require 'spec_helper'

describe DataMapper::Model::Hook do
  before :all do
    class ::ModelHookSpecs
      include DataMapper::Resource

      property :id, Serial
      property :value, Integer, :required => true, :default => 1

      def an_instance_method
      end
    end

    class ::ModelHookSpecsSubclass < ModelHookSpecs; end

    DataMapper.finalize
  end

  before :all do
    @resource = ModelHookSpecs.new
  end

  describe '#before' do
    describe 'an instance method' do
      before do
        @hooks = hooks = []
        ModelHookSpecs.before(:an_instance_method) { hooks << :before_instance_method }

        @resource.an_instance_method
      end

      it 'should execute before instance method hook' do
        @hooks.should == [ :before_instance_method ]
      end
    end

    describe 'save' do
      supported_by :all do
        before do
          @hooks = hooks = []
          ModelHookSpecs.before(:save) { hooks << :before_save }

          @resource.save
        end

        it 'should execute before save hook' do
          @hooks.should == [ :before_save ]
        end
      end
    end

    describe 'create' do
      supported_by :all do
        before do
          @hooks = hooks = []
          ModelHookSpecs.before(:create) { hooks << :before_create }

          @resource.save
        end

        it 'should execute before create hook' do
          @hooks.should == [ :before_create ]
        end
      end
    end

    describe 'update' do
      supported_by :all do
        before do
          @hooks = hooks = []
          ModelHookSpecs.before(:update) { hooks << :before_update }

          @resource.save
          @resource.update(:value => 2)
        end

        it 'should execute before update hook' do
          @hooks.should == [ :before_update ]
        end
      end
    end

    describe 'destroy' do
      supported_by :all do
        before do
          @hooks = hooks = []
          ModelHookSpecs.before(:destroy) { hooks << :before_destroy }

          @resource.save
          @resource.destroy
        end

        it 'should execute before destroy hook' do
          @hooks.should == [ :before_destroy ]
        end
      end
    end

    describe 'with an inherited hook' do
      supported_by :all do
        before do
          @hooks = hooks = []
          ModelHookSpecs.before(:an_instance_method) { hooks << :inherited_hook }
        end

        it 'should execute inherited hook' do
          ModelHookSpecsSubclass.new.an_instance_method
          @hooks.should == [ :inherited_hook ]
        end
      end
    end

    describe 'with a hook declared in the subclasss' do
      supported_by :all do
        before do
          @hooks = hooks = []
          ModelHookSpecsSubclass.before(:an_instance_method) { hooks << :hook }
        end

        it 'should execute hook' do
          ModelHookSpecsSubclass.new.an_instance_method
          @hooks.should == [ :hook ]
        end

        it 'should not alter hooks in the parent class' do
          @hooks.should be_empty
          ModelHookSpecs.new.an_instance_method
          @hooks.should == []
        end
      end
    end
  end

  describe '#after' do
    describe 'an instance method' do
      before do
        @hooks = hooks = []
        ModelHookSpecs.after(:an_instance_method) { hooks << :after_instance_method }

        @resource.an_instance_method
      end

      it 'should execute after instance method hook' do
        @hooks.should == [ :after_instance_method ]
      end
    end

    describe 'save' do
      supported_by :all do
        before do
          @hooks = hooks = []
          ModelHookSpecs.after(:save) { hooks << :after_save }

          @resource.save
        end

        it 'should execute after save hook' do
          @hooks.should == [ :after_save ]
        end
      end
    end

    describe 'create' do
      supported_by :all do
        before do
          @hooks = hooks = []
          ModelHookSpecs.after(:create) { hooks << :after_create }

          @resource.save
        end

        it 'should execute after create hook' do
          @hooks.should == [ :after_create ]
        end
      end
    end

    describe 'update' do
      supported_by :all do
        before do
          @hooks = hooks = []
          ModelHookSpecs.after(:update) { hooks << :after_update }

          @resource.save
          @resource.update(:value => 2)
        end

        it 'should execute after update hook' do
          @hooks.should == [ :after_update ]
        end
      end
    end

    describe 'destroy' do
      supported_by :all do
        before do
          @hooks = hooks = []
          ModelHookSpecs.after(:destroy) { hooks << :after_destroy }

          @resource.save
          @resource.destroy
        end

        it 'should execute after destroy hook' do
          @hooks.should == [ :after_destroy ]
        end
      end
    end

    describe 'with an inherited hook' do
      supported_by :all do
        before do
          @hooks = hooks = []
          ModelHookSpecs.after(:an_instance_method) { hooks << :inherited_hook }
        end

        it 'should execute inherited hook' do
          ModelHookSpecsSubclass.new.an_instance_method
          @hooks.should == [ :inherited_hook ]
        end
      end
    end

    describe 'with a hook declared in the subclasss' do
      supported_by :all do
        before do
          @hooks = hooks = []
          ModelHookSpecsSubclass.after(:an_instance_method) { hooks << :hook }
        end

        it 'should execute hook' do
          ModelHookSpecsSubclass.new.an_instance_method
          @hooks.should == [ :hook ]
        end

        it 'should not alter hooks in the parent class' do
          @hooks.should be_empty
          ModelHookSpecs.new.an_instance_method
          @hooks.should == []
        end
      end
    end

  end
end
