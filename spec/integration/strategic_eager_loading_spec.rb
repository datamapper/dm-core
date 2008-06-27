require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require 'pp'
DataMapper::Logger.new(STDOUT, 0)
DataObjects::Sqlite3.logger = DataObjects::Logger.new(STDOUT, 0)
describe "Strategic Eager Loading" do
  before :all do

    class Zoo
      include DataMapper::Resource
      def self.default_repository_name; ADAPTER end

      property :id, Serial
      property :name, String

      has n, :exhibits
    end

    class Exhibit
      include DataMapper::Resource
      def self.default_repository_name; ADAPTER end

      property :id, Serial
      property :name, String

      belongs_to :zoo
      has n, :animals
    end

    class Animal
      include DataMapper::Resource
      def self.default_repository_name; ADAPTER end

      property :id, Serial
      property :name, String

      belongs_to :exhibit
    end

    [Zoo, Exhibit, Animal].each { |k| k.auto_migrate!(ADAPTER) }

    repository(ADAPTER) do
      Zoo.create(:name => "Dallas Zoo")
      Exhibit.create(:name => "Primates", :zoo_id => 1)
      Animal.create(:name => "Chimpanzee", :exhibit_id => 1)
      Animal.create(:name => "Orangutan", :exhibit_id => 1)

      Zoo.create(:name => "San Diego")
      Exhibit.create(:name => "Aviary", :zoo_id => 2)
      Animal.create(:name => "Bald Eagle", :exhibit_id => 2)
      Animal.create(:name => "Parakeet", :exhibit_id => 2)
    end

  end

  it "should eager load one relationship deep" do
    zoo_ids     = Zoo.all.map { |z| z.key }
    exhibit_ids = Exhibit.all.map { |e| e.key }

    repository(ADAPTER) do
      zoos = Zoo.all.entries # load all zoos
      dallas = zoos.find { |z| z.name == 'Dallas Zoo' }
      # exhibits = Exhibit.all.entries
      dallas.exhibits.entries # load all exhibits for zoos in identity_map
      dallas.exhibits.size.should == 1
      repository.identity_map(Zoo).keys.should == zoo_ids
      repository.identity_map(Exhibit).keys.should == exhibit_ids
      zoos.each { |zoo| pp zoo.exhibits.entries } # issues no queries
    end
  end

  it "should eager load two deep" do
    pending
    animals = Animal.all.map { |e| e.key }

    repository(ADAPTER) do

    end
  end
end