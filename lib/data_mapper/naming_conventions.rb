require Pathname(__FILE__).dirname + 'support/inflector'

module DataMapper
  
  # Use these modules to set naming conventions.
  # The default is UnderscoredAndPluralized.
  # You assign a naming convention like so:
  #
  #   DataMapper::Repository.container_naming_convention = NamingConventions::Underscored
  # 
  # You can also easily assign a custom convention with a Proc:
  #
  #   DataMapper::Repository.resource_naming_convention = lambda do |value|
  #     'tbl' + value.camelize(true)
  #   end
  #
  # Or by simply defining your own module in NamingConventions that responds to ::call.
  module NamingConventions
  
    module UnderscoredAndPluralized
      def self.call(value)
        Inflector.pluralize(Inflector.underscore(value))
      end
    end
  
    module Underscored
      def self.call(value)
        Inflector.underscore(value)
      end
    end
    
  end # module NamingConventions
end # module DataMapper