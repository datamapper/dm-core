module DataMapper
  module Types
    class ParanoidDateTime < DataMapper::Type(DateTime)
      primitive DateTime
      lazy      true

      def self.bind(property)
        model = property.model
        repository = property.repository

        model.class_eval <<-EOS, __FILE__, __LINE__
          def destroy
            attribute_set(#{property.name.inspect}, DateTime.now)
            save
          end
        EOS

        model.default_scope.update(property.name => nil)
      end
    end # class ParanoidDateTime
  end # module Types
end # module DataMapper
