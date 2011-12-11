module DataMapper
  class Property
    # Exception raised then dm tries finds invalid values when 
    # persisting or quering resources.
    class InvalidValueError < StandardError
      attr_reader :resource
   
      def initialize(message, resource)
        super(message)
        @resource = resource
      end
    end
  end
end
