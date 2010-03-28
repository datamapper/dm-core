class String

  ##
  # Replace sequences of whitespace (including newlines) with either
  # a single space or remove them entirely (according to param _spaced_)
  #
  #   <<QUERY.compress_lines
  #     SELECT name
  #     FROM users
  #   QUERY => "SELECT name FROM users"
  #
  # @param [TrueClass, FalseClass] spaced (default=true)
  #   Determines whether returned string has whitespace collapsed or removed
  #
  # @return [String] Receiver with whitespace (including newlines) replaced
  #
  # @api public
  def compress_lines(spaced = true)
    split($/).map { |line| line.strip }.join(spaced ? ' ' : '')
  end

end
