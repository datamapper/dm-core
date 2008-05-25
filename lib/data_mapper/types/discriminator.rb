module DataMapper
  module Types
    class Discriminator < DataMapper::Type
      primitive Class
      default lambda { |r,p| p.model }

      def self.bind(property)
        model = property.model

        model.class_eval <<-EOS
          def self.inheritance_class_names
            @inheritance_class_names ||= []
          end

          after_class_method :inherited, :propagate_inheritance_class_name

          def self.propagate_inheritance_class_name(target)
            inheritance_class_names << target.name
            superclass.send(:propagate_inheritance_class_name,target) if superclass.respond_to?(:propagate_inheritance_class_name)
          end
        EOS

        model.send(:scope_stack) << DataMapper::Query.new(property.repository, model, property.name => (model.inheritance_class_names << model.name))

      end
    end # class Discriminator
  end # module Types
end # module DataMapper
