require __DIR__.parent + 'associations'
require __DIR__ + 'relationship'

module DataMapper
  module Associations
    module ManyToOne
      def many_to_one(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        target = options[:class_name] || DataMapper::Inflection.camelize(name)

        relationships[name] = Relationship.new(
          name,
          options[:repository_name] || repository.name,
          DataMapper::Inflection.demodulize(self.name),
          nil,
          target,
          nil
        )

        class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            #{name}_association.parent
          end

          def #{name}=(value)
            #{name}_association.parent = value
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              association = self.class.relationships[:#{name}].
                with_child(self, Instance) do |repository, child_key, parent_key, parent_model, child_resource|
                repository.all(parent_model, parent_key.to_query(child_key.get(child_resource))).first
              end

              child_associations << association

              association
            end
          end
        EOS
      end

      class Instance
        def initialize(relationship, child_resource, &parent_loader)
#          raise ArgumentError, "+relationship+ should be a DataMapper::Association::Relationship, but was #{relationship.class}", caller unless Relationship === relationship
#          raise ArgumentError, "+child_resource+ should be a DataMapper::Resource, but was #{child_resource.class}", caller              unless Resource     === child_resource

          @relationship   = relationship
          @child_resource = child_resource
          @parent_loader  = parent_loader
        end

        def parent
          @parent_resource ||= @parent_loader.call
        end

        def parent=(parent_resource)
          @parent_resource = parent_resource

          @relationship.attach_parent(@child_resource, @parent_resource) if @parent_resource.nil? || !@parent_resource.new_record?
        end

        def loaded?
          !defined?(@parent_resource)
        end

        def save
          if parent.new_record?
            repository(@relationship.repository_name).save(parent)
            @relationship.attach_parent(@child_resource, parent)
          end
        end
      end # class Instance
    end # module ManyToOne
  end # module Associations
end # module DataMapper
