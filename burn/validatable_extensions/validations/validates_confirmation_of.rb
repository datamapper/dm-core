module Validatable
  class ValidatesConfirmationOf < ValidationBase
    def message(instance)
      super || "%s does not match the confirmation".t(humanized_attribute)
    end
  end
end