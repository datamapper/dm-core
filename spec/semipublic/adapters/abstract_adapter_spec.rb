require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe 'AbstractAdapter' do
  before :all do
    @adapter = DataMapper::Adapters::AbstractAdapter.new(:abstract, {})
    @adapter_class = @adapter.class
    @scheme        = Extlib::Inflection.underscore(Extlib::Inflection.demodulize(@adapter_class).chomp('adapter'))
    @adapter_name  = "test_#{@scheme}".to_sym
  end

  describe 'initialization' do
    before :all do
      @options = {
        :adapter  => @scheme,
        :user     => 'paul',
        :password => 'secret',
        :host     => 'hostname',
        :port     => 12345,
        :path     => '/tmp',
        # non-uri option pair
        :foo      => 'bar'
      }

      @keys_renamed_from_uri = {
        :scheme => :adapter,
        :username => :user
      }

    end

    describe 'name' do
      before :all do
        @a = @adapter_class.new(@adapter_name, @options)
      end

      it 'should have a name' do
        @a.name.should == @adapter_name
      end

      it 'should require name to be a symbol' do
        lambda {
          @adapter_class.new("somestring", @options)
        }.should raise_error(ArgumentError)
      end
    end

    share_examples_for '#options' do

      it 'should have #options as an extlib mash' do
        @a.options.should be_kind_of(Mash)
      end

      it 'should have all the right values for #options' do
        @options.each { |k,v| @a.options[k].should == v }
      end

    end

    describe 'from an options Hash' do

      before :all do
        @a = @adapter_class.new(@adapter_name, @options)
      end

      it_should_behave_like '#options'

      it 'should not rename any keys from the options' do
        options = {:adapter => @scheme,
                   :scheme => 'scheme',
                   :database => 'database',
                   :username => 'username',
                   :path     => 'path'}

        a = @adapter_class.new(@adapter_name, options)

        options.each { |k,v| a.options[k].should == v }
      end

    end

    describe 'from a String uri' do
      before :all do
        uri = "#{@scheme}://paul:secret@hostname:12345/tmp?foo=bar"

        @a = @adapter_class.new(@adapter_name, uri)
      end

      it_should_behave_like '#options'

      it 'should rename some of the keys from the uri' do
        @keys_renamed_from_uri.each do |old, new|
          @a.options.should_not have_key(old)
          @a.options[new].should == @options[new]
        end
      end

    end

    describe 'from an Addressable uri' do
      before :all do
        @uri = Addressable::URI.parse("#{@scheme}://paul:secret@hostname:12345/tmp?foo=bar")
        @a = @adapter_class.new(@adapter_name, @uri)
      end

      it_should_behave_like '#options'

      it 'should rename some of the keys from the uri' do
        @keys_renamed_from_uri.each do |old, new|
          @a.options.should_not have_key(old)
          @a.options[new].should == @options[new]
        end
      end

    end

  end

end
