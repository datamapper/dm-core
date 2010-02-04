module DataMapper
  module Types
    class ParanoidDateTime < Type
      primitive DateTime
      lazy      true

      # @api private
      def self.bind(property)
        repository_name = property.repository_name.inspect
        model           = property.model
        property_name   = property.name.inspect

        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          include Paranoid::Base

          set_paranoid_property(#{property_name}) { DateTime.now }

          default_scope(#{repository_name}).update(#{property_name} => nil)
        RUBY
      end
    end # class ParanoidDateTime
  end # module Types
end # module DataMapper
