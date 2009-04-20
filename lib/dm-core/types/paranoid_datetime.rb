module DataMapper
  module Types
    class ParanoidDateTime < Type
      primitive DateTime
      lazy      true

      # TODO: document
      # @api private
      def self.bind(property)
        repository_name = property.repository_name
        model           = property.model
        property_name   = property.name

        model.send(:set_paranoid_property, property_name){DateTime.now}

        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def self.with_deleted
            with_exclusive_scope(#{property_name.inspect}.not => nil) do
              yield
            end
          end

          def destroy
            self.class.paranoid_properties.each do |name, blk|
              attribute_set(name, blk.call(self))
            end
            save
          end
        RUBY

        model.default_scope(repository_name).update(property_name => nil)
      end
    end # class ParanoidDateTime
  end # module Types
end # module DataMapper
