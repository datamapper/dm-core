module Validatable
  module Macros
    def validates_uniqueness_of(*args)
      add_validations(args, ValidatesUniquenessOf)
    end
  end
end