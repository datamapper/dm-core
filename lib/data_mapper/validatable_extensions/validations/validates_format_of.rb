require File.dirname(__FILE__) + '/formats/email.rb'

module Validatable
  
  class ValidatesFormatOf < ValidationBase
    FORMATS = {}
    
    include Validatable::Helpers::Formats::Email

    def initialize(klass, attribute, options={})
      super
      if with.is_a? Symbol
        self.with = if FORMATS[with].is_a? Array
          @message = (FORMATS[with][1].respond_to?(:call) ? FORMATS[with][1].call(attribute) : FORMATS[with][1]) unless @message
          FORMATS[with][0]
        else
          FORMATS[with]
        end
      end
    end
    
    def message(instance)
      super || '%s is invalid'.t(humanized_attribute)
    end

  end

end