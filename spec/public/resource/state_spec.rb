require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe 'DataMapper::Resource' do
  before :all do
    class ::Author
      include DataMapper::Resource

      property :id,        Serial
      property :string_,   String
      property :bool_,     Boolean
      property :float_,    Float
      property :integer_,  Integer
      property :decimal_,  Decimal
      property :datetime_, DateTime
      property :date_,     Date
      property :time_,     Time
    end

    DataMapper.finalize

    @model = Author
  end

  supported_by :all do
    before do
      @values = {
        :string_   => Addressable::URI.parse('http://test.example/'),
        :bool_     => true,
        :float_    => 2.5,
        :integer_  => 10,
        :decimal_  => BigDecimal.new("999.95"),
        :datetime_ => DateTime.parse('2010-10-11 12:13:14+0'),
        :date_     => Date.parse('2010-10-11 12:13:14+0'),
        :time_     => Time.parse('2010-10-11 12:13:14+0'),
      }
      @string_values = {
        :string_ => 'http://test.example/',
        :decimal_ => '999.95',
      }

      @resource = @model.create(@values)
    end

    describe '.new' do
      subject { @resource }

      it { should_not be_dirty }
    end

    [:string_, :bool_, :float_, :integer_, :decimal_, :datetime_, :date_, :time_].each do |property|
      describe "#{property.to_s[0...-1]} property mutator" do
        before do
          @resource.send("#{property}=", @string_values[property] || @values[property].to_s)
        end

        it 'type casts given equal value so resource remains clean' do
          @resource.should_not be_dirty
        end
      end

      describe "#attribute_set for #{property.to_s[0...-1]} property" do
        before do
          @resource.attribute_set(property, @string_values[property] || @values[property].to_s)
        end

        it 'type casts given equal value so resource remains clean' do
          @resource.should_not be_dirty
        end
      end
    end
  end
end
