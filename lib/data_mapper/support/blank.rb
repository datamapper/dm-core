class Object
  def blank?
    nil? || (respond_to?(:empty?) && empty?)
  end
end # class Object

class Numeric
  def blank?
    false
  end
end # class Numeric

class NilClass
  def blank?
    true
  end
end # class NilClass

class TrueClass
  def blank?
    false
  end
end # class TrueClass

class FalseClass
  def blank?
    true
  end
end # class FalseClass

class String
  def blank?
    empty? || self =~ /\A\s*\Z/
  end
end # class String
