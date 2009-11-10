# -*- coding: utf-8 -*-
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# instance methods
describe DataMapper::Property do

  # define the model prior to supported_by
  before :all do
    class ::Track
      include DataMapper::Resource

      property :id,               Serial
      property :artist,           String, :lazy => false, :index => :artist_album
      property :title,            String, :field => 'name', :index => true
      property :album,            String, :index => :artist_album
      property :musicbrainz_hash, String, :unique => true, :unique_index => true
    end

    class ::Image
      include DataMapper::Resource

      property :md5hash,      String, :key => true, :length => 32
      property :title,        String, :required => true, :unique => true
      property :description,  Text,   :length => 1..1024, :lazy => [ :detail ]
      property :format,       String, :default => 'jpeg'
      property :taken_at,     Time,   :default => proc { Time.now }
    end
  end

  supported_by :all do
    describe '#field' do
      it 'returns @field value if it is present' do
        Track.properties[:title].field.should eql('name')
      end

      it 'returns field for specific repository when it is present'

      it 'sets field value using field naming convention on first reference'
    end

    describe '#custom?' do
      it 'is true for custom type fields (not provided by dm-core)'

      it 'is false for core type fields (provided by dm-core)'
    end

    describe '#default_for' do
      it 'returns default value for non-callables' do
        Image.properties[:format].default_for(Image.new).should == 'jpeg'
      end

      it 'returns result of a call for callable values' do
        Image.properties[:taken_at].default_for(Image.new).year.should == Time.now.year
      end
    end

    describe '#eql?' do
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

    describe '#get' do
      before :all do
        @image = Image.create(:md5hash     => '5268f0f3f452844c79843e820f998869',
                              :title       => 'Rome at the sunset',
                              :description => 'Just wow')

        @image.should be_saved

        @image = Image.first(:fields => [ :md5hash, :title ], :md5hash => @image.md5hash)
      end

      it 'triggers loading for lazy loaded properties' do
        Image.properties[:description].get(@image)
        Image.properties[:description].loaded?(@image).should be(true)
      end

      it 'assigns loaded value to @ivar' do
        Image.properties[:description].get(@image)
        @image.instance_variable_get(:@description).should == 'Just wow'
      end

      it 'sets default value for new records with nil value' do
        Image.properties[:format].get(@image).should == 'jpeg'
      end

      it 'returns property value' do
        Image.properties[:description].get(@image).should == 'Just wow'
      end
    end

    describe '#get!' do
      before :all do
        @image = Image.new

        # now some dark Ruby magic
        @image.instance_variable_set(:@description, 'Is set by magic')
      end

      it 'gets instance variable value from the resource directly' do
        # if you know a better way to test direct instance variable access,
        # go ahead and make changes to this example
        Image.properties[:description].get!(@image).should == 'Is set by magic'
      end
    end

    describe '#index' do
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

    describe '#initialize' do
      describe 'when tracking strategy is explicitly given' do
        it 'uses tracking strategy from options'
      end

      describe 'when custom type has tracking stragegy' do
        it 'uses tracking strategy from type'
      end
    end

    describe '#inspect' do
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

    describe '#key?' do
      describe 'returns true when property is a ' do
        it 'serial key' do
          Track.properties[:id].key?.should be_true
        end
        it 'natural key' do
          Image.properties[:md5hash].key?.should be_true
        end
      end

      it 'returns true when property is a part of composite key'

      it 'returns false when property does not relate to a key' do
        Track.properties[:title].key?.should be_false
      end
    end

    describe '#lazy?' do
      it 'returns true when property is lazy loaded' do
        Image.properties[:description].lazy?.should be_true
      end

      it 'returns false when property is not lazy loaded' do
        Track.properties[:artist].lazy?.should be_false
      end
    end

    describe '#length' do
      it 'returns upper bound for Range values' do
        Image.properties[:description].length.should eql(1024)
      end

      it 'returns value as is for integer values' do
        Image.properties[:md5hash].length.should eql(32)
      end
    end

    describe '#min' do
      describe 'when :min and :max options not provided to constructor' do
        before do
          @property = Image.property(:integer_with_nil_min, Integer)
        end

        it 'should be nil' do
          @property.min.should be_nil
        end
      end

      describe 'when :min option not provided to constructor, but :max is provided' do
        before do
          @property = Image.property(:integer_with_default_min, Integer, :max => 1)
        end

        it 'should be the default value' do
          @property.min.should == 0
        end
      end

      describe 'when :min and :max options provided to constructor' do
        before do
          @min = 1
          @property = Image.property(:integer_with_explicit_min, Integer, :min => @min, :max => 2)
        end

        it 'should be the expected value' do
          @property.min.should == @min
        end
      end
    end

    describe '#max' do
      describe 'when :min and :max options not provided to constructor' do
        before do
          @property = Image.property(:integer_with_nil_max, Integer)
        end

        it 'should be nil' do
          @property.max.should be_nil
        end
      end

      describe 'when :max option not provided to constructor, but :min is provided' do
        before do
          @property = Image.property(:integer_with_default_max, Integer, :min => 1)
        end

        it 'should be the default value' do
          @property.max.should == 2**31-1
        end
      end

      describe 'when :min and :max options provided to constructor' do
        before do
          @max = 2
          @property = Image.property(:integer_with_explicit_max, Integer, :min => 1, :max => @max)
        end

        it 'should be the expected value' do
          @property.max.should == @max
        end
      end
    end

    describe '#allow_nil?' do
      it 'returns true when property can accept nil as its value' do
        Track.properties[:artist].allow_nil?.should be_true
      end

      it 'returns false when property nil value is prohibited for this property' do
        Image.properties[:title].allow_nil?.should be_false
      end
    end

    describe '#serial?' do
      it 'returns true when property is serial (auto incrementing)' do
        Track.properties[:id].serial?.should be_true
      end

      it 'returns false when property is NOT serial (auto incrementing)' do
        Image.properties[:md5hash].serial?.should be_false
      end
    end

    # What's going on here:
    #
    # we first set original value and make an assertion on it
    # then we try to set it again, which clears original value
    # (since original value is set, property is no longer dirty)
    describe '#set_original_value' do
      before :all do
        @image = Image.create(
          :md5hash     => '5268f0f3f452844c79843e820f998869',
          :title       => 'Rome at the sunset',
          :description => 'Just wow'
        )

        @property = Image.properties[:title]
      end

      describe 'when value changes' do
        before :all do
          @property.set_original_value(@image, 'New title')
        end

        it 'sets original value of the property' do
          @image.original_attributes[@property].should == 'Rome at the sunset'
        end
      end

      describe 'when value stays the same' do
        before :all do
          @property.set_original_value(@image, 'Rome at the sunset')
        end

        it 'only sets original value when it has changed' do
          @property.set_original_value(@image, 'Rome at the sunset')
          @image.original_attributes.should_not have_key(@property)
        end
      end
    end

    describe '#set' do
      before :all do
        # keep in mind we must run these examples with a
        # saved model instance
        @image = Image.create(
          :md5hash     => '5268f0f3f452844c79843e820f998869',
          :title       => 'Rome at the sunset',
          :description => 'Just wow'
        )

        @property = Image.properties[:title]
      end

      it 'triggers lazy loading for given resource'

      it 'type casts given value' do
        @property.set(@image, Addressable::URI.parse('http://test.example/'))
        # get a string that has been typecasted using #to_str
        @image.title.should == 'http://test.example/'
      end

      it 'stores original value' do
        @property.set(@image, 'Updated value')
        @image.original_attributes[@property].should == 'Rome at the sunset'
      end

      it 'sets new property value' do
        @property.set(@image, 'Updated value')
        @image.title.should == 'Updated value'
      end
    end

    describe '#set!' do
      before :all do
        @image = Image.new(:md5hash      => '5268f0f3f452844c79843e820f998869',
                           :title       => 'Rome at the sunset',
                           :description => 'Just wow')

        @property = Image.properties[:title]
      end

      it 'directly sets instance variable on given resource' do
        @property.set!(@image, 'Set with dark Ruby magic')
        @image.title.should == 'Set with dark Ruby magic'
      end
    end

    describe '#unique?' do
      it 'is true for fields that explicitly given uniq index' do
        Track.properties[:musicbrainz_hash].unique?.should be_true
      end

      it 'is true for serial fields' do
        pending do
          Track.properties[:title].unique?.should be_true
        end
      end

      it 'is true for keys' do
        Image.properties[:md5hash].unique?.should be_true
      end
    end

    describe '#unique_index' do
      it 'returns true when property has unique index' do
        Track.properties[:musicbrainz_hash].unique_index.should be_true
      end

      it 'returns nil when property has no unique index' do
        Image.properties[:title].unique_index.should be_nil
      end
    end
  end
end # DataMapper::Property
