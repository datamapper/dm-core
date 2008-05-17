module DataMapper
  module Associations
    module HasOneThrough
      OPTIONS = [ :class_name, :remote_name, :min, :max ]

      private

      def has_one_through(name, options = {})
        raise NotImplementedError
      end

    end # module HasOneThrough
  end # module Associations
end # module DataMapper
