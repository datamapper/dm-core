class Hash

  ##
  # Create a hash with *only* key/value pairs in receiver and +allowed+
  #
  #   { :one => 1, :two => 2, :three => 3 }.only(:one)    #=> { :one => 1 }
  #
  # @param [Array[String, Symbol]] *allowed The hash keys to include.
  #
  # @return [Hash] A new hash with only the selected keys.
  #
  # @api public
  def only(*allowed)
    hash = {}
    allowed.each {|k| hash[k] = self[k] if self.has_key?(k) }
    hash
  end

  # Convert to Mash. This class has semantics of ActiveSupport's
  # HashWithIndifferentAccess and we only have it so that people can write
  # params[:key] instead of params['key'].
  #
  # @return [Mash] This hash as a Mash for string or symbol key access.
  def to_mash
    hash = Mash.new(self)
    hash.default = default
    hash
  end

end
