require "nested_attribute_reassignable/version"
require "active_support/concern"

module NestedAttributeReassignable
  class Helper
    def self.has_delete_flag?(hash)
      has_key?(hash, :_delete)
    end

    def self.has_destroy_flag?(hash)
      has_key?(hash, :_destroy)
    end

    def self.has_key?(hash, key)
      ActiveRecord::Type::Boolean.new.cast(hash[key])
    end

    def self.symbolize_keys!(attributes)
      if attributes.is_a?(Array)
        return unless attributes[0].respond_to?(:symbolize_keys!)
        attributes.each { |a| a.symbolize_keys! }
      else
        return unless attributes.respond_to?(:symbolize_keys!)
        attributes.symbolize_keys!
      end
    end

    def self.children_for(klass, association_name, ids, association_key = :id)
      association_klass = reflection(klass, association_name).klass
      association_klass.where(association_key => ids)
    end

    def self.reflection(klass, association_name)
      klass.reflect_on_association(association_name)
    end
  end

  extend ActiveSupport::Concern

  included do
    class_attribute :reassignable_nested_attributes_options, instance_writer: false
    self.reassignable_nested_attributes_options = {}
  end

  # Yes, this could use refactoring love, I do not
  # have time right now D:
  # Just go by the tests.
  module ClassMethods
    def reassignable_nested_attributes_for(association_name, *args)
      options = args.extract_options!.symbolize_keys
      options.update({ :allow_destroy => true })
      lookup_key = options.delete(:lookup_key) || :id
      self.reassignable_nested_attributes_options[association_name] = { lookup_key: lookup_key }

      accepts_nested_attributes_for(association_name, options)

      define_method "#{association_name}_attributes=" do |attributes|
        Helper.symbolize_keys!(attributes)
        options = self.reassignable_nested_attributes_options[association_name]
        id_key  = options[:lookup_key]

        if attributes.is_a?(Array)
          id_attribute_sets = attributes.select { |a| a.has_key?(lookup_key) }
          children = Helper.children_for(self.class, association_name, attributes.map { |a| a[lookup_key] }, lookup_key).to_a

          id_attribute_sets.each do |id_attributes|
            if existing_record = children.find { |c| c.send(lookup_key).to_s == id_attributes[lookup_key].to_s }
              if Helper.has_destroy_flag?(id_attributes)
                send(association_name).find { |c| c.id.to_s == existing_record.id.to_s }.mark_for_destruction
              elsif Helper.has_delete_flag?(id_attributes)
                record = send(association_name).find { |c| c.id.to_s == existing_record.id.to_s }
                send(association_name).delete(record)
              else
                nested_attributes = id_attributes.select { |k,v| k.to_s.include?('_attributes') }
                existing_record.assign_attributes(nested_attributes)
              end
            else
              raise_nested_attributes_record_not_found!(association_name, id_attributes[lookup_key])
            end
          end
          self.send("#{association_name}=", (self.send(association_name) | children))
          non_id_attribute_sets = attributes.reject { |a| a.has_key?(lookup_key) }
          non_id_attribute_sets.each do |non_id_attributes|
            self.send(association_name).build(non_id_attributes)
          end
        else

          if attributes[lookup_key]
            if Helper.has_destroy_flag?(attributes)
              self.send(association_name).mark_for_destruction
            elsif Helper.has_delete_flag?(attributes)
              send("#{association_name}=", nil)
            elsif existing_record = Helper.children_for(self.class, association_name, attributes[lookup_key], lookup_key).first

              self.send("#{association_name}=", existing_record)

              nested_attributes = attributes.select { |k,v| k.to_s.include?('_attributes') }.dup
              existing_record.assign_attributes(nested_attributes)
            else
              raise_nested_attributes_record_not_found!(association_name, attributes[lookup_key])
            end
          else
            super(attributes)
          end
        end
      end
    end
  end
end
