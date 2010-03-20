require 'dm-core/type'

module DataMapper
  module Types
    class ParanoidBoolean < Type
      primitive TrueClass
      default   false
      lazy      true

      # @api private
      def self.bind(property)
        repository_name = property.repository_name.inspect
        model           = property.model
        property_name   = property.name.inspect

        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          include Paranoid::Base

          set_paranoid_property(#{property_name}) { true }

          default_scope(#{repository_name}).update(#{property_name} => false)
        RUBY
      end
    end # class ParanoidBoolean
  end # module Types
end # module DataMapper
