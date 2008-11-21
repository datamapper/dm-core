module DataMapper::Spec
  module CollectionHelpers
    module GroupMethods
      def self.extended(base)
        base.class_inheritable_accessor :loaded
        base.loaded = false
      end
    end
  end
end
