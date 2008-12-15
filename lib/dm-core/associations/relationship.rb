module DataMapper
  module Associations
    class Relationship
      include Assertions

      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max, :through ]

      attr_reader :name, :options, :query, :repository_name
      attr_accessor :type

      # TODO: document
      # @api private
      def child_model
        @child_model ||= begin
          (@parent_model || Object).find_const(@child_model_name)
        rescue
          raise NameError, "Cannot find the child_model #{@child_model_name} for #{@parent_model || @parent_model_name}"
        ensure
          remove_instance_variable(:@child_model_name)
        end
      end

      # TODO: document
      # @api private
      def child_key
        @child_key ||= begin
          child_key = nil
          child_model.repository.scope do |r|
            model_properties = child_model.properties(r.name)

            child_key = parent_key.zip(@child_properties || []).map do |parent_property,property_name|
              # TODO: use something similar to DM::NamingConventions to determine the property name
              parent_name = Extlib::Inflection.underscore(Extlib::Inflection.demodulize(parent_model.base_model.name))
              property_name ||= "#{parent_name}_#{parent_property.name}".to_sym

              if model_properties.has_property?(property_name)
                model_properties[property_name]
              else
                options = {}

                [ :length, :precision, :scale ].each do |option|
                  options[option] = parent_property.send(option)
                end

                child_model.property(property_name, parent_property.primitive, options)
              end
            end
          end
          PropertySet.new(child_key)
        end
      end

      # TODO: document
      # @api private
      def parent_model
        @parent_model ||= begin
          (@child_model || Object).find_const(@parent_model_name)
        rescue
          raise NameError, "Cannot find the parent_model #{@parent_model_name} for #{@child_model || @child_model_name}"
        ensure
          remove_instance_variable(:@parent_model_name)
        end
      end

      # TODO: document
      # @api private
      def parent_key
        @parent_key ||= begin
          parent_key = nil
          parent_model.repository.scope do |r|
            parent_key = if @parent_properties
              parent_model.properties(r.name).slice(*@parent_properties)
            else
              parent_model.key
            end
          end
          PropertySet.new(parent_key)
        end
      end

      private

      # +child_model_name and child_properties refers to the FK, parent_model_name
      # and parent_properties refer to the PK.  For more information:
      # http://edocs.bea.com/kodo/docs41/full/html/jdo_overview_mapping_join.html
      # I wash my hands of it!
      def initialize(name, repository_name, child_model, parent_model, options = {})
        assert_kind_of 'name',            name,            Symbol
        assert_kind_of 'repository_name', repository_name, Symbol

        if child_properties = options[:child_key]
          assert_kind_of 'options[:child_key]', child_properties, Array
        end

        if parent_properties = options[:parent_key]
          assert_kind_of 'options[:parent_key]', parent_properties, Array
        end

        @name              = name
        @repository_name   = repository_name
        @child_properties  = child_properties   # may be nil
        @parent_properties = parent_properties  # may be nil
        @query             = options.reject { |k,v| OPTIONS.include?(k) }
        @options           = options

        case child_model
          when Model  then @child_model      = child_model
          when String then @child_model_name = child_model
          else
            raise ArgumentError, "+child_model+ must be a String or Model, but was: #{child_model.class}"
        end

        case parent_model
          when Model  then @parent_model      = parent_model
          when String then @parent_model_name = parent_model
          else
            raise ArgumentError, "+parent_model+ must be a String or Model, but was: #{parent_model.class}"
        end

        # attempt to load the child_key if the parent and child model constants are defined
        if @parent_model && @child_model
          child_key
        end
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
