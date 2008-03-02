describe DataMapper::Support::String do
  
  it "should translate" do
    "%s is great!".t('DataMapper').should eql("DataMapper is great!")
  end
  
end
