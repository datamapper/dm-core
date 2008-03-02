module Validatable
  class ValidatesPresenceOf < ValidationBase
    def message(instance)
      super || "%s must not be blank".t(humanized_attribute)
    end
  end
end