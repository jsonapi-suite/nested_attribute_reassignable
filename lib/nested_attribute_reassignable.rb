require "nested_attribute_reassignable/version"

module NestedAttributeReassignable
  class Helper
    def self.symbolize_keys!(attributes)
      if attributes.is_a?(Array)
        attributes.each { |a| a.symbolize_keys! }
      else
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

    def self.has_one?(klass, association_name)
      reflection(klass, association_name).is_a?(ActiveRecord::Reflection::HasOneReflection)
    end
  end

  def self.included(klass)
    klass.extend ClassMethods
  end

  module ClassMethods
    def reassignable_nested_attributes_for(name, *args)
      accepts_nested_attributes_for(name, *args)

      define_method "#{name}_attributes=" do |attributes|
        Helper.symbolize_keys!(attributes)

        if attributes.is_a?(Array)
          children = Helper.children_for(self.class, name, attributes.map { |a| a[:id] })
          self.send("#{name}=", (self.send(name) | children))
          attributes = attributes.select { |a| !a.has_key?(:id) }
          super(attributes)
        else
          if attributes[:id]
            if Helper.has_one?(self.class, name)
              record = Helper.children_for(self.class, name, attributes[:id])
              self.send("#{name}=", record)
            else
              self.send("#{name}_id=", attributes[:id])
            end
          else
            super(attributes)
          end
        end
      end
    end
  end
end
