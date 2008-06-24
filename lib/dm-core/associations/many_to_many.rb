require File.join(File.dirname(__FILE__), "one_to_many")
module DataMapper
  module Associations
    module ManyToMany
      extend Assertions

      # Setup many to many relationship between two models
      # -
      # @api private
      def self.setup(name, model, options = {})
        assert_kind_of 'name',    name,    Symbol
        assert_kind_of 'model',   model,   Model
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
        opts[:mutable]                  =   true

        names = [opts[:child_model], opts[:parent_model]].sort!

        class_name = Extlib::Inflection.pluralize(names[0]) + names[1]
        storage_name = Extlib::Inflection.tableize(class_name)

        opts[:near_relationship_name] = storage_name.to_sym

        model.has 1.0/0, storage_name.to_sym
        relationship = model.relationships(repository_name)[name] = RelationshipChain.new( opts )

        unless Object.const_defined?(class_name)
          model = DataMapper::Model.new(storage_name)

          model.class_eval <<-EOS, __FILE__, __LINE__
            def self.default_repository_name; #{repository_name.inspect} end
            def self.many_to_many; true end
          EOS

          names.each do |name|
            model.belongs_to Extlib::Inflection.underscore(name).to_sym
          end

          Object.const_set(class_name, model)
        end

        relationship
      end

      class Proxy < DataMapper::Associations::OneToMany::Proxy

        def <<(resource)
          resource.save if resource.new_record?
          through = @relationship.child_model.new
          @relationship.child_key.each_with_index do |key, index|
            through.send("#{key.name}=", @relationship.parent_key.key[index].get(@parent))
          end
          remote_relationship.child_key.each_with_index do |key, index|
            through.send("#{key.name}=", remote_relationship.parent_key.key[index].get(resource))
          end
          near_model << through
          super
        end

        def delete(resource)
          through = near_model.get(*(@parent.key + resource.key))
          near_model.delete(through)
          orphan_resource(super)
        end

        def clear
          near_model.clear
          super
        end

        def destroy
          near_model.destroy
          super
        end

        def save
        end

        def orphan_resource(resource)
          assert_mutable
          @orphans << resource
          resource
        end

        def assert_mutable
        end

        private

        def remote_relationship
          @remote_relationship ||= @relationship.send(:remote_relationship)
        end

        def near_model
          @near_model ||= @parent.send(near_relationship_name)
        end

        def near_relationship_name
          @near_relationship_name ||= @relationship.send(:instance_variable_get, :@near_relationship_name)
        end
      end # class Proxy
    end # module ManyToMany
  end # module Associations
end # module DataMapper
