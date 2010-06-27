require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# instance methods
describe DataMapper::Property do
  describe ".find_class" do
    [ :Serial, :Text ].each do |type|
      describe "with #{type}" do
        subject { DataMapper::Property.find_class(type) }

        it { subject.should be(DataMapper::Property.const_get(type)) }
      end
    end
  end

  describe ".determine_class" do
    [ Integer, String, Float, Class, String, Time, DateTime, Date ].each do |type|
      describe "with #{type}" do
        subject { DataMapper::Property.determine_class(type) }

        it { subject.should be(DataMapper::Property.const_get(type.name)) }
      end
    end

    describe "with custom types" do
      before :all do
        module ::CustomProps
          class Property
            class Hash  < DataMapper::Property::Object; end
            class Other < DataMapper::Property::Object; end
          end
        end
      end

      describe "with ::Foo::Property::Hash" do
        subject { DataMapper::Property.determine_class(Hash) }

        it { subject.should be(::CustomProps::Property::Hash) }
      end

      describe "with ::Foo::Property::Other" do
        subject { DataMapper::Property.determine_class(::CustomProps::Property::Other) }

        it { subject.should be(::CustomProps::Property::Other) }
      end
    end
  end

  before :all do
    module ::Blog
      class Author
        include DataMapper::Resource

        property :id,         Integer, :key => true
        property :name,       String
        property :rating,     Float
        property :rate,       Decimal
        property :type,       Class
        property :alias,      String
        property :active,     Boolean
        property :deleted_at, Time
        property :created_at, DateTime
        property :created_on, Date
        property :info,       Text
      end
    end

    @model = Blog::Author
  end

  describe 'override property definition in other repository' do
    before(:all) do
      module ::Blog
        class Author
          repository(:other) do
            property :name,  String, :key => true, :field => 'other_name'
          end
        end
      end
    end

    it 'should return property options in other repository' do
      @model.properties(:other)[:name].options[:field].should == 'other_name'
    end

    it 'should return property options in default repository' do
      @model.properties[:name].options[:field].should be_nil
    end
  end
end
