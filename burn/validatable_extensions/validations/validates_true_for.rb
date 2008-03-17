module Validatable
  class ValidatesTrueFor < ValidationBase
    def message(instance)
      super || '%s must be true'.t(humanized_attribute)
    end
  end
end
