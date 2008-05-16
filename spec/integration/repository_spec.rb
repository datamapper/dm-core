require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if HAS_SQLITE3
  describe DataMapper::Repository do
    describe "finders" do
      before do
        class SerialFinderSpec
          include DataMapper::Resource

          property :id, Fixnum, :serial => true
          property :sample, String
        end

        SerialFinderSpec.auto_migrate!(:sqlite3)

        @adapter = repository(:sqlite3).adapter

        setup_repository = repository(:sqlite3)
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
        repository(:sqlite3).all(SerialFinderSpec, {}).should have(100).entries
      end

      it "should allow limit and offset" do
        repository(:sqlite3).all(SerialFinderSpec, { :limit => 50 }).should have(50).entries

        repository(:sqlite3).all(SerialFinderSpec, { :limit => 20, :offset => 40 }).map(&:id).should ==
          repository(:sqlite3).all(SerialFinderSpec, {})[40...60].map(&:id)
      end

      it "should lazy-load missing attributes" do
        sfs = repository(:sqlite3).all(SerialFinderSpec, { :fields => [:id], :limit => 1 }).first
        sfs.should be_a_kind_of(SerialFinderSpec)
        sfs.should_not be_a_new_record

        sfs.instance_variables.should_not include('@sample')
        sfs.sample.should_not be_nil
      end

      it "should translate an Array to an IN clause" do
        ids = repository(:sqlite3).all(SerialFinderSpec, { :limit => 10 }).map(&:id)
        results = repository(:sqlite3).all(SerialFinderSpec, { :id => ids })

        results.size.should == 10
        results.map(&:id).should == ids
      end

      after do
        @adapter.execute('DROP TABLE "serial_finder_specs"')
      end

    end
  end
end
