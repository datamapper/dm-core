module Validatable
  class ValidatesEach < ValidationBase
    def message(instance)
      super || '%s is invalid'.t(humanized_attribute)
    end
  end
end