share_examples_for 'A semipublic Property' do
  before :all do
    %w[ @type @name @value @other_value ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_defined?(ivar)
    end

    module ::Blog
      class Article
        include DataMapper::Resource
        property :id, Serial
      end
    end

    @model      = Blog::Article
    @options  ||= {}
    @property   = @type.new(@model, @name, @options)
  end

  describe '.new' do
    describe 'when provided no options' do
      it 'should return a Property' do
        @property.should be_kind_of(@type)
      end

      it 'should set the load_as' do
        @property.load_as.should be(@type.load_as)
      end

      it 'should set the model' do
        @property.model.should equal(@model)
      end

      it 'should set the options to the default' do
        @property.options.should == @type.options.merge(@options)
      end
    end

    [ :index, :unique_index, :unique, :lazy ].each do |attribute|
      [ true, false, :title, [ :title ] ].each do |value|
        describe "when provided #{(options = { attribute => value }).inspect}" do
          before :all do
            @property = @type.new(@model, @name, @options.merge(options))
          end

          it 'should return a Property' do
            @property.should be_kind_of(@type)
          end

          it 'should set the model' do
            @property.model.should equal(@model)
          end

          it 'should set the load_as' do
            @property.load_as.should be(@type.load_as)
          end

          it "should set the options to #{options.inspect}" do
            @property.options.should == @type.options.merge(@options.merge(options))
          end
        end
      end

      [ [], nil ].each do |value|
        describe "when provided #{(invalid_options = { attribute => value }).inspect}" do
          it 'should raise an exception' do
            lambda {
              @type.new(@model, @name, @options.merge(invalid_options))
            }.should raise_error(ArgumentError, "options[#{attribute.inspect}] must be either true, false, a Symbol or an Array of Symbols")
          end
        end
      end
    end
  end

  describe '#load' do
    subject { @property.load(@value) }

    before do
      @property.should_receive(:typecast).with(@value).and_return(@value)
    end

    it { should eql(@value) }
  end

  describe "#typecast" do
    describe 'when value is nil' do
      it 'returns value unchanged' do
        @property.typecast(nil).should be(nil)
      end

      describe 'when value is a Ruby primitive' do
        it 'returns value unchanged' do
          @property.typecast(@value).should == @value
        end
      end
    end
  end

  describe '#valid?' do
    describe 'when provided a valid value' do
      it 'should return true' do
        @property.valid?(@value).should be(true)
      end
    end

    describe 'when provide an invalid value' do
      it 'should return false' do
        @property.valid?(@invalid_value).should be(false)
      end
    end

    describe 'when provide a nil value when required' do
      it 'should return false' do
        @property = @type.new(@model, @name, @options.merge(:required => true))
        @property.valid?(nil).should be(false)
      end
    end

    describe 'when provide a nil value when not required' do
      it 'should return false' do
        @property = @type.new(@model, @name, @options.merge(:required => false))
        @property.valid?(nil).should be(true)
      end
    end
  end

  describe '#assert_valid_value' do
    subject do
      @property.assert_valid_value(value)
    end

    shared_examples_for 'assert_valid_value on invalid value' do
      it 'should raise DataMapper::Property::InvalidValueError' do
        expect { subject }.to(raise_error(DataMapper::Property::InvalidValueError) do |error|
          error.property.should == @property
        end)
      end
    end

    describe 'when provided a valid value' do
      let(:value) { @value }

      it 'should return true' do
        subject.should be(true)
      end
    end

    describe 'when provide an invalid value' do
      let(:value) { @invalid_value }
      
      it_should_behave_like 'assert_valid_value on invalid value'
    end

    describe 'when provide a nil value when required' do
      before do
        @property = @type.new(@model, @name, @options.merge(:required => true))
      end

      let(:value) { nil }

      it_should_behave_like 'assert_valid_value on invalid value'
    end

    describe 'when provide a nil value when not required' do
      before do
        @property = @type.new(@model, @name, @options.merge(:required => false))
      end

      let(:value) { nil }

      it 'should return true' do
        subject.should be(true)
      end
    end
  end
end
