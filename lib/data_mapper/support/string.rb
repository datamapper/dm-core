class String
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

  def to_class
    ::Object::recursive_const_get(self)
  end
end # class String
