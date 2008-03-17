module Validatable
  class ValidatesAcceptanceOf < ValidationBase
    def message(instance)
      super || '%s must be accepted'.t(humanized_attribute)
    end
  end
end