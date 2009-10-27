module Enumerable
  def empty?
    each { return false }
    true
  end
end
