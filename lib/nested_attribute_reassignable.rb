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
        reflection_klass  = self.class._reflect_on_association(association_name)
        association_klass = reflection_klass.klass

        Helper.symbolize_keys!(attributes)

        if attributes.is_a?(Array)
          id_attribute_sets = attributes.select { |a| a.has_key?(:id) }
          children = association_klass.where(lookup_key => attributes.map { |a| a[:id] }).to_a

          id_attribute_sets.each do |id_attributes|
            if existing_record = children.find { |c| c.send(lookup_key).to_s == id_attributes[:id].to_s }
              if Helper.has_destroy_flag?(id_attributes)
                if record = send(association_name).find { |c| c.id.to_s == existing_record.id.to_s }
                  record.mark_for_destruction
                else
                  raise_nested_attributes_record_not_found!(association_name, id_attributes[:id])
                end
              elsif Helper.has_delete_flag?(id_attributes)
                if record = send(association_name).find { |c| c.id.to_s == existing_record.id.to_s }
                  reflection_klass.through_reflection ? record.mark_for_destruction : send(association_name).delete(record)
                else
                  raise_nested_attributes_record_not_found!(association_name, id_attributes[:id])
                end
              else
                id_attributes[lookup_key] = id_attributes[:id]
                existing_record.assign_attributes(id_attributes.except(:id))
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
            if Helper.has_destroy_flag?(attributes)
              self.send(association_name).mark_for_destruction
            elsif Helper.has_delete_flag?(attributes)
              send("#{association_name}=", nil)
            elsif existing_record = association_klass.find_by(lookup_key => attributes[:id])
              attributes[lookup_key] = attributes.delete(:id)
              existing_record.assign_attributes(attributes)
              self.send("#{association_name}=", existing_record)
            else
              raise_nested_attributes_record_not_found!(association_name, attributes[:id])
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
