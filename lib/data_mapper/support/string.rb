module DataMapper
  module Support
    module String
      
      # I set the constant on the String itself to avoid inheritance chain lookups.
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        # Overwrite this method to provide your own translations.
        def translate(value)
          translations[value] || value
        end
        
        def translations
          @translations ||= {}
        end
      end

      # Matches any whitespace (including newline) and replaces with a single space
      # EXAMPLE:
      #   <<QUERY.compress_lines
      #     SELECT name
      #     FROM users
      #   QUERY
      #   => "SELECT name FROM users"
      def compress_lines(spaced = true)
        split($/).map { |line| line.strip }.join(spaced ? ' ' : '')
      end
      
      # Useful for heredocs - removes whitespace margin.
      def margin(indicator = nil)
        lines = self.dup.split($/)
        
        min_margin = 0
        lines.each do |line|
          if line =~ /^(\s+)/ && (min_margin == 0 || $1.size < min_margin)
            min_margin = $1.size
          end
        end
        lines.map { |line| line.sub(/^\s{#{min_margin}}/, '') }.join($/)
      end
      
      # Formats String for easy translation. Replaces an arbitrary number of 
      # values using numeric identifier replacement.
      # 
      #   "%s %s %s" % %w(one two three) #=> "one two three"
      #   "%3$s %2$s %1$s" % %w(one two three) #=> "three two one"
      def t(*values)
        self.class::translate(self) % values
      end

      def to_class
        ::Object::recursive_const_get(self)
      end
    end # module String
  end # module Support
end # module DataMapper

class String #:nodoc:
  include DataMapper::Support::String  
end
