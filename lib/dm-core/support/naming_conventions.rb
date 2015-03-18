module DataMapper

  # Use these modules to establish naming conventions.
  # The default is UnderscoredAndPluralized.
  # You assign a naming convention like so:
  #
  #   repository(:default).adapter.resource_naming_convention = NamingConventions::Resource::Underscored
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
  #   adapter = DataMapper.setup(:default, 'mock://127.0.0.1/mock')
  #   adapter.resource_naming_convention = NamingConventions::Resource::Underscored
  module NamingConventions

    module Resource

      module UnderscoredAndPluralized
        def self.call(name)
          DataMapper::Inflector.pluralize(DataMapper::Inflector.underscore(name)).gsub('/', '_')
        end
      end # module UnderscoredAndPluralized

      module UnderscoredAndPluralizedWithoutModule
        def self.call(name)
          DataMapper::Inflector.pluralize(DataMapper::Inflector.underscore(DataMapper::Inflector.demodulize(name)))
        end
      end # module UnderscoredAndPluralizedWithoutModule

      module UnderscoredAndPluralizedWithoutLeadingModule
        def self.call(name)
          UnderscoredAndPluralized.call(name.to_s.gsub(/^[^:]*::/,''))
        end
      end

      module Underscored
        def self.call(name)
          DataMapper::Inflector.underscore(name)
        end
      end # module Underscored

      module Yaml
        def self.call(name)
          "#{DataMapper::Inflector.pluralize(DataMapper::Inflector.underscore(name))}.yaml"
        end
      end # module Yaml

    end # module Resource

    module Field

      module UnderscoredAndPluralized
        def self.call(property)
          DataMapper::Inflector.pluralize(DataMapper::Inflector.underscore(property.name.to_s)).gsub('/', '_')
        end
      end # module UnderscoredAndPluralized

      module UnderscoredAndPluralizedWithoutModule
        def self.call(property)
          DataMapper::Inflector.pluralize(DataMapper::Inflector.underscore(DataMapper::Inflector.demodulize(property.name.to_s)))
        end
      end # module UnderscoredAndPluralizedWithoutModule

      module Underscored
        def self.call(property)
          DataMapper::Inflector.underscore(property.name.to_s)
        end
      end # module Underscored

      module FQN
        def self.call(property)
          model, name = property.model, property.name

          fk_names = model.relationships.inject([]) { |names, rel|
            if rel.respond_to?(:required?)
              names + rel.source_key.map(&:name)
            else
              names
            end
          }

          return name.to_s if fk_names.include?(name)

          storage_name = model.storage_name(property.repository_name)
          "#{DataMapper::Inflector.singularize(storage_name)}_#{name}"
        end
      end # module FQN

      module Yaml
        def self.call(property)
          "#{DataMapper::Inflector.pluralize(DataMapper::Inflector.underscore(property.name.to_s))}.yaml"
        end
      end # module Yaml

    end # module Field

  end # module NamingConventions
end # module DataMapper
