require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if ADAPTER
  describe DataMapper::Repository, "with #{ADAPTER}" do
    describe "finders" do
      before :all do
        class SerialFinderSpec
          include DataMapper::Resource

          property :id, Integer, :serial => true
          property :sample, String
        end
      end

      before do
        SerialFinderSpec.auto_migrate!(ADAPTER)

        setup_repository = repository(ADAPTER)
        100.times do
          setup_repository.save(SerialFinderSpec.new(:sample => rand.to_s))
        end
      end

      it "should throw an exception if the named repository is unknown" do
        (lambda do
          ::DataMapper::Repository.new(:completely_bogus)
        end).should raise_error(ArgumentError)
      end

      it "should return all available rows" do
        repository(ADAPTER).all(SerialFinderSpec, {}).should have(100).entries
      end

      it "should allow limit and offset" do
        repository(ADAPTER).all(SerialFinderSpec, { :limit => 50 }).should have(50).entries

        collection = repository(ADAPTER).all(SerialFinderSpec, { :limit => 20, :offset => 40 })
        collection.should have(20).entries
        collection.map { |entry| entry.id }.should == repository(ADAPTER).all(SerialFinderSpec, {})[40...60].map { |entry| entry.id }
      end

      it "should lazy-load missing attributes" do
        sfs = repository(ADAPTER).first(SerialFinderSpec, { :fields => [ :id ], :limit => 1 })
        sfs.should be_a_kind_of(SerialFinderSpec)
        sfs.should_not be_a_new_record

        sfs.attribute_loaded?(:sample).should be_false
        sfs.sample.should_not be_nil
      end

      it "should translate an Array to an IN clause" do
        ids = repository(ADAPTER).all(SerialFinderSpec, { :fields => [ :id ], :limit => 10 }).map { |entry| entry.id }
        results = repository(ADAPTER).all(SerialFinderSpec, { :id => ids })

        results.map { |entry| entry.id }.should == ids
      end
    end
  end
end
