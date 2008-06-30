module DataMapper
  module Associations
    class Relationship
      include Assertions

      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max, :through ]

      attr_reader :name, :repository_name, :options, :query

      def child_key
        @child_key ||= begin
          model_properties = child_model.properties(repository_name)

          child_key = parent_key.zip(@child_properties || []).map do |parent_property,property_name|
            # TODO: use something similar to DM::NamingConventions to determine the property name
            parent_name = Extlib::Inflection.underscore(Extlib::Inflection.demodulize(parent_model))
            property_name ||= "#{parent_name}_#{parent_property.name}".to_sym

            model_properties[property_name] || DataMapper.repository(repository_name) do
              attributes = {}

              [ :length, :precision, :scale ].each do |attribute|
                attributes[attribute] = parent_property.send(attribute)
              end

              # NOTE: hack to make each many to many child_key a true key,
              # until I can figure out a better place for this check
              if child_model.respond_to?(:many_to_many)
                attributes[:key] = true
              end

              child_model.property(property_name, parent_property.primitive, attributes)
            end
          end
          PropertySet.new(child_key)
        end
      end

      def parent_key
        @parent_key ||= begin
          parent_key = if @parent_properties
            parent_model.properties(repository_name).slice(*@parent_properties)
          else
            parent_model.key(repository_name)
          end

          PropertySet.new(parent_key)
        end
      end

      def parent_model
        Class === @parent_model ? @parent_model : (Class === @child_model ? @child_model.find_const(@parent_model) : Object.find_const(@parent_model))
      end

      def child_model
        Class === @child_model ? @child_model : (Class === @parent_model ? @parent_model.find_const(@child_model) : Object.find_const(@child_model))
      end

      # @api private
      def get_children(parent, options = {}, finder = :all, *args)
        bind_values = parent_values = parent_key.get(parent)
        bind_values |= DataMapper.repository(repository_name).identity_map(parent_model).keys.flatten
        query_values = bind_values.reject { |k| DataMapper.repository(repository_name).identity_map(child_model)[[k]] }

        association_accessor = "#{self.name}_association"

        query = {}
        child_key.each do |key|
          query[key] = query_values.empty? ? bind_values : query_values
        end

        DataMapper.repository(repository_name) do
          collection = child_model.send(finder, *(args << @query.merge(options).merge(query)))
          return collection unless Collection === collection
          grouped_collection = collection.inject({}) do |grouped, model|
            (grouped[get_parent(model)] ||= []) << model
            grouped
          end
          ret = []
          grouped_collection.each do |parent, children|
            association = parent.send(association_accessor)
            parents_children = association.instance_variable_get(:@children)
            if parents_children.blank?
              query = collection.query
              query.conditions[0][2] = *children.map { |child| child_key.get(child) }
              parents_children = Collection.new(query) do |collection|
                children.each { |child| collection.send(:add, child) }
              end
            else
              parents_children |= children
            end
            parent_key.get(parent) == parent_values ? ret = parents_children : association.instance_variable_set(:@children, parents_children)
          end
          ret
        end
      end

      # @api private
      def get_parent(child)
        if parent = DataMapper.repository(repository_name).identity_map(parent_model)[child_key.get(child)]
          return parent
        else
          bind_values = child_key.get(child)
          return nil if bind_values.any? { |bind_value| bind_value.nil? }
          query = parent_key.to_query(bind_values)

          DataMapper.repository(repository_name) do
            parent_model.first(query)
          end
        end
      end

      # @api private
      def attach_parent(child, parent)
        child_key.set(child, parent && parent_key.get(parent))
      end

      private

      # +child_model_name and child_properties refers to the FK, parent_model_name
      # and parent_properties refer to the PK.  For more information:
      # http://edocs.bea.com/kodo/docs41/full/html/jdo_overview_mapping_join.html
      # I wash my hands of it!
      def initialize(name, repository_name, child_model, parent_model, options = {})
        assert_kind_of 'name',              name,              Symbol
        assert_kind_of 'repository_name',   repository_name,   Symbol
        assert_kind_of 'child_model',  child_model,  String, Class
        assert_kind_of 'parent_model', parent_model, String, Class

        if child_properties = options[:child_key]
          assert_kind_of 'options[:child_key]', child_properties, Array
        end

        if parent_properties = options[:parent_key]
          assert_kind_of 'options[:parent_key]', parent_properties, Array
        end

        @name              = name
        @repository_name   = repository_name
        @child_model       = child_model
        @child_properties  = child_properties   # may be nil
        @query             = options.reject { |k,v| OPTIONS.include?(k) }
        @parent_model      = parent_model
        @parent_properties = parent_properties  # may be nil
        @options           = options
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
