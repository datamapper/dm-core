module DataMapper; module Ext
  module Array
    # Transforms an Array of key/value pairs into a {Mash}.
    #
    # This is a better idiom than using Mash[*array.flatten] in Ruby 1.8.6
    # because it is not possible to limit the flattening to a single
    # level.
    #
    # @param [Array] array
    #   The array of key/value pairs to transform.
    #
    # @return [Mash]
    #   A {Mash} where each entry in the Array is turned into a key/value.
    #
    # @api semipublic
    def self.to_mash(array)
      m = Mash.new
      array.each { |k,v| m[k] = v }
      m
    end
  end # class Array
end; end
