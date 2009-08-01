share_examples_for 'A valid query condition' do
  before :all do
    raise "+@comp+ should be defined in before block" unless instance_variable_get(:@comp)
  end

  it 'should be valid' do
    @comp.should be_valid
  end
end
