# The original of this file was copied for the ActiveSupport project which is
# part of the Ruby On Rails web-framework (http://rubyonrails.org)
#
# Methods have been modified or removed. English inflection is now provided via
# the english gem (http://english.rubyforge.org)
#
# sudo gem install english
#
require 'english/inflect'

English::Inflect.word 'postgres'

module DataMapper
  module Inflection
    class << self
      # Take an underscored name and make it into a camelized name
      #
      # Examples
      #   "egg_and_hams".classify #=> "EggAndHam"
      #   "post".classify #=> "Post"
      #
      def classify(name)
        camelize(singularize(name.to_s.sub(/.*\./, '')))
      end

      # By default, camelize converts strings to UpperCamelCase.
      #
      # camelize will also convert '/' to '::' which is useful for converting paths to namespaces
      #
      # Examples
      #   "active_record".camelize #=> "ActiveRecord"
      #   "active_record/errors".camelize #=> "ActiveRecord::Errors"
      #
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
      #
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
      #
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

      # The reverse of pluralize, returns the singular form of a word in a string.
      # Wraps the English gem
      # Examples
      #   "posts".singularize #=> "post"
      #   "octopi".singularize #=> "octopus"
      #   "sheep".singluarize #=> "sheep"
      #   "word".singluarize #=> "word"
      #   "the blue mailmen".singularize #=> "the blue mailman"
      #   "CamelOctopi".singularize #=> "CamelOctopus"
      #
      def singularize(word)
        word.singular
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
      #
      def pluralize(word)
        word.plural
      end

    end
  end # module Inflection
end # module DataMapper
