module DataMapper
  module Types
    class Discriminator < DataMapper::Type
      primitive Class
      track :set
      default lambda { |r,p| p.model }

      def self.bind(property)
        model = property.model

        model.class_eval <<-EOS
          def self.child_classes
            @child_classes ||= []
          end

          after_class_method :inherited, :propagate_child_classes

          def self.propagate_child_classes(target)
            child_classes << target
            superclass.send(:propagate_child_classes,target) if superclass.respond_to?(:propagate_child_classes)
          end
        EOS

        model.send(:scope_stack) << DataMapper::Query.new(property.repository, model, property.name => (model.child_classes << model))

      end
    end # class Discriminator
  end # module Types
end # module DataMapper
