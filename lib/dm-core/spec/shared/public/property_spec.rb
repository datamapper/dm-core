share_examples_for 'A public Property' do
  before :all do
    %w[ @type @primitive @name @value @other_value ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_defined?(ivar)
    end

    module ::Blog
      class Article
        include DataMapper::Resource
        property :id, Serial
      end
    end

    @model     = Blog::Article
    @options ||= {}
  end

  describe "with a sub-type" do
    before :all do
      class ::SubType < @type; end
      @subtype = ::SubType
      @type.accept_options :foo, :bar
    end

    before :all do
      @original = @type.accepted_options.dup
    end

    after :all do
      @type.accepted_options.replace(@original - [ :foo, :bar ])
    end

    describe "predefined options" do
      before :all do
        class ::ChildSubType < @subtype
          default nil
        end
        @child_subtype = ChildSubType
      end

      describe "when parent type overrides a default" do
        before do
          @subtype.default "foo"
        end

        after do
          DataMapper::Property.descendants.delete(ChildSubType)
          Object.send(:remove_const, :ChildSubType)
        end

        it "should not override the child's type setting" do
          @child_subtype.default.should eql(nil)
        end
      end
    end

    after :all do
      DataMapper::Property.descendants.delete(SubType)
      Object.send(:remove_const, :SubType)
    end

    describe ".accept_options" do
      describe "when provided :foo, :bar" do
        it "should add new options" do
          [@type, @subtype].each do |type|
            type.accepted_options.include?(:foo).should be(true)
            type.accepted_options.include?(:bar).should be(true)
          end
        end

        it "should create predefined option setters" do
          [@type, @subtype].each do |type|
            type.should respond_to(:foo)
            type.should respond_to(:bar)
          end
        end

        describe "auto-generated option setters" do
          before :all do
            @type.foo true
            @type.bar 1
            @property = @type.new(@model, @name, @options)
          end

          it "should set the pre-defined option values" do
            @property.options[:foo].should == true
            @property.options[:bar].should == 1
          end

          it "should ask the superclass for the value if unknown" do
            @subtype.foo.should == true
            @subtype.bar.should == 1
          end
        end
      end
    end

    describe ".descendants" do
      it "should include the sub-type" do
        @type.descendants.include?(SubType).should be(true)
      end
    end

    describe ".primitive" do
      it "should return the primitive class" do
        [@type, @subtype].each do |type|
          type.primitive.should be(@primitive)
        end
      end

      it "should change the primitive class" do
        @subtype.primitive Object
        @subtype.primitive.should be(Object)
      end
    end
  end

  [:allow_blank, :allow_nil].each do |opt|
    describe "##{method = "#{opt}?"}" do
      [true, false].each do |value|
        describe "when created with :#{opt} => #{value}" do
          before :all do
            @property = @type.new(@model, @name, @options.merge(opt => value))
          end

          it "should return #{value}" do
            @property.send(method).should be(value)
          end
        end
      end

      describe "when created with :#{opt} => true and :required => true" do
        it "should fail with ArgumentError" do
          lambda {
            @property = @type.new(@model, @name, @options.merge(opt => true, :required => true))
          }.should raise_error(ArgumentError,
            "options[:required] cannot be mixed with :allow_nil or :allow_blank")
        end
      end
    end
  end

  [:key?, :required?, :index, :unique_index, :unique?].each do |method|
    describe "##{method}" do
      [true, false].each do |value|
        describe "when created with :#{method} => #{value}" do
          before :all do
            opt = method.to_s.chomp('?').to_sym
            @property = @type.new(@model, @name, @options.merge(opt => value))
          end

          it "should return #{value}" do
            @property.send(method).should be(value)
          end
        end
      end
    end
  end

  describe "#lazy?" do
    describe "when created with :lazy => true, :key => false" do
      before :all do
        @property = @type.new(@model, @name, @options.merge(:lazy => true, :key => false))
      end

      it "should return true" do
        @property.lazy?.should be(true)
      end
    end

    describe "when created with :lazy => true, :key => true" do
      before :all do
        @property = @type.new(@model, @name, @options.merge(:lazy => true, :key => true))
      end

      it "should return false" do
        @property.lazy?.should be(false)
      end
    end
  end

  describe '#instance_of?' do
    subject { property.instance_of?(klass) }

    let(:property) { @type.new(@model, @name, @options) }

    context 'when provided the property class' do
      let(:klass) { @type }

      it { should be(true) }
    end

    context 'when provided the property superclass' do
      let(:klass) { @type.superclass }

      it { should be(false) }
    end

    context 'when provided the DataMapper::Property class' do
      let(:klass) { DataMapper::Property }

      it { should be(false) }
    end
  end

  describe '#kind_of?' do
    subject { property.kind_of?(klass) }

    let(:property) { @type.new(@model, @name, @options) }

    context 'when provided the property class' do
      let(:klass) { @type }

      it { should be(true) }
    end

    context 'when provided the property superclass' do
      let(:klass) { @type.superclass }

      it { should be(true) }
    end

    context 'when provided the DataMapper::Property class' do
      let(:klass) { DataMapper::Property }

      it { should be(true) }
    end
  end
end
