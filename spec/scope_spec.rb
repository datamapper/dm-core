require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

# NOTE: These specs mock out DM::Query, since it is currently in the burn
# folder.  Once that class is pulled into core, I expect these specs to
# change and simplify considerably.  Instead of mocking the object, I would
# likely just inspect the current_scope within the scoped block to see if it
# matches my expectations.  This should be enough to know whether or not the
# passed-in conditions were merged properly with the existing scope.

describe DataMapper::Scope do
  before :all do
    class Article
      include DataMapper::Scope
    end

    class DataMapper::Query
      # FIXME: stub this out until DM::Query is moved from burn into lib
    end
  end

  before do
    @dm_query = mock('DataMapper::Query')
    @dm_query.stub!(:merge)
    DataMapper::Query.stub!(:new).and_return(@dm_query)
  end

  after do
    Article.publicize_methods do
      Article.scope_stack.clear  # reset the stack before each spec
    end
  end

  describe '.with_scope' do
    it 'should be protected' do
      klass = class << Article; self; end
      klass.should be_protected_method_defined(:with_scope)
    end

    it 'should set the current scope for the block when given a Hash' do
      Article.publicize_methods do
        DataMapper::Query.should_receive(:new).with(Article, :blog_id => 1).once.and_return(@dm_query)

        Article.with_scope :blog_id => 1 do
          Article.current_scope.should == @dm_query
        end
      end
    end

    it 'should set the current scope for the block when given a DataMapper::Query' do
      Article.publicize_methods do
        Article.with_scope @dm_query do
          Article.current_scope.should == @dm_query
        end
      end
    end

    it 'should set the current scope for an inner block, merged with the outer scope' do
      Article.publicize_methods do
        DataMapper::Query.should_receive(:new).with(Article, :blog_id => 1).once.ordered.and_return(@dm_query)

        Article.with_scope :blog_id => 1 do
          nested_query = mock('Nested DataMapper::Query')
          @dm_query.should_receive(:merge).with(:author => 'dkubb').once.ordered.and_return(nested_query)

          Article.with_scope :author => 'dkubb' do
            Article.current_scope.should == nested_query
          end
        end
      end
    end

    it 'should reset the stack on error' do
      Article.publicize_methods do
        Article.current_scope.should be_nil
        lambda {
          Article.with_scope(:blog_id => 1) { raise 'There was a problem!' }
        }.should raise_error(RuntimeError)
        Article.current_scope.should be_nil
      end
    end
  end

  describe '.with_exclusive_scope' do
    it 'should be protected' do
      klass = class << Article; self; end
      klass.should be_protected_method_defined(:with_exclusive_scope)
    end

    it 'should set the current scope for an inner block, ignoring the outer scope' do
      Article.publicize_methods do
        DataMapper::Query.should_receive(:new).with(Article, :blog_id => 1).once.ordered.and_return(@dm_query)
        @dm_query.should_not_receive(:merge)

        Article.with_scope :blog_id => 1 do
          exclusive_query = mock('Exclusive DataMapper::Query')
          exclusive_query.should_not_receive(:merge)
          DataMapper::Query.should_receive(:new).with(Article, :author => 'dkubb').once.ordered.and_return(exclusive_query)

          Article.with_exclusive_scope :author => 'dkubb' do
            Article.current_scope.should == exclusive_query
          end
        end
      end
    end

    it 'should reset the stack on error' do
      Article.publicize_methods do
        Article.current_scope.should be_nil
        lambda {
          Article.with_exclusive_scope(:blog_id => 1) { raise 'There was a problem!' }
        }.should raise_error(RuntimeError)
        Article.current_scope.should be_nil
      end
    end
  end

  describe '.scope_stack' do
    it 'should be private' do
      klass = class << Article; self; end
      klass.should be_private_method_defined(:scope_stack)
    end

    it 'should provide an Array' do
      Article.publicize_methods do
        Article.scope_stack.should be_kind_of(Array)
      end
    end

    it 'should be the same in a thread' do
      Article.publicize_methods do
        Article.scope_stack.object_id.should == Article.scope_stack.object_id
      end
    end

    it 'should be different in each thread' do
      Article.publicize_methods do
        a = Thread.new { Article.scope_stack }
        b = Thread.new { Article.scope_stack }

        a.value.object_id.should_not == b.value.object_id
      end
    end
  end

  describe '.current_scope' do
    it 'should be private' do
      klass = class << Article; self; end
      klass.should be_private_method_defined(:current_scope)
    end

    it 'should return nil if the scope stack is empty' do
      Article.publicize_methods do
        Article.scope_stack.should be_empty
        Article.current_scope.should be_nil
      end
    end

    it 'should return the last element of the scope stack' do
      Article.publicize_methods do
        Article.scope_stack << @dm_query
        Article.current_scope.object_id.should == @dm_query.object_id
      end
    end
  end

  # TODO: specify the behavior of finders (all, first, get, []) when scope is in effect
end
