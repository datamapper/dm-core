module DataMapper; module Ext
  module Hash
    # Create a hash with *only* key/value pairs in receiver and +allowed+
    #
    #   { :one => 1, :two => 2, :three => 3 }.only(:one)    #=> { :one => 1 }
    #
    # @param [Array[String, Symbol]] *allowed The hash keys to include.
    #
    # @return [Hash] A new hash with only the selected keys.
    #
    # @api public
    def self.only(h, *allowed)
      hash = {}
      allowed.each {|k| hash[k] = h[k] if h.has_key?(k) }
      hash
    end

    # Return a hash that includes everything but the given keys. This is useful for
    # limiting a set of parameters to everything but a few known toggles:
    #
    #   @person.update_attributes(params[:person].except(:admin))
    #
    # If the receiver responds to +convert_key+, the method is called on each of the
    # arguments. This allows +except+ to play nice with hashes with indifferent access
    # for instance:
    #
    #   {:a => 1}.with_indifferent_access.except(:a)  # => {}
    #   {:a => 1}.with_indifferent_access.except("a") # => {}
    #
    def self.except(h, *keys)
      self.except!(h.dup, *keys)
    end

    # Replaces the hash without the given keys.
    def self.except!(h, *keys)
      keys.each { |key| h.delete(key) }
      h
    end

    # Convert to Mash. This class has semantics of ActiveSupport's
    # HashWithIndifferentAccess and we only have it so that people can write
    # params[:key] instead of params['key'].
    #
    # @return [Mash] This hash as a Mash for string or symbol key access.
    def self.to_mash(h)
      hash = Mash.new(h)
      hash.default = h.default
      hash
    end
  end
end; end
