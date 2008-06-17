require File.join(File.dirname(__FILE__), "one_to_many")
module DataMapper
  module Associations
    module ManyToMany
      extend Assertions

      # Setup many to many relationship between two models
      # -
      # @private
      def self.setup(name, model, options = {})
        assert_kind_of 'name',    name,    Symbol
        assert_kind_of 'model',   model,   Resource::ClassMethods
        assert_kind_of 'options', options, Hash

        repository_name = model.repository.name

        model.class_eval <<-EOS, __FILE__, __LINE__
          def #{name}(query = {})
            #{name}_association.all(query)
          end

          def #{name}=(children)
            #{name}_association.replace(children)
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              unless relationship = model.relationships(#{repository_name.inspect})[#{name.inspect}]
                raise ArgumentError, 'Relationship #{name.inspect} does not exist'
              end
              association = Proxy.new(relationship, self)
              parent_associations << association
              association
            end
          end
        EOS

        opts = options.dup
        opts.delete(:through)
        opts[:child_model]            ||= opts.delete(:class_name)  || Extlib::Inflection.classify(name)
        opts[:parent_model]             =   model.name
        opts[:repository_name]          =   repository_name
        opts[:remote_relationship_name] ||= opts.delete(:remote_name) || name
        opts[:parent_key]               =   opts[:parent_key]
        opts[:child_key]                =   opts[:child_key]

        names = [opts[:child_model], opts[:parent_model]].sort!

        class_name = Extlib::Inflection.pluralize(names[0]) + names[1]
        storage_name = Extlib::Inflection.tableize(class_name)

        opts[:near_relationship_name] = storage_name.to_sym

        model.has 1.0/0, storage_name.to_sym
        model.relationships(repository_name)[name] = RelationshipChain.new( opts )

        unless Object.const_defined?(class_name)
          resource = DataMapper::Resource.new(storage_name)
          resource.class_eval <<-EOS, __FILE__, __LINE__
          def self.name; #{class_name.inspect} end
          EOS
          names.each do |name|
            name = Extlib::Inflection.underscore(name)
            resource.class_eval <<-EOS, __FILE__, __LINE__
            property :#{name}_id, Integer, :key => true
            belongs_to :#{name}
            EOS
          end
          Object.const_set(class_name, resource)
        end
      end

      class Proxy < DataMapper::Associations::OneToMany::Proxy

        def <<(resource)
          remote_relationship = @relationship.send(:remote_relationship)
          resource.save if resource.new_record?
          through = @relationship.child_model.new(
            @relationship.child_key.key.first.name => @relationship.parent_key.key.first.get(@parent),
            remote_relationship.child_key.key.first.name => remote_relationship.parent_key.key.first.get(resource)
          )
          @parent.send(@relationship.send(:instance_variable_get, :@near_relationship_name)) << through
        end

        def save
        end

        def assert_mutable
        end
      end # class Proxy
    end # module ManyToMany
  end # module Associations
end # module DataMapper
