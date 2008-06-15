module DataMapper
  module Assertions
    def assert_kind_of(name, value, *klasses)
      return if defined?(Spec::Mocks::Mock) && value.kind_of?(Spec::Mocks::Mock)  # FIXME
      unless klasses.any? { |k| value.kind_of?(k) }
        raise ArgumentError, "+#{name}+ should be #{klasses.map { |k| k.name } * ' or '}, but was #{value.class.name}", caller(2)
      end
    end
  end
end # module DataMapper
