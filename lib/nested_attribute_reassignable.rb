require "nested_attribute_reassignable/version"

module NestedAttributeReassignable
  class Helper
    def self.has_delete_flag?(hash)
      ActiveRecord::Type::Boolean.new.cast(hash[:_delete])
    end

    def self.with_indifferent_access(attributes)
      if attributes.is_a?(Array)
        return unless attributes[0].respond_to?(:with_indifferent_access)
        attributes.map { |a| a.with_indifferent_access }
      else
        return unless attributes.respond_to?(:with_indifferent_access)
        attributes.with_indifferent_access
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
    def reassignable_nested_attributes_for(association_name, *args)
      accepts_nested_attributes_for(association_name, *args)

      define_method "#{association_name}_attributes=" do |attributes|
        attributes = Helper.with_indifferent_access(attributes)

        if attributes.is_a?(Array)
          id_attribute_sets = attributes.select { |a| a.has_key?(:id) }
          children = Helper.children_for(self.class, association_name, attributes.map { |a| a[:id] }).to_a
          id_attribute_sets.each do |id_attributes|
            if child = children.find { |c| c.id.to_s == id_attributes[:id].to_s }
              if has_destroy_flag?(id_attributes)
                send(association_name).find { |c| c.id == id_attributes[:id].to_i }.mark_for_destruction
              elsif Helper.has_delete_flag?(id_attributes)
                record = send(association_name).find { |c| c.id == id_attributes[:id].to_i }
                send(association_name).delete(record)
              else
                nested_attributes = id_attributes.select { |k,v| k.to_s.include?('_attributes') }
                nested_attributes.each_pair do |key, val|
                  child.send("#{key}=", val)
                end
              end
            else
              raise_nested_attributes_record_not_found!(association_name, id_attributes[:id])
            end
          end
          self.send("#{association_name}=", (self.send(association_name) | children))

          non_id_attribute_sets = attributes.reject { |a| a.has_key?(:id) }
          non_id_attribute_sets.each do |non_id_attributes|
            self.send(association_name).build(non_id_attributes)
          end
        else
          if attributes[:id]
            if has_destroy_flag?(attributes)
              self.send(association_name).mark_for_destruction
            elsif Helper.has_delete_flag?(attributes)
              send("#{association_name}=", nil)
            else
              record = Helper.children_for(self.class, association_name, attributes[:id])
              self.send("#{association_name}=", record)

              attributes = attributes.select { |k,v| k.to_s.include?('_attributes') }.dup
              attributes.each_pair do |att, val|
                self.send(association_name).send("#{att}=", val)
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
