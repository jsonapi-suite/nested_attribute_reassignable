require "nested_attribute_reassignable/version"

module NestedAttributeReassignable
  class Helper
    def self.symbolize_keys!(attributes)
      if attributes.is_a?(Array)
        return unless attributes[0].respond_to?(:symbolize_keys!)
        attributes.each { |a| a.symbolize_keys! }
      else
        return unless attributes.respond_to?(:symbolize_keys!)
        attributes.symbolize_keys!
      end
    end

    def self.children_for(klass, association_name, ids)
      association_klass = reflection(klass, association_name).klass

      if ids.is_a?(Array)
        association_klass.where(id: ids)
      else
        association_klass.find(ids)
      end
    end

    def self.reflection(klass, association_name)
      klass.reflect_on_association(association_name)
    end
  end

  def self.included(klass)
    klass.extend ClassMethods
  end

  # Yes, this could use refactoring love, I do not
  # have time right now D:
  # Just go by the tests.
  module ClassMethods
    def reassignable_nested_attributes_for(name, *args)
      accepts_nested_attributes_for(name, *args)

      define_method "#{name}_attributes=" do |attributes|
        Helper.symbolize_keys!(attributes)

        if attributes.is_a?(Array)
          id_attribute_sets = attributes.select { |a| a.has_key?(:id) }
          children = Helper.children_for(self.class, name, attributes.map { |a| a[:id] }).to_a
          id_attribute_sets.each do |id_attributes|
            if child = children.find { |c| c.id.to_s == id_attributes[:id].to_s }
              if ActiveRecord::Type::Boolean.new.cast(id_attributes[:_destroy])
                send(name).find { |c| c.id == id_attributes[:id].to_i }.mark_for_destruction
              elsif ActiveRecord::Type::Boolean.new.cast(id_attributes[:_delete])
                record = send(name).find { |c| c.id == id_attributes[:id].to_i }
                send(name).delete(record)
              else
                nested_attributes = id_attributes.select { |k,v| k.to_s.include?('_attributes') }
                nested_attributes.each_pair do |key, val|
                  child.send("#{key}=", val)
                end
              end
            else
              raise_nested_attributes_record_not_found!(name, id_attributes[:id])
            end
          end
          self.send("#{name}=", (self.send(name) | children))

          non_id_attribute_sets = attributes.reject { |a| a.has_key?(:id) }
          non_id_attribute_sets.each do |non_id_attributes|
            self.send(name).build(non_id_attributes)
          end
        else
          if attributes[:id]
            if ActiveRecord::Type::Boolean.new.cast(attributes[:_destroy])
              self.send(name).mark_for_destruction
            elsif ActiveRecord::Type::Boolean.new.cast(attributes[:_delete])
              send("#{name}=", nil)
            else
              record = Helper.children_for(self.class, name, attributes[:id])
              self.send("#{name}=", record)

              attributes = attributes.select { |k,v| k.to_s.include?('_attributes') }.dup
              attributes.each_pair do |att, val|
                self.send(name).send("#{att}=", val)
              end
            end
          else
            super(attributes)
          end
        end
      end
    end
  end
end
