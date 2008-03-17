module Validatable
  class ValidatesNumericalityOf < ValidationBase
    def message(instance)
      super || '%s must be a number'.t(humanized_attribute)
    end
  end
end