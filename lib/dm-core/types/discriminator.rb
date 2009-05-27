module DataMapper
  module Types
    class Discriminator < Type
      primitive Class
      default lambda { |resource, property| property.model }
      nullable false

      # TODO: document
      # @api private
      def self.bind(property)
        repository_name = property.repository_name
        model           = property.model

        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          # TODO: update to use an Ordered Set so that new models
          # added retain their order
          def self.descendants
            @descendants ||= Set.new
          end

          after_class_method :inherited, :add_scope_for_discriminator

          def self.add_scope_for_discriminator(retval, target)
            target.descendants << target
            target.default_scope(#{repository_name.inspect}).update(#{property.name.inspect} => target.descendants.to_a)
            propagate_descendants(target)
          end

          def self.propagate_descendants(target)
            descendants << target
            superclass.propagate_descendants(target) if superclass.respond_to?(:propagate_descendants)
          end
        RUBY
      end
    end # class Discriminator
  end # module Types
end # module DataMapper
