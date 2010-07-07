require File.expand_path(File.join(File.dirname(__FILE__), '../..', 'spec_helper'))
require 'dm-core/property/lookup'

describe DataMapper::Property::Lookup do
  supported_by :all do
    before(:all) do
      @klass = Class.new { extend DataMapper::Model }

      DataMapper::Types::LegacyType = Class.new(DataMapper::Types::Text)
    end

    it "should provide access to Property classes" do
      @klass::Serial.should == DataMapper::Property::Serial
    end

    it "should provide access to legacy Types" do
      @klass::LegacyType.should be(DataMapper::Types::LegacyType)
    end

    it "should not provide access to unknown Property classes" do
      lambda {
        @klass::Bla
      }.should raise_error(NameError)
    end
  end
end
