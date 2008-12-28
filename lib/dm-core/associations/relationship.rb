module DataMapper
  module Associations
    class Relationship
      include Extlib::Assertions

      OPTIONS = [ :child_repository_name, :parent_repository_name, :child_key, :parent_key, :min, :max, :through ].freeze

      # TODO: document
      # @api semipublic
      attr_reader :name, :query, *OPTIONS

      # TODO: document
      # @api semipublic
      def child_model
        @child_model ||= (@parent_model || Object).find_const(@child_model_name)
      rescue NameError
        raise NameError, "Cannot find the child_model #{@child_model_name} for #{@parent_model || @parent_model_name}"
      end

      # TODO: document
      # @api semipublic
      def child_key
        @child_key ||= begin
          properties = child_model.properties(@child_repository_name)

          # TODO: use something similar to DM::NamingConventions to determine the property name
          parent_name = Extlib::Inflection.underscore(Extlib::Inflection.demodulize(parent_model.base_model.name))

          child_key = parent_key.zip(@child_properties || []).map do |parent_property,property_name|
            property_name ||= "#{parent_name}_#{parent_property.name}".to_sym

            properties[property_name] || begin
              options = { :index => parent_name.to_sym }

              [ :length, :precision, :scale ].each do |option|
                options[option] = parent_property.send(option)
              end

              # create the property within the correct repository
              DataMapper.repository(@child_repository_name) do
                child_model.property(property_name, parent_property.primitive, options)
              end
            end
          end

          PropertySet.new(child_key)
        end
      end

      # TODO: document
      # @api semipublic
      def parent_model
        @parent_model ||= (@child_model || Object).find_const(@parent_model_name)
      rescue NameError
        raise NameError, "Cannot find the parent_model #{@parent_model_name} for #{@child_model || @child_model_name}"
      end

      # TODO: document
      # @api semipublic
      def parent_key
        @parent_key ||= begin
          parent_key = if @parent_properties
            parent_model.properties(@parent_repository_name).slice(*@parent_properties)
          else
            parent_model.key(@parent_repository_name)
          end

          PropertySet.new(parent_key)
        end
      end

      private

      # TODO: document
      # @api semipublic
      def initialize(name, child_model, parent_model, options = {})
        assert_kind_of 'name',         name,         Symbol
        assert_kind_of 'child_model',  child_model,  Model, String if child_model
        assert_kind_of 'parent_model', parent_model, Model, String
        assert_kind_of 'options',      options,      Hash

        assert_kind_of 'options[:child_repository_name]',  options[:child_repository_name],  Symbol
        assert_kind_of 'options[:parent_repository_name]', options[:parent_repository_name], Symbol

        assert_kind_of 'options[:child_key]',  options[:child_key],  Array, NilClass
        assert_kind_of 'options[:parent_key]', options[:parent_key], Array, NilClass

        assert_kind_of 'options[:through]', options[:through], Relationship, NilClass

        case child_model
          when Model  then @child_model      = child_model
          when String then @child_model_name = child_model.freeze
        end

        case parent_model
          when Model  then @parent_model      = parent_model
          when String then @parent_model_name = parent_model.freeze
        end

        @name                   = name
        @child_repository_name  = options[:child_repository_name]
        @parent_repository_name = options[:parent_repository_name]
        @child_properties       = options[:child_key].freeze
        @parent_properties      = options[:parent_key].freeze
        @min                    = options[:min] || 0
        @max                    = options[:max]
        @through                = options[:through]
        @query                  = options.except(*OPTIONS).freeze

        create_helper
        create_accessor
        create_mutator
      end

      # TODO: document
      # @api semipublic
      def create_helper
        raise NotImplementedError
      end

      # TODO: document
      # @api semipublic
      def create_accessor
        raise NotImplementedError
      end

      # TODO: document
      # @api semipublic
      def create_mutator
        raise NotImplementedError
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
