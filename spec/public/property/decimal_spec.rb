require 'spec_helper'

describe DataMapper::Property::Decimal do
  before :all do
    @name          = :rate
    @type          = DataMapper::Property::Decimal
    @options       = { :precision => 5, :scale => 2 }
    @primitive     = BigDecimal
    @value         = BigDecimal('1.0')
    @other_value   = BigDecimal('2.0')
    @invalid_value = true
  end

  it_should_behave_like "A public Property"
end
