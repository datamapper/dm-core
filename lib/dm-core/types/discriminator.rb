module DataMapper
  module Types
    class Discriminator < Type
      primitive Class
      default   lambda { |resource, property| resource.model }
      required  true

      # @api private
      def self.bind(property)
        repository_name = property.repository_name
        model           = property.model
        property_name   = property.name

        model.default_scope(repository_name).update(property_name => model.descendants)

        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          extend Chainable

          extendable do
            def inherited(model)
              super  # setup self.descendants
              set_discriminator_scope_for(model)
            end

            def new(*args, &block)
              if args.size == 1 && args.first.kind_of?(Hash)
                discriminator = properties(repository_name).discriminator
                model         = discriminator.typecast(args.first[discriminator.name])

                if model.kind_of?(Model) && !model.equal?(self)
                  return model.new(*args, &block)
                end
              end

              super
            end

            private

            def set_discriminator_scope_for(model)
              model.default_scope(#{repository_name.inspect}).update(#{property_name.inspect} => model.descendants)
            end
          end
        RUBY
      end
    end # class Discriminator
  end # module Types
end # module DataMapper
