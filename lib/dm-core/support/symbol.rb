class Symbol
  def gt
    DataMapper::Query::Operator.new(self, :gt)
  end

  def gte
    DataMapper::Query::Operator.new(self, :gte)
  end

  def lt
    DataMapper::Query::Operator.new(self, :lt)
  end

  def lte
    DataMapper::Query::Operator.new(self, :lte)
  end

  def not
    DataMapper::Query::Operator.new(self, :not)
  end

  def eql
    warn "explicit use of 'eql' operator is deprecated"
    DataMapper::Query::Operator.new(self, :eql)
  end

  def like
    DataMapper::Query::Operator.new(self, :like)
  end

  def in
    warn "explicit use of 'in' operator is deprecated"
    DataMapper::Query::Operator.new(self, :in)
  end

  def asc
    DataMapper::Query::Operator.new(self, :asc)
  end

  def desc
    DataMapper::Query::Operator.new(self, :desc)
  end
end # class Symbol
