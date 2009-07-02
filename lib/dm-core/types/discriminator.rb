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

        model.default_scope(repository_name).update(property.name => model.descendants)

        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          extend Chainable

          extendable do
            def inherited(model)
              set_discriminator_scope_for(model)
              super
            end

            private

            def set_discriminator_scope_for(model)
              model.default_scope(#{repository_name.inspect}).update(#{property.name.inspect} => model.descendants)
            end
          end
        RUBY
      end
    end # class Discriminator
  end # module Types
end # module DataMapper
