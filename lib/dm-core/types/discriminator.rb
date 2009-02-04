module DataMapper
  module Types
    class Discriminator < DataMapper::Type
      primitive Class
      default lambda { |r,p| p.model }
      nullable false

      def self.bind(property)
        model = property.model

        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def self.descendants
            @descendants ||= Set.new
          end

          after_class_method :inherited, :add_scope_for_discriminator

          def self.add_scope_for_discriminator(retval, target)
            target.descendants << target
            target.default_scope.update(#{property.name.inspect} => target.descendants)
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
