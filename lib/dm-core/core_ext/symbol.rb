class Symbol

  # TODO: document this
  # @api public
  def gt
    DataMapper::Query::Operator.new(self, :gt)
  end

  # TODO: document this
  # @api public
  def gte
    DataMapper::Query::Operator.new(self, :gte)
  end

  # TODO: document this
  # @api public
  def lt
    DataMapper::Query::Operator.new(self, :lt)
  end

  # TODO: document this
  # @api public
  def lte
    DataMapper::Query::Operator.new(self, :lte)
  end

  # TODO: document this
  # @api public
  def not
    DataMapper::Query::Operator.new(self, :not)
  end

  def eql
    warn "explicit use of 'eql' operator is deprecated"
    DataMapper::Query::Operator.new(self, :eql)
  end

  # TODO: document this
  # @api public
  def like
    DataMapper::Query::Operator.new(self, :like)
  end

  def in
    warn "explicit use of 'in' operator is deprecated"
    DataMapper::Query::Operator.new(self, :in)
  end

  # TODO: document this
  # @api public
  def asc
    DataMapper::Query::Operator.new(self, :asc)
  end

  # TODO: document this
  # @api public
  def desc
    DataMapper::Query::Operator.new(self, :desc)
  end
end # class Symbol
