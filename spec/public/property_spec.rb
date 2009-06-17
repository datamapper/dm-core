# -*- coding: utf-8 -*-
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Property do

  # define the model prior to supported_by
  before :all do
    class ::Track
      include DataMapper::Resource

      property :id,               Serial
      property :artist,           String, :lazy => false, :index => :artist_album
      property :title,            String, :field => "name", :index => true
      property :album,            String, :index => :artist_album
      property :musicbrainz_hash, String, :unique => true, :unique_index => true
    end

    class ::Image
      include DataMapper::Resource

      property :md5hash,      String, :key => true, :length => 32
      property :title,        String, :nullable => false, :unique => true
      property :description,  Text,   :length => 1..1024, :lazy => true

      property :format,       String, :default => "jpeg"
      # WxH, stored as a dumped Ruby pair
      property :size,         Object
      property :filesize,     Float
      property :width,        Integer

      property :taken_on,     Date
      property :taken_at,     Time, :default => lambda { |resource, property| Time.now }
      property :retouched_at, DateTime
    end
  end

  supported_by :all do
    describe "#field" do
      it "returns @field value if it is present" do
        Track.properties[:title].field.should eql("name")
      end

      it 'returns field for specific repository when it is present'

      it 'sets field value using field naming convention on first reference'
    end

    describe "#unique?" do
      it "is true for fields that explicitly given uniq index" do
        Track.properties[:musicbrainz_hash].unique?.should be_true
      end

      it "is true for serial fields" do
        pending do
          Track.properties[:title].unique?.should be_true
        end
      end

      it "is true for keys" do
        Image.properties[:md5hash].unique?.should be_true
      end
    end

    describe "#eql?" do
      it 'is true for properties with the same model and name' do
        Track.properties[:title].should eql(Track.properties[:title])
      end


      it 'is false for properties of different models' do
        Track.properties[:title].should_not eql(Image.properties[:title])
      end

      it 'is false for properties with different names' do
        Track.properties[:title].should_not eql(Track.properties[:id])
      end
    end

    describe "#length" do
      it 'returns upper bound for Range values' do
        Image.properties[:description].length.should eql(1024)
      end

      it 'returns value as is for integer values' do
        Image.properties[:md5hash].length.should eql(32)
      end
    end

    describe "#index" do
      it 'returns true when property has an index' do
        Track.properties[:title].index.should be_true
      end

      it 'returns index name when property has a named index' do
        Track.properties[:album].index.should eql(:artist_album)
      end

      it 'returns nil when property has no index' do
        Track.properties[:musicbrainz_hash].index.should be_nil
      end
    end

    describe "#unique_index" do
      it 'returns true when property has unique index' do
        Track.properties[:musicbrainz_hash].unique_index.should be_true
      end

      it 'returns nil when property has no unique index' do
        Image.properties[:title].unique_index.should be_nil
      end
    end

    describe "#lazy?" do
      it 'returns true when property is lazy loaded' do
        Image.properties[:description].lazy?.should be_true
      end

      it 'returns false when property is not lazy loaded' do
        Track.properties[:artist].lazy?.should be_false
      end
    end

    describe "#key?" do
      describe 'returns true when property is a ' do
        it "serial key" do
          Track.properties[:id].key?.should be_true
        end
        it "natural key" do
          Image.properties[:md5hash].key?.should be_true
        end
      end

      it 'returns true when property is a part of composite key'

      it 'returns false when property does not relate to a key' do
        Track.properties[:title].key?.should be_false
      end
    end

    describe "#serial?" do
      it 'returns true when property is serial (auto incrementing)' do
        Track.properties[:id].serial?.should be_true
      end

      it 'returns false when property is NOT serial (auto incrementing)' do
        Image.properties[:md5hash].serial?.should be_false
      end
    end

    describe "#nullable?" do
      it 'returns true when property can accept nil as its value' do
        Track.properties[:artist].nullable?.should be_true
      end

      it 'returns false when property nil value is prohibited for this property' do
        Image.properties[:title].nullable?.should be_false
      end
    end

    describe "#custom?" do
      it "is true for custom type fields (not provided by dm-core)"

      it "is false for core type fields (provided by dm-core)"
    end

    describe "#get" do
      before :all do
        @image = Image.create(:md5hash     => "5268f0f3f452844c79843e820f998869",
                              :title       => "Rome at the sunset",
                              :description => "Just wow")

        @image.should be_saved

        @image = Image.first(:fields => [ :md5hash, :title ], :md5hash => @image.md5hash)
      end

      it 'triggers loading for lazy loaded properties' do
        Image.properties[:description].get(@image)
        Image.properties[:description].loaded?(@image).should be(true)
      end

      it 'assigns loaded value to @ivar' do
        Image.properties[:description].get(@image)
        @image.instance_variable_get(:@description).should == "Just wow"
      end

      it 'sets default value for new records with nil value' do
        Image.properties[:format].get(@image).should == "jpeg"
      end

      it 'returns property value' do
        Image.properties[:description].get(@image).should == "Just wow"
      end
    end

    describe "#get!" do
      before :all do
        @image = Image.new

        # now some dark Ruby magic
        @image.instance_variable_set(:@description, "Is set by magic")
      end

      it 'gets instance variable value from the resource directly' do
        # if you know a better way to test direct instance variable access,
        # go ahead and make changes to this example
        Image.properties[:description].get!(@image).should == "Is set by magic"
      end
    end

    # What's going on here:
    #
    # we first set original value and make an assertion on it
    # then we try to set it again, which clears original value
    # (since original value is set, property is no longer dirty)
    describe "#set_original_value" do
      before :all do
        @image = Image.create(:md5hash     => "5268f0f3f452844c79843e820f998869",
                              :title       => "Rome at the sunset",
                              :description => "Just wow")
        @image.reload
        @property = Image.properties[:title]
      end

      describe "when value changes" do
        before :all do
          @property.set_original_value(@image, "Rome at the sunset")
        end

        it 'sets original value of the property' do
          @image.original_attributes[@property].should == "Rome at the sunset"
        end
      end

      describe "when value stays the same" do
        before :all do
          @property.set_original_value(@image, "Rome at the sunset")
        end

        it 'only sets original value when it has changed' do
          @property.set_original_value(@image, "Rome at the sunset")
          @image.original_attributes[@property].should be_blank
        end
      end
    end

    describe "#set" do
      before :all do
        # keep in mind we must run these examples with a
        # saved model instance
        @image = Image.create(:md5hash     => "5268f0f3f452844c79843e820f998869",
                              :title       => "Rome at the sunset",
                              :description => "Just wow")
        @image.reload
        @property = Image.properties[:title]
      end

      it 'triggers lazy loading for given resource'

      it 'type casts given value' do
        # set it to a float
        @property.set(@image, 1.0)
        # get a string that has been typecasted
        @image.title.should == "1.0"
      end

      it 'stores original value' do
        @property.set(@image, "Updated value")
        @image.original_attributes[@property].should == "Rome at the sunset"
      end

      it 'sets new property value' do
        @property.set(@image, "Updated value")
        @image.title.should == "Updated value"
      end
    end

    describe "#set!" do
      before :all do
        @image = Image.new(:md5hash      => "5268f0f3f452844c79843e820f998869",
                           :title       => "Rome at the sunset",
                           :description => "Just wow")

        @property = Image.properties[:title]
      end

      it 'directly sets instance variable on given resource' do
        @property.set!(@image, "Set with dark Ruby magic")
        @image.title.should == "Set with dark Ruby magic"
      end
    end

    describe "#typecast" do
      describe "when type is able to do typecasting on it's own" do
        it 'delegates all the work to the type'
      end

      describe "when value is nil" do
        it 'returns value unchanged' do
          Image.properties[:size].typecast(nil).should be(nil)
        end
      end

      describe "when value is a Ruby primitive" do
        it 'returns value unchanged' do
          Image.properties[:size].typecast([3200, 2400]).should == [3200, 2400]
        end
      end

      describe "when type primitive is a string" do
        it 'returns string representation of the new value' do
          Image.properties[:title].typecast(1.0).should == "1.0"
        end
      end

      describe "when type primitive is a float" do
        it 'returns float representation of the value' do
          Image.properties[:filesize].typecast("24.34").should == 24.34
        end
      end

      describe "when type primitive is an integer" do
        describe "and value only has digits in it" do
          it 'returns integer representation of the value' do
            Image.properties[:width].typecast("24").should == 24
          end
        end

        it 'should return a negative integer when the value has a minus sign before digits' do
          Image.properties[:width].typecast("-24").should == -24
        end

        describe "and it has various valid presentations of 0" do
          it { Image.properties[:width].typecast(0).should == 0 }
          it { Image.properties[:width].typecast(0.0).should == 0 }
          it { Image.properties[:width].typecast("0").should == 0 }
          it { Image.properties[:width].typecast("0.0").should == 0 }
          it { Image.properties[:width].typecast("00").should == 0 }
          it { Image.properties[:width].typecast(BigDecimal("0.0")).should == 0 }
          it { Image.properties[:width].typecast(Rational(0,1)).should == 0 }
        end

        describe "but value has non-digits and punctuation in it" do
          it "returns value without typecasting" do
            Image.properties[:width].typecast('datamapper').should == 'datamapper'
          end
        end
      end

      describe "when type primitive is a BigDecimal" do
        it 'casts the value to BigDecimal'
      end

      describe "when type primitive is a DateTime" do
        describe "and value given as a hash with keys like :year, :month, etc" do
          it 'builds a DateTime instance from hash values' do
            result = Image.properties[:retouched_at].typecast({
                                                                :year  => 2006,
                                                                :month => 11,
                                                                :day   => 23,
                                                                :hour  => 12,
                                                                :min   => 0,
                                                                :sec   => 0
                                                              })
            result.year.should == 2006
            result.month.should == 11
            result.day.should == 23
            result.hour.should == 12
            result.min.should == 0
            result.sec.should == 0
          end
        end

        describe "and value is a string" do
          it 'parses the string' do
            Image.properties[:retouched_at].typecast("Dec, 2006").month.should == 12
          end
        end
      end

      describe "when type primitive is a Date" do
        describe "and value given as a hash with keys like :year, :month, etc" do
          it 'builds a Date instance from hash values' do
            result = Image.properties[:taken_on].typecast({
                                                            :year  => 2007,
                                                            :month => 03,
                                                            :day   => 25
                                                          })
            result.year.should == 2007
            result.month.should == 03
            result.day.should == 25
          end
        end

        describe "and value is a string" do
          it 'parses the string' do
            result = Image.properties[:taken_on].typecast("Dec 20th, 2006")
            result.month.should == 12
            result.day.should == 20
            result.year.should == 2006
          end
        end
      end

      describe "when type primitive is a Time" do
        describe "and value given as a hash with keys like :year, :month, etc" do
          it 'builds a Time instance from hash values' do
            result = Image.properties[:retouched_at].typecast({
                                                                :year  => 2006,
                                                                :month => 11,
                                                                :day   => 23,
                                                                :hour  => 12,
                                                                :min   => 0,
                                                                :sec   => 0
                                                              })
            result.year.should == 2006
            result.month.should == 11
            result.day.should == 23
            result.hour.should == 12
            result.min.should == 0
            result.sec.should == 0
          end
        end

        describe "and value is a string" do
          it 'parses the string' do
            result = Image.properties[:taken_at].typecast("22:24")
            result.hour.should == 22
            result.min.should == 24
          end
        end
      end

      describe "when type primitive is a Class" do
        it 'looks up constant in Property namespace'
      end
    end # #typecase

    describe "#default_for" do
      it 'returns default value for non-callables' do
        Image.properties[:format].default_for(Image.new).should == "jpeg"
      end

      it 'returns result of a call for callable values' do
        Image.properties[:taken_at].default_for(Image.new).year.should == Time.now.year
      end
    end

    describe "#value" do
      it 'returns value for core types'

      it 'triggers dump operation for custom types'
    end

    describe "#inspect" do
      before :all do
        @str = Track.properties[:title].inspect
      end

      it 'features model name' do
        @str.should =~ /@model=Track/
      end

      it 'features property name' do
        @str.should =~ /@name=:title/
      end
    end

    describe "#initialize" do
      describe "when tracking strategy is explicitly given" do
        it 'uses tracking strategy from options'
      end

      describe "when custom type has tracking stragegy" do
        it 'uses tracking strategy from type'
      end
    end
  end
end # DataMapper::Property
