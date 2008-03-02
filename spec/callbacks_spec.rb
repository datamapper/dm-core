require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Callbacks do
  
  it "should allow for a callback to be set, then called" do
    
    example = Class.new do
      include DataMapper::CallbacksHelper
      
      attr_accessor :name
      
      def initialize(name)
        @name = name
      end
      
      before_save 'name = "bob"'
      before_validation { |instance| instance.name = 'Barry White Returns!' }

    end.new('Barry White')
    
    example.class::callbacks.execute(:before_save, example)
    example.name.should == 'Barry White'
    
    example.class::callbacks.execute(:before_validation, example)
    example.name.should == 'Barry White Returns!'
  end
  
  it "should allow method delegation by passing symbols to the callback definitions" do
    
    example = Class.new do
      include DataMapper::CallbacksHelper
      
      attr_accessor :name
      
      before_save :test
      
      def test
        @name = 'Walter'
      end
    end.new
    
    example.class::callbacks.execute(:before_save, example)
    example.name.should == 'Walter'
    
  end
  
  it "should execute before_save regardless of dirty state" do
    
    Post.before_save do |post|
      post.instance_variable_set("@one", 'moo')
    end
    
    Post.before_save do |post|
      post.instance_variable_set("@two", 'cow')
    end
    
    Post.before_save :red_cow
    
    class Post
      def red_cow
        @three = "blue_cow"
      end
    end
    
    post = Post.new(:title => 'bob')
    post.save
    
    post = Post.first(:title => 'bob')
    post.instance_variable_get("@one").should be_nil
    post.instance_variable_get("@two").should be_nil
    post.instance_variable_get("@three").should be_nil

    post.save
    post.instance_variable_get("@one").should eql('moo')
    post.instance_variable_get("@two").should eql('cow')
    post.instance_variable_get("@three").should eql('blue_cow')
  end
  
  it "should execute materialization callbacks" do
    
    $before_materialize = 0
    $after_materialize = 0
    
    Zoo.before_materialize do
      $before_materialize += 1
    end
    
    Zoo.after_materialize do
      $after_materialize += 1
    end
    
    class Zoo
      
      # This syntax doesn't work in DM.
      # Which I don't think is necessarily a bad thing...
      # Just FYI -Sam
      def before_materialize
        $before_materialize += 1
      end
      
      def call_before_materialize
        $before_materialize += 1
      end
      
      # Example of invalid syntax
      def after_materialize
        $after_materialize += 1
      end
      
      def call_after_materialize
        $after_materialize += 1
      end
      
    end
    
    Zoo.before_materialize :call_before_materialize
    Zoo.after_materialize :call_after_materialize
    
    Zoo.before_materialize "$before_materialize += 1"
    Zoo.after_materialize "$after_materialize += 1"
    
    Zoo.first
    
    $before_materialize.should == 3
    $after_materialize.should == 3
    
    Zoo[1]
    
    $before_materialize.should == 6
    $after_materialize.should == 6
    
  end
  
  it "should execute creation callbacks" do
    
    $before_create = 0
    $after_create = 0
    
    Zoo.before_create do
      $before_create += 1
    end
    
    Zoo.after_create do
      $after_create += 1
    end
    
    class Zoo
      
      # Example of invalid syntax
      def before_create
        $before_create += 1
      end
      
      def call_before_create
        $before_create += 1
      end
      
      # Example of invalid syntax
      def after_create
        $after_create += 1
      end
      
      def call_after_create
        $after_create += 1
      end
      
    end
    
    Zoo.before_create :call_before_create
    Zoo.after_create :call_after_create
    
    Zoo.before_create "$before_create += 1"
    Zoo.after_create "$after_create += 1"
    
    Zoo.create(:name => 'bob')
    
    $before_create.should == 3
    $after_create.should == 3  
    
    Zoo.new(:name => 'bob2').save
    
    $before_create.should == 6
    $after_create.should == 6
  end
  
end