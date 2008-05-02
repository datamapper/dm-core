require 'forwardable'

module DataMapper
  module Associations
    module OneToMany
      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max ]

      private

      def one_to_many(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol (or Hash for +through+ support), but was #{name.class}", caller     unless Symbol === name || Hash === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        if (unknown_options = options.keys - OPTIONS).any?
          raise ArgumentError, "+options+ contained unknown keys: #{unknown_options * ', '}"
        end

        child_model_name = options.fetch(:class_name, DataMapper::Inflection.classify(name))

        relationship = relationships(repository.name)[name] = Relationship.new(
          DataMapper::Inflection.underscore(self.name.split('::').last).to_sym,
          repository.name,
          child_model_name,
          self.name,
          options
        )

        class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            @#{name}_association ||= begin
              relationship = self.class.relationships(repository.name)[:#{name}]
              association = Proxy.new(relationship, self, relationship.get_children(repository, self))
              parent_associations << association
              association
            end
          end
        EOS

        relationship
      end

      class Proxy
        def push(*resources)
          append_resource(resources)
          @children.push(*resources)
          self
        end

        alias << push

        def unshift(*resources)
          append_resource(resources)
          @children.unshift(*resources)
          self
        end

        def clear
          each { |resource| remove_resource(resource) }
          @children.clear
          self
        end

        def pop
          remove_resource(@children.pop)
        end

        def shift
          remove_resource(@children.shift)
        end

        def delete(resource, &block)
          remove_resource(@children.delete(resource, &block))
        end

        def delete_at(index)
          remove_resource(@children.delete_at(index))
        end

        def save
          save_resources(@dirty_children)
          @dirty_children = []
        end

        private

        def initialize(relationship, parent_resource, collection)
#          raise ArgumentError, "+relationship+ should be a DataMapper::Association::Relationship, but was #{relationship.class}", caller unless Relationship === relationship
#          raise ArgumentError, "+parent_resource+ should be a DataMapper::Resource, but was #{parent_resource.class}", caller            unless Resource     === parent_resource
#          raise ArgumentError, "+collection+ should be a DataMapper::Collection, but was #{collection.class}", caller                    unless Collection   === parent_resource

          @relationship    = relationship
          @parent_resource = parent_resource
          @children        = collection
          @dirty_children  = []
        end

        def remove_resource(resource)
          begin
            @relationship.attach_parent(resource, nil)
            repository(@relationship.repository_name).save(resource)
          rescue
            @children << resource
            raise
          end
          resource
        end

        def append_resource(resources = [])
          if @parent_resource.new_record?
            @dirty_children.push(*resources)
          else
            save_resources(resources)
          end
        end

        def save_resources(resources = [])
          resources.each do |resource|
            @relationship.attach_parent(resource, @parent_resource)
            repository(@relationship.repository_name).save(resource)
          end
        end

        def method_missing(method, *args, &block)
          if @children.respond_to?(method)
            @children.__send__(method, *args, &block)
          else
            super
          end
        end
      end # class Proxy
    end # module OneToMany
  end # module Associations
end # module DataMapper
