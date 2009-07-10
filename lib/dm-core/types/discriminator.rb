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

        model.instance_variable_set(:@discriminators, {})
        model.default_scope(repository_name).update(property.name => model.descendants)

        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          extend Chainable

          extendable do
            def inherited(model)
              model.instance_variable_set(:@discriminators, {})
              set_discriminator_scope_for(model)
              super
            end

            def new(*args, &block)
              if args.size == 1 && args.first.kind_of?(Hash)
                model = discriminator.typecast(args.first[discriminator.name])

                if model.kind_of?(Model) && !model.equal?(self)
                  return model.new(*args, &block)
                end
              end

              super
            end

            private

            # TODO: document
            # @api private
            def discriminator
              @discriminators[repository_name] ||= properties(repository_name).discriminator
            end

            def set_discriminator_scope_for(model)
              model.default_scope(#{repository_name.inspect}).update(#{property.name.inspect} => model.descendants)
            end
          end
        RUBY
      end
    end # class Discriminator
  end # module Types
end # module DataMapper
