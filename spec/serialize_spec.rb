require File.dirname(__FILE__) + "/spec_helper"

describe('An AR serialize implementation') do
  
  it 'should instatiate, save, (clear and load) the original objects' do
    test_data = { :first => 1, :second => "dos", :third => 3.0 }

    srlzr1 = Serializer.new(:content => test_data)
    srlzr1.content.should == test_data
    
    srlzr1.save
    srlzr1.content.should == test_data
    
    srlzr1 = nil
    srlzr2 = Serializer.first
    srlzr2.content.should == test_data
  end

end