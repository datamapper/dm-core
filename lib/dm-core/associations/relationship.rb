module DataMapper
  module Associations
    class Relationship
      include Extlib::Assertions

      OPTIONS = [ :child_repository_name, :parent_repository_name, :child_key, :parent_key, :min, :max, :through ].freeze

      # TODO: document
      # @api semipublic
      attr_reader :name, :query, *OPTIONS

      def intermediaries
        @intermediaries ||= [].freeze
      end

      # TODO: document
      # @api semipublic
      def child_model
        @child_model ||= (@parent_model || Object).find_const(@child_model_name)
      rescue NameError
        raise NameError, "Cannot find the child_model #{@child_model_name} for #{@parent_model || @parent_model_name} #{name.inspect}"
      end

      # TODO: document
      # @api semipublic
      def child_key(repository_name)
        assert_kind_of 'repository_name', repository_name, Symbol

        child_repository_name  = @child_repository_name  || repository_name
        parent_repository_name = @parent_repository_name || repository_name

        @child_key ||= {}

        @child_key[child_repository_name] ||= begin
          properties  = child_model.properties(child_repository_name)
          parent_name = Extlib::Inflection.underscore(Extlib::Inflection.demodulize(parent_model.base_model.name))

          child_key = parent_key(parent_repository_name).zip(@child_properties || []).map do |parent_property,property_name|
            property_name ||= "#{parent_name}_#{parent_property.name}".to_sym

            properties[property_name] || begin
              options = { :index => parent_name.to_sym }

              [ :length, :size, :precision, :scale ].each do |option|
                if parent_property.options.key?(option)
                  options[option] = parent_property.options[option]
                end
              end

              # create the property within the correct repository
              DataMapper.repository(child_repository_name) do
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
        raise NameError, "Cannot find the parent_model #{@parent_model_name} for #{@child_model || @child_model_name} #{name.inspect}"
      end

      # TODO: document
      # @api semipublic
      def parent_key(repository_name)
        assert_kind_of 'repository_name', repository_name, Symbol

        parent_repository_name = @parent_repository_name || repository_name

        @parent_key ||= {}

        @parent_key[parent_repository_name] ||= begin
          parent_key = if @parent_properties
            parent_model.properties(parent_repository_name).slice(*@parent_properties)
          else
            parent_model.key(parent_repository_name)
          end

          PropertySet.new(parent_key)
        end
      end

      # TODO: document
      # @api semipublic
      def target_for(resource)
        raise NotImplementedError
      end

      private

      # TODO: document
      # @api semipublic
      def initialize(name, child_model, parent_model, options = {})
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
        @min                    = options[:min]
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
