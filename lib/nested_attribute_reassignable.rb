require "nested_attribute_reassignable/version"
require "active_support/concern"

module NestedAttributeReassignable
  class RelationExists < StandardError
    def initialize(model, relation)
      @model = model.class.name.pluralize.underscore
      @relation = relation
    end

    def message
      <<-STR
Relation '#{@relation}' already exists on '#{@model}' object but attributes were passed with no id.

It is invalid to create a new '#{@relation}' relation when one already exists, as it would leave orphaned records. Update the existing record instead.
      STR
    end
  end

  class Helper
    def self.has_delete_flag?(hash)
      truthy?(hash, :_delete)
    end

    def self.has_destroy_flag?(hash)
      truthy?(hash, :_destroy)
    end

    def self.truthy?(hash, key)
      if defined?(Rails) && Rails::VERSION::MAJOR == 5
        ActiveRecord::Type::Boolean.new.cast(hash[key])
      else
        value = hash[key]
        [true, 1, '1', 'true'].include?(value)
      end
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
  end

  extend ActiveSupport::Concern

  # Yes, this could use refactoring love, I do not
  # have time right now D:
  # Just go by the tests.
  module ClassMethods
    def reassignable_nested_attributes_for(association_name, *args)
      options = args.extract_options!.symbolize_keys
      options.update({ :allow_destroy => true })
      nonexistent_id = options.delete(:nonexistent_id) || :raise

      accepts_nested_attributes_for(association_name, options.except(:lookup_key))

      define_method "#{association_name}_attributes=" do |attributes|
        reflection_klass  = self.class._reflect_on_association(association_name)
        association_klass = reflection_klass.klass
        association       = association(association_name)
        lookup_key        = options[:lookup_key] || association.klass.primary_key

        Helper.symbolize_keys!(attributes)

        if attributes.is_a?(Array)
          id_attribute_sets = attributes.select { |a| a.has_key?(:id) }

          ids = attributes.map { |a| a[:id] }
          children = association_klass.where(lookup_key => ids)

          # If we're deleting or destroying, we want to validate the record in question
          # is actually part of this relationship
          if id_attribute_sets.any? { |set| Helper.has_destroy_flag?(set) || Helper.has_delete_flag?(set) }
            existing_associated = association.scope.where(lookup_key => ids)
          end

          id_attribute_sets.each do |id_attributes|
            if existing_record = children.find { |c| c.send(lookup_key).to_s == id_attributes[:id].to_s }
              if Helper.has_destroy_flag?(id_attributes)
                if record = existing_associated.find { |e| e.send(lookup_key).to_s == id_attributes[:id].to_s }
                  record.mark_for_destruction
                  association.add_to_target(record, :skip_callbacks)
                else
                  raise_nested_attributes_record_not_found!(association_name, id_attributes[:id])
                end
              elsif Helper.has_delete_flag?(id_attributes)
                if record = existing_associated.find { |e| e.send(lookup_key).to_s == id_attributes[:id].to_s }
                  association.add_to_target(record, :skip_callbacks)
                  send(association_name).delete(record)
                else
                  raise_nested_attributes_record_not_found!(association_name, id_attributes[:id])
                end
              else
                id_attributes[lookup_key] = id_attributes[:id]
                existing_record.assign_attributes(id_attributes.except(:id))
                self.send(association_name).concat(existing_record)
              end
            else
              if nonexistent_id == :create
                new_record = association_klass.new(lookup_key => id_attributes[:id])
                self.send(association_name).concat(new_record)
              else
                raise_nested_attributes_record_not_found!(association_name, id_attributes[:id])
              end
            end
          end
          non_id_attribute_sets = attributes.reject { |a| a.has_key?(:id) }
          non_id_attribute_sets.each do |non_id_attributes|
            self.send(association_name).build(non_id_attributes)
          end
          self.association(association_name).loaded!
        else
          if attributes[:id]
            if Helper.has_destroy_flag?(attributes)
              self.send(association_name).mark_for_destruction
            elsif Helper.has_delete_flag?(attributes)
              send("#{association_name}=", nil)
            elsif existing_record = association_klass.find_by(lookup_key => attributes[:id])
              attributes[lookup_key] = attributes.delete(:id)
              existing_record.assign_attributes(attributes)
              self.send("#{association_name}=", existing_record)
            else
              if nonexistent_id == :create
                new_record = association_klass.new(lookup_key => attributes[:id])
                self.send("#{association_name}=", new_record)
              else
                raise_nested_attributes_record_not_found!(association_name, attributes[:id])
              end
            end
          else
            reflection  = self.class._reflect_on_association(association_name)
            if reflection.has_one? and send(association_name).present?
              raise RelationExists.new(self, association_name)
            else
              super(attributes)
            end
          end
        end
      end
    end
  end
end
