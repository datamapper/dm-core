require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Scope do
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
        Article.with_scope :blog_id => 1 do
          Article.current_scope.should == DataMapper::Query.new(repository(:mock), Article, :blog_id => 1)
        end
      end
    end

    it 'should set the current scope for the block when given a DataMapper::Query' do
      Article.publicize_methods do
        Article.with_scope query = DataMapper::Query.new(repository(:mock), Article) do
          Article.current_scope.should == query
        end
      end
    end

    it 'should set the current scope for an inner block, merged with the outer scope' do
      Article.publicize_methods do
        Article.with_scope :blog_id => 1 do
          Article.with_scope :author => 'dkubb' do
            Article.current_scope.should == DataMapper::Query.new(repository(:mock), Article, :blog_id => 1, :author => 'dkubb')
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
        Article.with_scope :blog_id => 1 do
          Article.with_exclusive_scope :author => 'dkubb' do
            Article.current_scope.should == DataMapper::Query.new(repository(:mock), Article, :author => 'dkubb')
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
        query = DataMapper::Query.new(repository(:mock), Article)
        Article.scope_stack << query
        Article.current_scope.object_id.should == query.object_id
      end
    end
  end

  # TODO: specify the behavior of finders (all, first, get, []) when scope is in effect
end
