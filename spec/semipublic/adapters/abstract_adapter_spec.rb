require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe 'DataMapper::Adapters::AbstractAdapter' do

  describe 'initialization' do
    before do
      @adapter_name = :test_abstract
      @options = {
        :scheme   => 'scheme',
        :user     => 'username',
        :password => 'pass',
        :host     => 'hostname',
        :port     => 12345,
        :path     => '/some/path',
        :fragment => 'frag',
        # non-uri option pair
        :foo      => 'bar'
      }

    end

    describe 'name' do
      before do
        @aa = DataMapper::Adapters::AbstractAdapter.new(@adapter_name, @options)
      end
      it 'should have a name' do
        @aa.name.should == :test_abstract
      end

      it 'should require name to be a symbol' do
        lambda {
          DataMapper::Adapters::AbstractAdapter.new("somestring", @options)
        }.should raise_error(ArgumentError)
      end
    end

    describe 'uri_or_options' do
      before do
        @uri = Addressable::URI.new(@options)
        @uri.query_values = {'foo' => 'bar'} # URI.new doesn't import unknown keys as query params
        @uri_str = @uri.to_s
      end

      share_examples_for '#uri and #options' do

        it 'should have #uri as an Addressable::URI' do
          @aa.uri.should be_kind_of(Addressable::URI)
        end

        it 'should have the right value for #uri' do
          @aa.uri.should == @uri
        end

        it 'should have #options as a hash' do
          @aa.options.should be_kind_of(Hash)
        end

        it 'should have all the right values for #options' do
          @options.each { |k,v|
            @aa.options[k].should == v
          }
        end

      end

      describe 'from a String uri' do
        before do
          @aa = DataMapper::Adapters::AbstractAdapter.new(@adapter_name, @uri_str)
        end

        it_should_behave_like '#uri and #options'

      end

      describe 'from an Addressable uri' do
        before do
          @aa = DataMapper::Adapters::AbstractAdapter.new(@adapter_name, @uri)
        end

        it_should_behave_like '#uri and #options'

      end

      describe 'from an options Hash' do
        before do
          @aa = DataMapper::Adapters::AbstractAdapter.new(@adapter_name, @options)
        end

        it_should_behave_like '#uri and #options'

      end
    end

  end
end

