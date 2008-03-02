class Struct
  def attributes
    h = {}
    each_pair { |k,v| h[k] = v }
    h
  end
end