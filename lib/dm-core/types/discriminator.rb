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
          after_class_method :inherited, :add_scope_for_discriminator

          def self.add_scope_for_discriminator(retval, target)
            target.default_scope(#{repository_name.inspect}).update(#{property.name.inspect} => target.descendants.to_a)
          end
        RUBY
      end
    end # class Discriminator
  end # module Types
end # module DataMapper
