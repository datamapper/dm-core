require 'forwardable'

module DataMapper
  module Associations
    module OneToMany
      private
      def one_to_many(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        # TOOD: raise an exception if unknown options are passed in

        child_model_name  = options[:class_name] || DataMapper::Inflection.classify(name)

        relationships[name] = Relationship.new(
          DataMapper::Inflection.underscore(self.name).to_sym,
          options,
          repository.name,
          child_model_name,
          nil,
          self.name,
          nil
        )

        class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            #{name}_association
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              relationship = self.class.relationships[:#{name}]

              association = Proxy.new(relationship, self) do |repository, relationship|
                repository.all(*relationship.to_child_query(self))
              end

              parent_associations << association

              association
            end
          end
        EOS
        relationships[name]
      end

      class Proxy
        extend Forwardable
        include Enumerable
        
        def_instance_delegators :entries, :[], :size, :length, :first, :last

        def loaded?
          !defined?(@children_resources)
        end

        def clear
          each { |child_resource| delete(child_resource) }
        end

        def each(&block)
          children.each(&block)
          self
        end
        
        def children
          @children_resources ||= @children_loader.call(repository(@relationship.repository_name), @relationship)
        end
        
        def save
          @dirty_children.each do |child_resource|
            save_child(child_resource)
          end
        end
        
        def push(*child_resources)
          child_resources.each do |child_resource|
            if @parent_resource.new_record?
              @dirty_children << child_resource
            else
              save_child(child_resource)
            end

            children << child_resource
          end
          
          self
        end
        
        alias << push
        
        def delete(child_resource)
          deleted_resource = children.delete(child_resource)
          begin
            @relationship.attach_parent(deleted_resource, nil)
            repository(@relationship.repository_name).save(deleted_resource)
          rescue
            children << child_resource
            raise
          end
        end
        
        private
        
        def initialize(relationship, parent_resource, &children_loader)
          #        raise ArgumentError, "+relationship+ should be a DataMapper::Association::Relationship, but was #{relationship.class}", caller unless Relationship === relationship
          #        raise ArgumentError, "+parent_resource+ should be a DataMapper::Resource, but was #{parent_resource.class}", caller            unless Resource     === parent_resource
          
          @relationship    = relationship
          @parent_resource = parent_resource
          @children_loader = children_loader
          @dirty_children  = []
        end

        def save_child(child_resource)
          @relationship.attach_parent(child_resource, @parent_resource)
          repository(@relationship.repository_name).save(child_resource)
        end
      end # class Proxy
    end # module OneToMany
  end # module Associations
end # module DataMapper
