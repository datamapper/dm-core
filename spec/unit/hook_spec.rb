require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require ROOT_DIR + 'lib/data_mapper/hook'

describe "DataMapper::Hook" do
  before(:each) do
    @class = Class.new do
      include DataMapper::Hook

      def a_method
      end

      def self.a_class_method
      end
    end
  end

  it 'should generate the correct argument signature' do
    @class.class_eval do
      def some_method(a, b, c)
        [a, b, c]
      end

      def yet_another(a, *heh)p
        [a, *heh]
      end
    end

    @class.args_for(@class.instance_method(:a_method)).should == ""
    @class.args_for(@class.instance_method(:some_method)).should == "_1, _2, _3"
    @class.args_for(@class.instance_method(:yet_another)).should == "_1, *args"
  end

  it 'should install the block under the appropriate hook' do
    @class.class_eval do
      def a_hook
      end
    end
    @class.before :a_hook, &c = lambda { 1 }

    @class.hooks.should have_key(:a_hook)
    @class.hooks[:a_hook][:before].should have(1).item
  end

  it 'should run an advice block for class methods' do
    @class.before_class_method :a_class_method do
      hi_dad!
    end
    
    @class.should_receive(:hi_dad!)
    
    @class.a_class_method
  end

  it 'should run an advice block' do
    @class.before :a_method do
      hi_mom!
    end

    inst = @class.new
    inst.should_receive(:hi_mom!)

    inst.a_method
  end

  it 'should run an advice method' do
    @class.class_eval do
      def hook
      end

      def before_method()
        hi_mom!
      end

      before :hook, :before_method
    end

    inst = @class.new
    inst.should_receive(:hi_mom!)

    inst.hook
  end

  describe "using before hook" do
    it "should install the advice block under the appropriate hook" do
      c = lambda { 1 }

      @class.should_receive(:install_hook).with(:before, :a_method, nil, :instance, &c)

      @class.class_eval do
        before :a_method, &c
      end
    end

    it 'should install the advice method under the appropriate hook' do
      @class.class_eval do
        def a_hook
        end
      end

      @class.should_receive(:install_hook).with(:before, :a_method, :a_hook, :instance)

      @class.before :a_method, :a_hook
    end

    it 'should run the advice before the advised class method' do
      tester = mock("tester")
      tester.should_receive(:one).ordered
      tester.should_receive(:two).ordered

      class << @class
        self
      end.instance_eval do
        define_method :hook do
          tester.two
        end
        define_method :one do
          tester.one
        end
      end
      @class.before_class_method :hook, :one

      @class.hook
    end

    it 'should run the advice before the advised method' do
      tester = mock("tester")
      tester.should_receive(:one).ordered
      tester.should_receive(:two).ordered

      @class.send(:define_method, :a_method) do
        tester.two
      end

      @class.before :a_method do
        tester.one
      end

      @class.new.a_method
    end

    it 'should execute all class method advices once' do
      tester = mock("tester")
      tester.should_receive(:before1).once
      tester.should_receive(:before2).once
      @class.class_eval do
        def self.hook
        end
      end
      @class.before_class_method :hook do
        tester.before1
      end
      @class.before_class_method :hook do
        tester.before2
      end

      @class.hook
    end

    it 'should execute all advices once' do
      tester = mock("tester")
      tester.should_receive(:before1).once
      tester.should_receive(:before2).once

      @class.before :a_method do
        tester.before1
      end

      @class.before :a_method do
        tester.before2
      end

      @class.new.a_method
    end
  end

  describe 'using after hook' do
    it "should install the advice block under the appropriate hook" do
      c = lambda { 1 }
      @class.should_receive(:install_hook).with(:after, :a_method, nil, :instance, &c)

      @class.class_eval do
        after :a_method, &c
      end
    end

    it 'should install the advice method under the appropriate hook' do
      @class.class_eval do
        def a_hook
        end
      end

      @class.should_receive(:install_hook).with(:after, :a_method, :a_hook, :instance)

      @class.after :a_method, :a_hook
    end

    it 'should run the advice after the advised class method' do
      tester = mock("tester")
      tester.should_receive(:one).ordered
      tester.should_receive(:two).ordered
      tester.should_receive(:three).ordered

      @class.after_class_method :a_class_method do
        tester.one
      end
      @class.after_class_method :a_class_method do
        tester.two
      end
      @class.after_class_method :a_class_method do
        tester.three
      end

      @class.a_class_method
    end

    it 'should run the advice after the advised method' do
      tester = mock("tester")
      tester.should_receive(:one).ordered
      tester.should_receive(:two).ordered
      tester.should_receive(:three).ordered

      @class.send(:define_method, :a_method) do
        tester.one
      end

      @class.after :a_method do
        tester.two
      end

      @class.after :a_method do
        tester.three
      end

      @class.new.a_method
    end

    it 'should execute all class method advices once' do
      tester = mock("tester")
      tester.should_receive(:after1).once
      tester.should_receive(:after2).once

      @class.after_class_method :a_class_method do
        tester.after1
      end
      @class.after_class_method :a_class_method do
        tester.after2
      end
      @class.a_class_method
    end

    it 'should execute all advices once' do
      tester = mock("tester")
      tester.should_receive(:after1).once
      tester.should_receive(:after2).once

      @class.after :a_method do
        tester.after1
      end

      @class.after :a_method do
        tester.after2
      end

      @class.new.a_method
    end  

    it "the advised method should still return its normal value" do
      @class.class_eval do
	def returner
	  1
        end

	after :returner do
	  2
        end
      end

      @class.new.returner.should == 1
    end
  end

  it 'should allow the use of before and after together on class methods' do
    tester = mock("tester")
    tester.should_receive(:before).ordered.once
    tester.should_receive(:method).ordered.once
    tester.should_receive(:after).ordered.once

    class << @class
        self
    end.instance_eval do
      define_method :hook do
        tester.method
      end
    end

    @class.before_class_method :hook do
      tester.before
    end

    @class.after_class_method :hook do
      tester.after
    end

    @class.hook
  end

  it 'should allow the use of before and after together' do
    tester = mock("tester")
    tester.should_receive(:before).ordered.once
    tester.should_receive(:method).ordered.once
    tester.should_receive(:after).ordered.once

    @class.class_eval do
      define_method :a_method do
        tester.method
      end

      before :a_method do
        tester.before
      end

      after :a_method do
        tester.after
      end
    end

    @class.new.a_method
  end

  it "should allow advising methods ending in ? or !" do
    tester = mock("tester")
    tester.should_receive(:before).ordered.once
    tester.should_receive(:method!).ordered.once
    tester.should_receive(:method?).ordered.once
    tester.should_receive(:after).ordered.once

    @class.class_eval do
      define_method :a_method! do
        tester.method!
      end

      define_method :a_method? do
	tester.method?
      end

      before :a_method! do
        tester.before
      end

      after :a_method? do
        tester.after
      end
    end

    @class.new.a_method!
    @class.new.a_method?
  end

  it "should allow advising methods ending in ?, ! or = when passing methods as advices" do
    tester = mock("tester")
    tester.should_receive(:before_bang).ordered.once
    tester.should_receive(:method!).ordered.once
    tester.should_receive(:before_eq).ordered.once
    tester.should_receive(:method_eq).ordered.once
    tester.should_receive(:method?).ordered.once
    tester.should_receive(:after).ordered.once

    @class.class_eval do
      define_method :a_method! do
        tester.method!
      end

      define_method :a_method? do
	tester.method?
      end

      define_method :a_method= do |value|
	tester.method_eq
      end

      define_method :before_a_method_bang do
        tester.before_bang
      end

      before :a_method!, :before_a_method_bang

      define_method :before_a_method_eq do
        tester.before_eq
      end

      before :a_method=, :before_a_method_eq

      define_method :after_a_method_question do
        tester.after
      end

      after :a_method?, :after_a_method_question
    end

    @class.new.a_method!
    @class.new.a_method = 1
    @class.new.a_method?
  end

  it "should complain when only one argument is passed for class methods" do
    lambda do
      @class.before_class_method :plur
    end.should raise_error(ArgumentError)
  end

  it "should complain when target_method is not a symbol for class methods" do
    lambda do
      @class.before_class_method "hepp", :plur
    end.should raise_error(ArgumentError)
  end

  it "should complain when method_sym is not a symbol" do
    lambda do
      @class.before_class_method :hepp, "plur"
    end.should raise_error(ArgumentError)
  end

  it "should complain when only one argument is passed" do
    lambda do
      @class.class_eval do
	before :a_method
	after :a_method
      end
    end.should raise_error(ArgumentError)
  end

  it "should complain when target_method is not a symbol" do
    lambda do
      @class.class_eval do
	before "target", :something
      end
    end.should raise_error(ArgumentError)
  end

  it "should complain when method_sym is not a symbol" do
    lambda do
      @class.class_eval do
	before :target, "something"
      end
    end.should raise_error(ArgumentError)
  end
end
