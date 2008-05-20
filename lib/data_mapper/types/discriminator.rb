module DataMapper
  module Types
    class Discriminator < DataMapper::Type
      primitive Class
      default lambda { |r,p| p.model }

      def self.bind(property)
        property.model.class_eval <<-EOS
          def self.inheritance_scope_class_names
            @inheritance_scope_class_names ||= []
          end
        
          after_class_method :inherited, :send_inheritance_scope
          
          def self.send_inheritance_scope(target)
            inheritance_scope_class_names << target.name
            target.instance_variable_set(:@inheritance_scope_class_names, [target.name])
            target.send(:scope_stack) << DataMapper::Query.new(#{property.name}.repository, target, :#{property.name} => target.inheritance_scope_class_names)
          end
        EOS
      end # bind
    end # class Discriminator
  end # module Types
end # module DataMapper
