require File.dirname(__FILE__) + "/spec_helper"

describe('A tree') do
  
  before(:all) do
    class Node #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable

      property :name, :string

      belongs_to :parent, :class => 'Node'
      has_many :children, :class => 'Node', :foreign_key => 'parent_id'
      
      def <=>(other)
        name <=> other.name
      end
    end
    
    Node.auto_migrate!
  end
  
  after(:all) do
    repository.table(Node).drop!
  end

  it 'should work' do
    root = Node.new(:name => 'root')

    one = Node.new(:name => 'one')
    two = Node.new(:name => 'two')

    root.children << one << two
    
    root.parent_id.should be_nil
    
    one_one = Node.new(:name => 'one_one')
    one_two = Node.new(:name => 'one_two')
    one.children << one_one << one_two

    two_one = Node.new(:name => 'two_one')
    two_two = Node.new(:name => 'two_two')
    two.children << two_one << two_two

    root.save.should == true
    root.parent_id.should be_nil
    
    root.should have(2).children
    one.should have(2).children
    two.should have(2).children

    Node.all(:name => 'root').should have(1).entries
    
    grand = Node.first(:name => 'root')
    
    grand.should have(2).children
    
    root.should == grand # true since +root+ and +grand+ are objects with identical types and attributes.
    root.object_id.should_not eql(grand.object_id) # false since +root+ and +grand+ are in different sessions.
    
    grand.children.should include(one)
    one.reload
    one.children.should include(one_one)
    
    grand.children.first.children.first.should eql(one_one)
  end
  
end
