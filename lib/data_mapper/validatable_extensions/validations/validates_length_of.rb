module Validatable
  class ValidatesLengthOf < ValidationBase
     def message(instance)
       super || unless minimum.nil?
         '%s must be more than %d characters long'.t(humanized_attribute, minimum-1)
       else unless maximum.nil?
         '%s must be less than %d characters long'.t(humanized_attribute, maximum+1)
       else unless is.nil?
         '%s must be %d characters long'.t(humanized_attribute, is)
       else unless within.nil?
         '%s must be between %d and %d characters long'.t(humanized_attribute, within.first, within.last)
       end;end;end;end
     end
   end
 end