require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

gem 'fastercsv', '>=1.2.3'
require 'fastercsv'

if ADAPTER
  module TypeTests
    class Impostor < DataMapper::Type
      primitive String
    end

    class Coconut
      include DataMapper::Resource

      storage_names[ADAPTER] = 'coconuts'

      def self.default_repository_name
        ADAPTER
      end

      property :id, Serial
      property :faked, Impostor
      property :active, Boolean
      property :note, Text
    end
  end

  class Lemon
    include DataMapper::Resource

    def self.default_repository_name
      ADAPTER
    end

    property :id, Serial
    property :color, String
    property :deleted_at, DataMapper::Types::ParanoidDateTime
  end

  class Lime
    include DataMapper::Resource

    def self.default_repository_name
      ADAPTER
    end

    property :id, Serial
    property :color, String
    property :deleted_at, DataMapper::Types::ParanoidBoolean
  end

  describe DataMapper::Type, "with #{ADAPTER}" do
    before do
      TypeTests::Coconut.auto_migrate!(ADAPTER)

      @document = <<-EOS.margin
        NAME, RATING, CONVENIENCE
        Freebird's, 3, 3
        Whataburger, 1, 5
        Jimmy John's, 3, 4
        Mignon, 5, 2
        Fuzi Yao's, 5, 1
        Blue Goose, 5, 1
      EOS

      @stuff = YAML::dump({ 'Happy Cow!' => true, 'Sad Cow!' => false })

      @active = true
      @note = "This is a note on our ol' guy bob"
    end

    it "should instantiate an object with custom types" do
      coconut = TypeTests::Coconut.new(:faked => 'bob', :active => @active, :note => @note)
      coconut.faked.should == 'bob'
      coconut.active.should be_a_kind_of(TrueClass)
      coconut.note.should be_a_kind_of(String)
    end

    it "should CRUD an object with custom types" do
      repository(ADAPTER) do
        coconut = TypeTests::Coconut.new(:faked => 'bob', :active => @active, :note => @note)
        coconut.save.should be_true
        coconut.id.should_not be_nil

        fred = TypeTests::Coconut.get!(coconut.id)
        fred.faked.should == 'bob'
        fred.active.should be_a_kind_of(TrueClass)
        fred.note.should be_a_kind_of(String)

        note = "Seems like bob is just mockin' around"
        fred.note = note

        fred.save.should be_true

        active = false
        fred.active = active

        fred.save.should be_true

        # Can't call coconut.reload since coconut.collection isn't setup.
        mac = TypeTests::Coconut.get!(fred.id)
        mac.active.should == active
        mac.note.should == note
      end
    end

    it "should respect paranoia with a datetime" do
      Lemon.auto_migrate!(ADAPTER)

      lemon = nil

      repository(ADAPTER) do |repository|
        lemon = Lemon.new
        lemon.color = 'green'

        lemon.save
        lemon.destroy

        lemon.deleted_at.should be_kind_of(DateTime)
      end

      repository(ADAPTER) do |repository|
        Lemon.all.should be_empty
        Lemon.get(lemon.id).should be_nil
      end
    end

    it "should respect paranoia with a boolean" do
      Lime.auto_migrate!(ADAPTER)

      lime = nil

      repository(ADAPTER) do |repository|
        lime = Lime.new
        lime.color = 'green'

        lime.save
        lime.destroy

        lime.deleted_at.should be_kind_of(TrueClass)
      end

      repository(ADAPTER) do |repository|
        Lime.all.should be_empty
        Lime.get(lime.id).should be_nil
      end
    end
  end
end
