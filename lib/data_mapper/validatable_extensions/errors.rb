module Validatable
  class Errors
    def on(attribute)
      raw(attribute)
    end
  
    def full_messages
      errors.values.flatten.compact
    end

  end
end