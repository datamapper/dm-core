module DataMapper
  class Property
    class Discriminator < Class
      include PassThroughLoadDump

      default   lambda { |resource, property| resource.model }
      required  true

      # @api private
      def bind
        model.default_scope(repository_name).update(name => model.descendants.dup << model)

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

                if discriminator_value = args.first[discriminator.name]
                  model = discriminator.typecast_to_primitive(discriminator_value)

                  if model.kind_of?(Model) && !model.equal?(self)
                    return model.new(*args, &block)
                  end
                end
              end

              super
            end

            private

            def set_discriminator_scope_for(model)
              model.default_scope(#{repository_name.inspect}).update(#{name.inspect} => model.descendants.dup << model)
            end
          end
        RUBY
      end
    end # class Discriminator
  end # module Property
end # module DataMapper
