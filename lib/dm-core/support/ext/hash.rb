module DataMapper; module Ext
  module Hash
    # Creates a hash with *only* the specified key/value pairs from +hash+.
    #
    # @param [Hash] hash The hash from which to pick the key/value pairs.
    # @param [Array] *keys The hash keys to include.
    #
    # @return [Hash] A new hash with only the selected keys.
    #
    # @example
    #   hash = { :one => 1, :two => 2, :three => 3 }
    #   Ext::Hash.only(hash, :one, :two) # => { :one => 1, :two => 2 }
    #
    # @api semipublic
    def self.only(hash, *keys)
      h = {}
      keys.each {|k| h[k] = hash[k] if hash.has_key?(k) }
      h
    end

    # Returns a hash that includes everything but the given +keys+.
    #
    # @param [Hash] hash The hash from which to pick the key/value pairs.
    # @param [Array] *keys The hash keys to exclude.
    #
    # @return [Hash] A new hash without the specified keys.
    #
    # @example
    #   hash = { :one => 1, :two => 2, :three => 3 }
    #   Ext::Hash.except(hash, :one, :two) # => { :three => 3 }
    #
    # @api semipublic
    def self.except(hash, *keys)
      self.except!(hash.dup, *keys)
    end

    # Removes the specified +keys+ from the given +hash+.
    #
    # @param [Hash] hash The hash to modify.
    # @param [Array] *keys The hash keys to exclude.
    #
    # @return [Hash] +hash+
    #
    # @example
    #   hash = { :one => 1, :two => 2, :three => 3 }
    #   Ext::Hash.except!(hash, :one, :two)
    #   hash # => { :three => 3 }
    #
    # @api semipublic
    def self.except!(hash, *keys)
      keys.each { |key| hash.delete(key) }
      hash
    end

    # Converts the specified +hash+ to a {Mash}.
    #
    # @param [Hash] hash The hash to convert.
    # @return [Mash] The {Mash} for the specified +hash+.
    #
    # @api semipublic
    def self.to_mash(hash)
      h = Mash.new(hash)
      h.default = hash.default
      h
    end
  end
end; end
