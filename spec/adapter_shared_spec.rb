
describe "a DataMapper Adapter", :shared => true do

  it "should initialize the connection uri" do
    new_adapter = @adapter.class.new(:default, 'some://uri/string')
    new_adapter.instance_variable_get('@uri').should == 'some://uri/string'
  end

  %w{create read update delete read_one read_set delete_set} .each do |meth|
    it "should have a #{meth} method" do
      @adapter.should respond_to(meth.intern)
    end
  end

end

