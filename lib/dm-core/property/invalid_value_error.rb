module DataMapper
  class Property
    # Exception raised when DataMapper is about to work with 
    # invalid property values.
    class InvalidValueError < StandardError
      attr_reader :property
      def initialize(message,property=nil)
        super(message)
        @property
      end
    end
  end
end
