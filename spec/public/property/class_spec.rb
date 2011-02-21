require 'spec_helper'

describe DataMapper::Property::Class do
  before :all do
    Object.send(:remove_const, :Foo) if defined?(Foo)
    Object.send(:remove_const, :Bar) if defined?(Bar)

    class ::Foo; end
    class ::Bar; end

    @name  = :type
    @type  = DataMapper::Property::Class
    @primitive = Class
    @value = Foo
    @other_value = Bar
    @invalid_value = 1
  end

  it_should_behave_like "A public Property"
end
