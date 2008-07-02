module DataMapper
  module Associations
    class Relationship
      include Assertions

      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max, :through ]

      attr_reader :name, :repository, :options, :query

      def child_key
        @child_key ||= begin
          child_key = nil
          with_repository(child_model) do
            model_properties = child_model.properties

            child_key = parent_key.zip(@child_properties || []).map do |parent_property,property_name|
              # TODO: use something similar to DM::NamingConventions to determine the property name
              parent_name = Extlib::Inflection.underscore(Extlib::Inflection.demodulize(parent_model))
              property_name ||= "#{parent_name}_#{parent_property.name}".to_sym

              if model_properties[property_name]
                model_properties[property_name]
              else
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
          end
          PropertySet.new(child_key)
        end
      end

      def parent_key
        @parent_key ||= begin
          parent_key = nil
          with_repository(parent_model) do
            parent_key = if @parent_properties
              parent_model.properties.slice(*@parent_properties)
            else
              parent_model.key
            end
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
        bind_values  = parent_values = parent_key.get(parent)
        query_values = []
        with_repository(parent) do |r|
          query_values = r.identity_map(parent_model).keys.flatten
          query_values.reject! { |k| r.identity_map(child_model)[[k]] }
        end

        association_accessor = "#{self.name}_association"

        query = {}
        child_key.each do |key|
          query[key] = query_values.empty? ? bind_values : query_values
        end

        ret = []
        with_repository(parent) do
          collection = child_model.send(finder, *(args << @query.merge(options).merge(query)))
          return collection unless Collection === collection
          grouped_collection = collection.inject({}) do |grouped, model|
            (grouped[get_parent(model, parent)] ||= []) << model
            grouped
          end
          grouped_collection.each do |parent, children|
            association = parent.send(association_accessor)
            parents_children = association.instance_variable_get(:@children)
            query = collection.query
            query.conditions[0][2] = *children.map { |child| child_key.get(child) }
            parents_children = Collection.new(query) do |collection|
              children.each { |child| collection.send(:add, child) }
            end
            parent_key.get(parent) == parent_values ? ret = parents_children : association.instance_variable_set(:@children, parents_children)
          end
        end
        ret
      end

      # @api private
      def get_parent(child, parent = nil)
        ret = nil
        with_repository(parent || child) do |r|
          bind_values = child_value = child_key.get(child)
          return nil if child_value.any? { |bind_value| bind_value.nil? }
          if parent = r.identity_map(parent_model)[child_value]
            return parent
          else
            association_accessor = "#{self.name}_association"
            children = r.identity_map(child_model)
            children.each do |key, c|
              bind_values |= child_key.get(c)
            end
            query_values = bind_values.reject { |k| r.identity_map(parent_model)[[k]] }

            query = {}
            parent_key.each do |key|
              query[key] = query_values.empty? ? bind_values : query_values
            end

            collection = parent_model.send(:all, query)
            collection.send(:lazy_load)
            children.each do |id, c|
              c.send(association_accessor).instance_variable_set(:@parent, collection.get(*child_key.get(c)))
            end
            ret = child.send(association_accessor).instance_variable_get(:@parent)
          end
        end
        ret
      end

      def with_repository(instance = nil, &block)
        instance == nil ? yield(@repository) : yield(instance.repository)
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
      def initialize(name, repository, child_model, parent_model, options = {})
        assert_kind_of 'name',              name,              Symbol
        # assert_kind_of 'repository_name',   repository_name,   Symbol
        assert_kind_of 'child_model',  child_model,  String, Class
        assert_kind_of 'parent_model', parent_model, String, Class

        if child_properties = options[:child_key]
          assert_kind_of 'options[:child_key]', child_properties, Array
        end

        if parent_properties = options[:parent_key]
          assert_kind_of 'options[:parent_key]', parent_properties, Array
        end

        @name              = name
        @repository        = repository
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
