module DataMapper
  module Types
    class Discriminator < DataMapper::Type
      primitive Class
      track :set
      default lambda { |r,p| p.model }
      nullable false

      def self.bind(property)
        model = property.model

        model.class_eval <<-EOS, __FILE__, __LINE__
          def self.child_classes
            @child_classes ||= []
          end

          after_class_method :inherited, :add_scope_for_discriminator

          def self.add_scope_for_discriminator(target)
            target.send(:scope_stack) << DataMapper::Query.new(target.repository, target, :#{property.name} => target.child_classes << target)
            propagate_child_classes(target)
          end

          def self.propagate_child_classes(target)
            child_classes << target
            superclass.send(:propagate_child_classes,target) if superclass.respond_to?(:propagate_child_classes)
          end
        EOS
      end
    end # class Discriminator
  end # module Types
end # module DataMapper
