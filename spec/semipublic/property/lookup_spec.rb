require File.expand_path(File.join(File.dirname(__FILE__), '../..', 'spec_helper'))
require 'dm-core/property/lookup'

describe DataMapper::Property::Lookup do
  supported_by :all do
    before(:all) do
      @klass = Class.new { extend DataMapper::Model }

      DataMapper::Types::LegacyType = Class.new(DataMapper::Types::Text)

      module Foo
        class OtherProperty < DataMapper::Property::String; end
      end
    end

    it "should provide access to Property classes" do
      @klass::Serial.should == DataMapper::Property::Serial
    end

    it "should provide access to Property classes from outside of the Property namespace" do
      @klass::OtherProperty.should be(Foo::OtherProperty)
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
