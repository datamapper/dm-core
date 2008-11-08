require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe "Resource" do
  before(:each) do
    Object.send(:remove_const, Track) if defined?(Track)

    class Track
      include DataMapper::Resource

      property :id,     Serial
      property :artist, String
      property :title,  String, :field => :name
      property :album,  String
    end

    DataMapper.auto_migrate!
  end

  describe "#field" do
    it "returns @field value if it is present"

    it 'returns field for specific repository when it is present'

    it 'sets field value using field naming convention on first reference'
  end

  describe "#unique" do
    it "is true for fields that explicitly given uniq index"

    it "is true for serial fields"

    it "is true for keys"
  end

  describe "#hash" do
    it 'triggers binding of unbound custom types'

    it 'concats hashes of model name and property name'
  end

  describe "#equal?" do
    it 'is true for properties with the same model and name'

    it 'is false for properties of different models'

    it 'is false for properties with different names'
  end

  describe "#length" do
    it 'returns upper bound for Range values'

    it 'returns value as is for integer values'
  end

  describe "#index" do
    it 'returns index name when property has an index'

    it 'returns nil when property has no index'
  end

  describe "#unique_index" do
    it 'returns true when property has unique index'

    it 'returns false when property has no unique index'
  end

  describe "#lazy?" do
    it 'returns true when property is lazy loaded'

    it 'returns false when property is not lazy loaded'
  end

  describe "#key?" do
    it 'returns true when property is a key'

    it 'returns true when property is a part of composite key'

    it 'returns false when property does not relate to a key'
  end

  describe "#serial?" do
    it 'returns true when property is serial (auto incrementing)'

    it 'returns false when property is NOT serial (auto incrementing)'
  end

  describe "#nullable?" do
    it 'returns true when property can accept nil as its value'

    it 'returns false when property nil value is prohibited for this property'
  end

  describe "#custom?" do
    it "is true for custom type fields (not provided by dm-core)"

    it "is false for core type fields (provided by dm-core)"
  end
end
