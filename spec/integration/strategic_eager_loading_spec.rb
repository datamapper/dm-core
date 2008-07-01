require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require 'pp'

def hr(word = nil)
  width = 80
  return puts("="*width) if word.nil?

  word = "[ #{word.upcase} ]"
  middle = width/2
  middle_word = word.size/2
  end_word = middle + middle_word
  print '='*(end_word - word.size), word, '='*(width - end_word), "\n"
end

# DataMapper::Logger.new(STDOUT, 0)
# DataObjects::Sqlite3.logger = DataObjects::Logger.new(STDOUT, 0)
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
      Exhibit.create(:name => "Insectorium", :zoo_id => 2)
      Exhibit.create(:name => "Bears", :zoo_id => 2)
      Animal.create(:name => "Bald Eagle", :exhibit_id => 2)
      Animal.create(:name => "Parakeet", :exhibit_id => 2)
      Animal.create(:name => "Roach", :exhibit_id => 3)
      Animal.create(:name => "Brown Bear", :exhibit_id => 4)
    end

  end

  it "should eager load children" do
    zoo_ids     = Zoo.all.map { |z| z.key }
    exhibit_ids = Exhibit.all.map { |e| e.key }

    repository(ADAPTER) do
      zoos = Zoo.all.entries # load all zoos
      dallas = zoos.find { |z| z.name == 'Dallas Zoo' }

      dallas.exhibits.entries # load all exhibits for zoos in identity_map
      dallas.exhibits.size.should == 1
      repository.identity_map(Zoo).keys.sort.should == zoo_ids
      repository.identity_map(Exhibit).keys.sort.should == exhibit_ids
      zoos.each { |zoo| zoo.exhibits.entries } # issues no queries
      dallas.exhibits << Exhibit.new(:name => "Reptiles")
      dallas.exhibits.size.should == 2
      dallas.save
    end
    repository(ADAPTER) do
      Zoo.first.exhibits.size.should == 2
    end
  end

  it "should not eager load children when a query is provided" do
    repository(ADAPTER) do
      dallas = Zoo.all.entries.find { |z| z.name == 'Dallas Zoo' }
      exhibits = dallas.exhibits.entries # load all exhibits
      reptiles = dallas.exhibits(:name => 'Reptiles')
      reptiles.size.should == 1
      primates = dallas.exhibits(:name => 'Primates')
      primates.size.should == 1
      primates.should_not == reptiles
    end
  end

  it "should eager load parents" do
    animal_ids  = Animal.all.map { |a| a.key }
    exhibit_ids = Exhibit.all.map { |e| e.key }.sort
    exhibit_ids.pop # remove Reptile exhibit, which has no Animals

    repository(ADAPTER) do
      animals = Animal.all.entries
      bear = animals.find { |a| a.name == 'Brown Bear' }
      bear.exhibit
      repository.identity_map(Animal).keys.sort.should == animal_ids
      repository.identity_map(Exhibit).keys.sort.should == exhibit_ids
    end
  end

  it "should not eager load parents when parent is in IM" do
    repository(ADAPTER) do
      animal = Animal.first
      exhibit = Exhibit.get(1) # load exhibit into IM
      animal.exhibit # load exhibit from IM
      repository.identity_map(Exhibit).keys.should == [exhibit.key]
    end
  end
end