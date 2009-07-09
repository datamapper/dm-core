module DataMapper::Spec
  module CollectionHelpers
    module GroupMethods
      def self.extended(base)
        base.class_inheritable_accessor :loaded
        base.loaded = false
      end

      def should_not_be_a_kicker
        unless loaded
          it 'should not be a kicker' do
            @articles.should_not be_loaded
          end
        end
      end
    end
  end
end
