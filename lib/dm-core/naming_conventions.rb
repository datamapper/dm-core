module DataMapper

  # Use these modules to establish naming conventions.
  # The default is UnderscoredAndPluralized.
  # You assign a naming convention like so:
  #
  #   repository(:default).adapter.resource_naming_convention = NamingConventions::Underscored
  #
  # You can also easily assign a custom convention with a Proc:
  #
  #   repository(:default).adapter.resource_naming_convention = lambda do |value|
  #     'tbl' + value.camelize(true)
  #   end
  #
  # Or by simply defining your own module in NamingConventions that responds to
  # ::call.
  #
  # NOTE: It's important to set the convention before accessing your models
  # since the resource_names are cached after first accessed.
  # DataMapper.setup(name, uri) returns the Adapter for convenience, so you can
  # use code like this:
  #
  #   adapter = DataMapper.setup(:default, "mock://localhost/mock")
  #   adapter.resource_naming_convention = DataMapper::NamingConventions::Underscored
  module NamingConventions

    module UnderscoredAndPluralized
      def self.call(value)
        Extlib::Inflection.pluralize(Extlib::Inflection.underscore(value)).gsub('/','_')
      end
    end # module UnderscoredAndPluralized

    module UnderscoredAndPluralizedWithoutModule
      def self.call(value)
        Extlib::Inflection.pluralize(Extlib::Inflection.underscore(Extlib::Inflection.demodulize(value)))
      end
    end # module UnderscoredAndPluralizedWithoutModule

    module Underscored
      def self.call(value)
        Extlib::Inflection.underscore(value)
      end
    end # module Underscored

    module Yaml
      def self.call(value)
        Extlib::Inflection.pluralize(Extlib::Inflection.underscore(value)) + ".yaml"
      end
    end # module Yaml

  end # module NamingConventions
end # module DataMapper
