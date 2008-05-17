module DataMapper
  module Associations
    class Relationship

      attr_reader :foreign_key_name, :repository_name, :options

      def child_key
        @child_key ||= begin
          model_properties = child_model.properties(repository_name)

          child_key = parent_key.zip(@child_properties || []).map do |parent_property,property_name|
            # TODO: use something similar to DM::NamingConventions to determine the property name
            property_name ||= "#{foreign_key_name}_#{parent_property.name}".to_sym
            type = parent_property.type
            type = Integer if Fixnum == type  # TODO: remove this hack once all in-the-wild code uses Integer instead of Fixnum
            model_properties[property_name] || child_model.property(property_name, type)
          end

          PropertySet.new(child_key)
        end
      end

      def parent_key
        @parent_key ||= begin
          model_properties = parent_model.properties(repository_name)

          parent_key = if @parent_properties
            model_properties.slice(*@parent_properties)
          else
            model_properties.key
          end

          PropertySet.new(parent_key)
        end
      end

      def get_children(parent,options = {},finder = :all)
        query = @query.merge(options).merge(child_key.to_query(parent_key.get(parent)))
        
        DataMapper.repository(parent.repository.name) do
          finder == :first ? child_model.first(query) : child_model.all(query)
        end
      end

      def get_parent(child)
        query = parent_key.to_query(child_key.get(child))

        DataMapper.repository(repository_name) do
          parent_model.first(query.merge(@query))
        end
      end

      def attach_parent(child, parent)
        child_key.set(child, parent && parent_key.get(parent))
      end

      def parent_model
        find_const(@parent_model_name)
      end

      def child_model
        find_const(@child_model_name)
      end

      private

      # +child_model_name and child_properties refers to the FK, parent_model_name
      # and parent_properties refer to the PK.  For more information:
      # http://edocs.bea.com/kodo/docs41/full/html/jdo_overview_mapping_join.html
      # I wash my hands of it!
      def initialize(foreign_key_name, repository_name, child_model_name, parent_model_name, options = {}, &loader)
        puts caller.join("\n") if child_model_name == "Wife"
        raise ArgumentError, "+foreign_key_name+ should be a Symbol, but was #{foreign_key_name.class}", caller                                unless Symbol === foreign_key_name
        raise ArgumentError, "+repository_name+ must be a Symbol, but was #{repository_name.class}", caller            unless Symbol === repository_name
        raise ArgumentError, "+child_model_name+ must be a String, but was #{child_model_name.class}", caller          unless String === child_model_name
        raise ArgumentError, "+parent_model_name+ must be a String, but was #{parent_model_name.class}", caller        unless String === parent_model_name

        if child_properties = options[:child_key]
          raise ArgumentError, "+options[:child_key]+ must be an Array or nil, but was #{child_properties.class}", caller unless Array === child_properties
        end

        if parent_properties = options[:parent_key]
          raise ArgumentError, "+parent_properties+ must be an Array or nil, but was #{parent_properties.class}", caller unless Array === parent_properties
        end
        
        query = options.reject{ |key,val| [:class_name, :child_key, :parent_key, :min, :max].include?(key) }

        @foreign_key_name  = foreign_key_name
        @repository_name   = repository_name
        @child_model_name  = child_model_name
        @child_properties  = child_properties   # may be nil
        @query             = query
        @parent_model_name = parent_model_name
        @parent_properties = parent_properties  # may be nil
        @loader            = loader
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
