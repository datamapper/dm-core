require File.join(File.dirname(__FILE__), '..', 'lib', 'data_mapper', 'hook')

describe "DataMapper::Hook" do
  before(:each) do
    @class = Class.new do
      include DataMapper::Hook

      def a_method
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
    @class.install_hook :before, :a_hook, :a_method, &c = lambda { 1 }

    @class.hooks.should have_key(:a_hook)
    @class.hooks[:a_hook].last.should == c
    @class.hooks[:a_hook].should have(1).item
  end
  
  it 'should run an advice block' do
    @class.install_hook :before, :hook, :a_method do |inst|
      inst.hi_mom!
    end
    
    inst = @class.new
    inst.should_receive(:hi_mom!)
    
    inst.run_hook :hook
  end

  it 'should run an advice method' do
    @class.class_eval do
      def before_method()
        hi_mom!
      end

      install_hook :before, :hook, :a_method, :before_method
    end
    
    inst = @class.new
    inst.should_receive(:hi_mom!)
    
    inst.run_hook :hook
  end
  
  describe "using before hook" do
    it "should install the advice block under the appropriate hook" do
      c = lambda { 1 }
      
      @class.should_receive(:install_hook).with(:before, :before_a_method, :a_method, nil, &c)
      
      @class.class_eval do
        before :a_method, &c
      end
    end 
    
    it 'should install the advice method under the appropriate hook' do
      @class.class_eval do
        def a_hook
        end
      end

      @class.should_receive(:install_hook).with(:before, :before_a_method, :a_method, :a_hook)

      @class.before :a_method, :a_hook
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
      @class.should_receive(:install_hook).with(:after, :after_a_method, :a_method, nil, &c)
      
      @class.class_eval do
        after :a_method, &c
      end
    end 
    
    it 'should install the advice method under the appropriate hook' do
      @class.class_eval do
        def a_hook
        end
      end

      @class.should_receive(:install_hook).with(:after, :after_a_method, :a_method, :a_hook)

      @class.after :a_method, :a_hook
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
    end  end

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
end
