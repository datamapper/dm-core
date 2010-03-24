module DataMapper
  module Types
    module Paranoid
      module Base
        def self.included(type)
          type.extend ClassMethods
        end

        def paranoid_destroy
          model.paranoid_properties.each do |name, block|
            attribute_set(name, block.call(self))
          end
          save_self
          self.persisted_state = Resource::State::Immutable.new(self)
          true
        end

        private

        # @api private
        def _destroy(safe)
          return false unless saved?
          if safe
            paranoid_destroy
          else
            super
          end
        end
      end # module Methods

      module ClassMethods
        def with_deleted
          with_exclusive_scope({}) { block_given? ? yield : all }
        end
      end # module ClassMethods
    end # module Paranoid
  end # module Types
end # module DataMapper
