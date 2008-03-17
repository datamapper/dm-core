
describe "a DataMapper Adapter", :shared => true do

  it "should initialize the connection uri" do
    new_adapter = @adapter.class.new('some://uri/string')
    new_adapter.instance_variable_get('@uri').should == 'some://uri/string'
  end

  %w{create read first all update delete save} .each do |meth|
    it "should have a #{meth} method" do
      @adapter.should respond_to(meth.intern)
    end
  end

end

