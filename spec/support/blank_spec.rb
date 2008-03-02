require File.dirname(__FILE__) + "/../spec_helper"

describe DataMapper::Support do
  it "should mark empty objects as blank" do
    [ nil, false, '', '   ', "  \n\t  \r ", [], {} ].each { |f| f.should be_blank }
    [ Object.new, true, 0, 1, 'a', [nil], { nil => 0 } ].each { |t| t.should_not be_blank }
  end
end
