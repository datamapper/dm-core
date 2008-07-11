module DataMapper
  module Types
    class ParanoidBoolean < DataMapper::Type(Boolean)
      primitive TrueClass
      default   false

      def self.bind(property)
        model = property.model
        repository = property.repository

        model.class_eval <<-EOS, __FILE__, __LINE__
          def destroy
            attribute_set(#{property.name.inspect}, true)
            save
          end
        EOS

        model.default_scope.update(property.name => nil)
      end
    end # class ParanoidBoolean
  end # module Types
end # module DataMapper
