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
          def self.descendants
            (@descendants ||= []).uniq!
            @descendants
          end

          after_class_method :inherited, :add_scope_for_discriminator

          def self.add_scope_for_discriminator(target)
            target.descendants << target
            target.send(:scope_stack) << DataMapper::Query.new(target.repository, target, :#{property.name} => target.descendants)
            propagate_descendants(target)
          end

          def self.propagate_descendants(target)
            descendants << target
            superclass.propagate_descendants(target) if superclass.respond_to?(:propagate_descendants)
          end
        EOS
      end
    end # class Discriminator
  end # module Types
end # module DataMapper
