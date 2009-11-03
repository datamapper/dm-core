module Enumerable
  def empty?
    each { return false }
    true
  end

  def one?
    return one? { |entry| entry } unless block_given?

    matches = 0
    each do |entry|
      matches += 1 if yield(entry)
      return false if matches > 1
    end
    matches == 1
  end

  def first
    each { |entry| return entry }
    nil
  end

  def size
    size = 0
    each { size += 1 }
    size
  end
end
