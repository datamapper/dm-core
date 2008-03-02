require File.dirname(__FILE__) + "/../spec_helper"

describe DataMapper::Support::Serialization do
  
  before(:all) do
    fixtures(:animals)
    fixtures(:zoos)
  end
  
  it "should serialize to YAML" do
    Animal.first(:name => 'Frog').to_yaml.strip.should == <<-EOS.margin
      --- 
      id: 1
      name: Frog
      notes: I am a Frog!
      nice: false
    EOS
  end
  
  it "should serialize to XML" do
    Animal.first(:name => 'Frog').to_xml.should == <<-EOS.compress_lines(false)
      <animal id="1">
        <name>Frog</name>
        <notes>I am a Frog!</notes>
        <nice>false</nice>
      </animal>
    EOS
    
    san_diego_zoo = Zoo.first(:name => 'San Diego')
    san_diego_zoo.to_xml.should == <<-EOS.compress_lines(false)
      <zoo id="2">
        <name>San Diego</name>
        <notes/>
        <updated_at>#{san_diego_zoo.updated_at.dup}</updated_at>
      </zoo>
    EOS
  end
  
  it "should serialize to JSON" do
    
    Animal.first(:name => 'Frog').to_json.should == <<-EOS.compress_lines
      {
        "id": 1,
        "name": "Frog",
        "notes": "I am a Frog!",
        "nice": false
      }
    EOS
    
    san_diego_zoo = Zoo.first(:name => 'San Diego')
    san_diego_zoo.to_json.should == <<-EOS.compress_lines
      {
        "id": 2,
        "name": "San Diego",
        "notes": null,
        "updated_at": #{san_diego_zoo.updated_at.dup.to_json}
      }
    EOS
  end
  
end