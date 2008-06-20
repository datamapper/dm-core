class Array
  # FIXME: rename this to to_hash :)
  def to_h
    hash = {}
    each { |k,v| hash[k] = v }
    hash
  end
end
