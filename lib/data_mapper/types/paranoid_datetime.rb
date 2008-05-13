module DataMapper
  module Types
    class ParanoidDateTime < DataMapper::Type(DateTime)
      primitive DateTime

      def self.bind(property)
        model = property.model
        repository = property.repository

        model.class_eval <<-EOS
          def destroy
            attribute_set(#{property.name.inspect}, DateTime::now)
            save
          end
        EOS

        model.send(:scope_stack) << DataMapper::Query.new(repository, model, property.name => nil)

      end
    end
  end
end
