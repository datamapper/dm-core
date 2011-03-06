module DataMapper; module Ext
  module String
    # Replace sequences of whitespace (including newlines) with either
    # a single space or remove them entirely (according to param _spaced_).
    #
    #   compress_lines(<<QUERY)
    #     SELECT name
    #     FROM users
    #   QUERY => "SELECT name FROM users"
    #
    # @param [String] string
    #   The input string.
    #
    # @param [TrueClass, FalseClass] spaced (default=true)
    #   Determines whether returned string has whitespace collapsed or removed.
    #
    # @return [String] The input string with whitespace (including newlines) replaced.
    #
    # @api semipublic
    def self.compress_lines(string, spaced = true)
      string.split($/).map { |line| line.strip }.join(spaced ? ' ' : '')
    end
  end
end; end
