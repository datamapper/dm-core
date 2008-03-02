# This file was copied from the ActiveSupport project, which
# is a part of the Ruby On Rails web-framework (http://rubyonrails.org).
# Some methods have been modified or removed.

require 'singleton'

# The Inflector transforms words from singular to plural, class names to table names, modularized class names to ones without,
# and class names to foreign keys. The default inflections for pluralization, singularization, and uncountable words are kept
# in inflections.rb.
unless defined?(Inflector)
  module Inflector
    # A singleton instance of this class is yielded by Inflector.inflections, which can then be used to specify additional
    # inflection rules. Examples:
    #
    #   Inflector.inflections do |inflect|
    #     inflect.plural /^(ox)$/i, '\1\2en'
    #     inflect.singular /^(ox)en/i, '\1'
    #
    #     inflect.irregular 'octopus', 'octopi'
    #
    #     inflect.uncountable "equipment"
    #   end
    #
    # New rules are added at the top. So in the example above, the irregular rule for octopus will now be the first of the
    # pluralization and singularization rules that is runs. This guarantees that your rules run before any of the rules that may
    # already have been loaded.
    class Inflections
      include Singleton

      attr_reader :plurals, :singulars, :uncountables

      def initialize
        @plurals, @singulars, @uncountables = [], [], []
      end

      # Specifies a new pluralization rule and its replacement. The rule can either be a string or a regular expression.
      # The replacement should always be a string that may include references to the matched data from the rule.
      def plural(rule, replacement)
        @plurals.insert(0, [rule, replacement])
      end

      # Specifies a new singularization rule and its replacement. The rule can either be a string or a regular expression.
      # The replacement should always be a string that may include references to the matched data from the rule.
      def singular(rule, replacement)
        @singulars.insert(0, [rule, replacement])
      end

      # Specifies a new irregular that applies to both pluralization and singularization at the same time. This can only be used
      # for strings, not regular expressions. You simply pass the irregular in singular and plural form.
      #
      # Examples:
      #   irregular 'octopus', 'octopi'
      #   irregular 'person', 'people'
      def irregular(singular, plural)
        plural(Regexp.new("(#{singular[0,1]})#{singular[1..-1]}$", "i"), '\1' + plural[1..-1])
        singular(Regexp.new("(#{plural[0,1]})#{plural[1..-1]}$", "i"), '\1' + singular[1..-1])
      end

      # Add uncountable words that shouldn't be attempted inflected.
      #
      # Examples:
      #   uncountable "money"
      #   uncountable "money", "information"
      #   uncountable %w( money information rice )
      def uncountable(*words)
        (@uncountables << words).flatten!
      end
    end

    extend self

    def inflections
      if block_given?
        yield Inflections.instance
      else
        Inflections.instance
      end
    end

    # Returns the plural form of the word in the string.
    #
    # Examples
    #   "post".pluralize #=> "posts"
    #   "octopus".pluralize #=> "octopi"
    #   "sheep".pluralize #=> "sheep"
    #   "words".pluralize #=> "words"
    #   "the blue mailman".pluralize #=> "the blue mailmen"
    #   "CamelOctopus".pluralize #=> "CamelOctopi"
    def pluralize(word)
      result = word.to_s.dup

      if inflections.uncountables.include?(result.downcase)
        result
      else
        inflections.plurals.each { |(rule, replacement)| break if result.gsub!(rule, replacement) }
        result
      end
    end

    # The reverse of pluralize, returns the singular form of a word in a string.
    #
    # Examples
    #   "posts".singularize #=> "post"
    #   "octopi".singularize #=> "octopus"
    #   "sheep".singluarize #=> "sheep"
    #   "word".singluarize #=> "word"
    #   "the blue mailmen".singularize #=> "the blue mailman"
    #   "CamelOctopi".singularize #=> "CamelOctopus"
    def singularize(word)
      result = word.to_s.dup

      if inflections.uncountables.include?(result.downcase)
        result
      else
        inflections.singulars.each { |(rule, replacement)| break if result.gsub!(rule, replacement) }
        result
      end
    end

    # By default, camelize converts strings to UpperCamelCase.
    #
    # camelize will also convert '/' to '::' which is useful for converting paths to namespaces
    #
    # Examples
    #   "active_record".camelize #=> "ActiveRecord"
    #   "active_record/errors".camelize #=> "ActiveRecord::Errors"
    def camelize(lower_case_and_underscored_word, *args)
      lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
    end

    # The reverse of +camelize+. Makes an underscored form from the expression in the string.
    #
    # Changes '::' to '/' to convert namespaces to paths.
    #
    # Examples
    #   "ActiveRecord".underscore #=> "active_record"
    #   "ActiveRecord::Errors".underscore #=> active_record/errors
    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end

    # Capitalizes the first word and turns underscores into spaces and strips _id.
    # Like titleize, this is meant for creating pretty output.
    #
    # Examples
    #   "employee_salary" #=> "Employee salary"
    #   "author_id" #=> "Author"
    def humanize(lower_case_and_underscored_word)
      lower_case_and_underscored_word.to_s.gsub(/_id$/, "").gsub(/_/, " ").capitalize
    end

    # Removes the module part from the expression in the string
    #
    # Examples
    #   "ActiveRecord::CoreExtensions::String::Inflections".demodulize #=> "Inflections"
    #   "Inflections".demodulize #=> "Inflections"
    def demodulize(class_name_in_module)
      class_name_in_module.to_s.gsub(/^.*::/, '')
    end

    # Create the name of a table like Rails does for models to table names. This method
    # uses the pluralize method on the last word in the string.
    #
    # Examples
    #   "RawScaledScorer".tableize #=> "raw_scaled_scorers"
    #   "egg_and_ham".tableize #=> "egg_and_hams"
    #   "fancyCategory".tableize #=> "fancy_categories"
    def tableize(class_name)
      pluralize(underscore(class_name))
    end

    # Create a class name from a table name like Rails does for table names to models.
    # Note that this returns a string and not a Class. (To convert to an actual class
    # follow classify with constantize.)
    #
    # Examples
    #   "egg_and_hams".classify #=> "EggAndHam"
    #   "post".classify #=> "Post"
    def classify(table_name)
      # strip out any leading schema name
      camelize(singularize(table_name.to_s.sub(/.*\./, '')))
    end

    # Creates a foreign key name from a class name.
    #
    # Examples
    #   "Message".foreign_key #=> "message_id"
    #   "Admin::Post".foreign_key #=> "post_id"
    def foreign_key(class_name, key = "id")
      underscore(demodulize(class_name.to_s)) << "_" << key.to_s
    end

    # Constantize tries to find a declared constant with the name specified
    # in the string. It raises a NameError when the name is not in CamelCase
    # or is not initialized.
    #
    # Examples
    #   "Module".constantize #=> Module
    #   "Class".constantize #=> Class
    def constantize(camel_cased_word)
      unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ camel_cased_word
        raise NameError, "#{camel_cased_word.inspect} is not a valid constant name!"
      end

      Object.module_eval("::#{$1}", __FILE__, __LINE__)
    end
  end
end

Inflector.inflections do |inflect|
  inflect.plural(/$/, 's')
  inflect.plural(/s$/i, 's')
  inflect.plural(/(ax|test)is$/i, '\1es')
  inflect.plural(/(octop|vir)us$/i, '\1i')
  inflect.plural(/(alias|status)$/i, '\1es')
  inflect.plural(/(bu)s$/i, '\1ses')
  inflect.plural(/(buffal|tomat)o$/i, '\1oes')
  inflect.plural(/([ti])um$/i, '\1a')
  inflect.plural(/sis$/i, 'ses')
  inflect.plural(/(?:([^f])fe|([lr])f)$/i, '\1\2ves')
  inflect.plural(/(hive)$/i, '\1s')
  inflect.plural(/([^aeiouy]|qu)y$/i, '\1ies')
  inflect.plural(/(x|ch|ss|sh)$/i, '\1es')
  inflect.plural(/(matr|vert|ind)ix|ex$/i, '\1ices')
  inflect.plural(/([m|l])ouse$/i, '\1ice')
  inflect.plural(/^(ox)$/i, '\1en')
  inflect.plural(/(quiz)$/i, '\1zes')

  inflect.singular(/s$/i, '')
  inflect.singular(/(n)ews$/i, '\1ews')
  inflect.singular(/([ti])a$/i, '\1um')
  inflect.singular(/((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)ses$/i, '\1\2sis')
  inflect.singular(/(^analy)ses$/i, '\1sis')
  inflect.singular(/([^f])ves$/i, '\1fe')
  inflect.singular(/(hive)s$/i, '\1')
  inflect.singular(/(tive)s$/i, '\1')
  inflect.singular(/([lr])ves$/i, '\1f')
  inflect.singular(/([^aeiouy]|qu)ies$/i, '\1y')
  inflect.singular(/(s)eries$/i, '\1eries')
  inflect.singular(/(m)ovies$/i, '\1ovie')
  inflect.singular(/(x|ch|ss|sh)es$/i, '\1')
  inflect.singular(/([m|l])ice$/i, '\1ouse')
  inflect.singular(/(bus)es$/i, '\1')
  inflect.singular(/(o)es$/i, '\1')
  inflect.singular(/(shoe)s$/i, '\1')
  inflect.singular(/(cris|ax|test)es$/i, '\1is')
  inflect.singular(/(octop|vir)i$/i, '\1us')
  inflect.singular(/(alias|status)es$/i, '\1')
  inflect.singular(/^(ox)en/i, '\1')
  inflect.singular(/(vert|ind)ices$/i, '\1ex')
  inflect.singular(/(matr)ices$/i, '\1ix')
  inflect.singular(/(quiz)zes$/i, '\1')

  inflect.irregular('person', 'people')
  inflect.irregular('man', 'men')
  inflect.irregular('child', 'children')
  inflect.irregular('sex', 'sexes')
  inflect.irregular('move', 'moves')

  inflect.uncountable(%w(equipment information rice money species series fish sheep))
end