require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if HAS_SQLITE3
  class Engine
    include DataMapper::Resource

    property :id, Integer, :serial => true
    property :name, String
  end

  class Yard
    include DataMapper::Resource

    property :id, Integer, :serial => true
    property :engine_id, Integer

    property :name, String

    repository(:sqlite3) do
      many_to_one :engine
    end
  end

  class Pie
    include DataMapper::Resource

    property :id, Integer, :serial => true
    property :sky_id, Integer

    property :name, String

    repository(:sqlite3) do
      one_to_one :sky
    end
  end

  class Sky
    include DataMapper::Resource

    property :id, Integer, :serial => true
    property :pie_id, Integer

    property :name, String

    repository(:sqlite3) do
      one_to_one :pie
    end
  end

  class Host
    include DataMapper::Resource

    property :id, Integer, :serial => true
    property :name, String

    repository(:sqlite3) do
      one_to_many :slices, :order => [:id.desc]
    end
  end

  class Slice
    include DataMapper::Resource

    property :id, Integer, :serial => true
    property :host_id, Integer

    property :name, String

    repository(:sqlite3) do
      many_to_one :host
    end
  end

  class Node
    include DataMapper::Resource

    property :id, Integer, :serial => true
    property :parent_id, Integer

    property :name, String

    repository(:sqlite3) do
      one_to_many :children, :class_name => "Node", :child_key => [ :parent_id ]
      many_to_one :parent, :class_name => "Node", :child_key => [ :parent_id ]
    end
  end

  describe DataMapper::Associations do
    describe "many to one associations" do
      before do
        @adapter = repository(:sqlite3).adapter

        Engine.auto_migrate!(:sqlite3)

        @adapter.execute('INSERT INTO "engines" ("id", "name") values (?, ?)', 1, 'engine1')
        @adapter.execute('INSERT INTO "engines" ("id", "name") values (?, ?)', 2, 'engine2')

        Yard.auto_migrate!(:sqlite3)

        @adapter.execute('INSERT INTO "yards" ("id", "name", "engine_id") values (?, ?, ?)', 1, 'yard1', 1)
        @adapter.execute('INSERT INTO "yards" ("id", "name", "engine_id") values (?, ?, NULL)', 0, 'yard2')
      end

      it "should load without the parent"

      it 'should allow substituting the parent' do
        y, e = nil, nil

        repository(:sqlite3) do
          y = Yard.first(:id => 1)
          e = Engine.first(:id => 2)
        end

        y.engine = e
        repository(:sqlite3) do
          y.save
        end

        y = repository(:sqlite3) do
          Yard.first(:id => 1)
        end

        y.engine_id.should == 2
      end

      it "#many_to_one" do
        yard = Yard.new
        yard.should respond_to(:engine)
        yard.should respond_to(:engine=)
      end

      it "#many_to_one with namespaced models" do
        module FlightlessBirds
          class Ostrich
            include DataMapper::Resource
            property :id, Integer, :serial => true
            property :name, String
            many_to_one :sky # there's something sad about this :'(
          end
        end

        FlightlessBirds::Ostrich.properties.slice(:sky_id).should_not be_empty

      end


      it "should load the associated instance" do
        y = repository(:sqlite3) do
          Yard.first(:id => 1)
        end

        y.engine.should_not be_nil
        y.engine.id.should == 1
        y.engine.name.should == "engine1"
      end

      it 'should save the association key in the child' do
        repository(:sqlite3) do
          e = Engine.first(:id => 2)
          Yard.create(:id => 2, :name => 'yard2', :engine => e)
        end

        repository(:sqlite3) do
          Yard.first(:id => 2).engine_id.should == 2
        end
      end

      it 'should save the parent upon saving of child' do
        y = nil
        repository(:sqlite3) do
          e = Engine.new(:id => 10, :name => "engine10")
          y = Yard.new(:id => 10, :name => "Yard10", :engine => e)
          y.save
        end

        y.engine_id.should == 10
        repository(:sqlite3) do
          Engine.first(:id => 10).should_not be_nil
        end
      end

      it 'should convert NULL parent ids into nils' do
        y = repository(:sqlite3) do
          Yard.first(:id => 0)
        end

        y.engine.should be_nil
      end

      it 'should save nil parents as NULL ids' do
        pending <<-EOS.margin
          Broken. I'm guessing Resource#attributes= doesn't make any concessions for associations
          (probably not what we want to do anyways), and more importantly, that many_to_one accessor=
          methods don't properly handle nils.
        EOS

        y1,y2 = nil, nil

        repository(:sqlite3) do
          y1 = Yard.new(:id => 20, :name => "Yard20")
          r.save(y1)

          y2 = Yard.create!(:id => 30, :name => "Yard30", :engine => nil)
        end

        y1.id.should == 20
        y1.engine_id.should be_nil
        y2.id.should == 30
        y2.engine_id.should be_nil
      end

      after do
        @adapter.execute('DROP TABLE "yards"')
        @adapter.execute('DROP TABLE "engines"')
      end
    end

    describe "one to one associations" do
      before do
        @adapter = repository(:sqlite3).adapter

        Sky.auto_migrate!(:sqlite3)

        @adapter.execute('INSERT INTO "skies" ("id", "name") values (?, ?)', 1, 'sky1')

        Pie.auto_migrate!(:sqlite3)

        @adapter.execute('INSERT INTO "pies" ("id", "name", "sky_id") values (?, ?, ?)', 1, 'pie1', 1)
        @adapter.execute('INSERT INTO "pies" ("id", "name") values (?, ?)', 2, 'pie2')
      end

      it 'should allow substituting the child' do
        s, p = nil, nil

        repository(:sqlite3) do
          s = Sky.first(:id => 1)
          p = Pie.first(:id => 2)
        end

        s.pie = p

        p1 = repository(:sqlite3) do
          Pie.first(:id => 1)
        end

        p1.sky_id.should be_nil

        p2 = repository(:sqlite3) do
          Pie.first(:id => 2)
        end

        p2.sky_id.should == 1
      end

      it "#one_to_one" do
        s = Sky.new
        s.should respond_to(:pie)
        s.should respond_to(:pie=)
      end

      it "should load the associated instance" do
        s = repository(:sqlite3) do
          Sky.first(:id => 1)
        end

        s.pie.should_not be_nil
        s.pie.id.should == 1
        s.pie.name.should == "pie1"
      end

      it 'should save the association key in the child' do
        repository(:sqlite3) do
          p = Pie.first(:id => 2)
          Sky.create(:id => 2, :name => 'sky2', :pie => p)
        end

        repository(:sqlite3) do
          Pie.first(:id => 2).sky_id.should == 2
        end
      end

      it 'should save the children upon saving of parent' do
        repository(:sqlite3) do
          p = Pie.new(:id => 10, :name => "pie10")
          s = Sky.new(:id => 10, :name => "sky10", :pie => p)

          s.save

          p.sky_id.should == 10
        end

        repository(:sqlite3) do
          Pie.first(:id => 10).should_not be_nil
        end
      end

      it 'should save nil parents as NULL ids' do
        p1, p2 = nil, nil

        repository(:sqlite3) do
          p1 = Pie.new(:id => 20, :name => "Pie20")
          p1.save

          p2 = Pie.create!(:id => 30, :name => "Pie30", :sky => nil)
        end

        p1.id.should == 20
        p1.sky_id.should be_nil
        p2.id.should == 30
        p2.sky_id.should be_nil
      end

      after do
        @adapter.execute('DROP TABLE "pies"')
        @adapter.execute('DROP TABLE "skies"')
      end
    end

    describe "one to many associations" do
      before do
        @adapter = repository(:sqlite3).adapter

        Host.auto_migrate!(:sqlite3)

        @adapter.execute('INSERT INTO "hosts" ("id", "name") values (?, ?)', 1, 'host1')
        @adapter.execute('INSERT INTO "hosts" ("id", "name") values (?, ?)', 2, 'host2')

        Slice.auto_migrate!(:sqlite3)

        @adapter.execute('INSERT INTO "slices" ("id", "name", "host_id") values (?, ?, NULL)', 0, 'slice0')
        @adapter.execute('INSERT INTO "slices" ("id", "name", "host_id") values (?, ?, ?)', 1, 'slice1', 1)
        @adapter.execute('INSERT INTO "slices" ("id", "name", "host_id") values (?, ?, ?)', 2, 'slice2', 1)
      end

      it "#one_to_many" do
        h = Host.new
        h.should respond_to(:slices)
      end

      it "should allow removal of a child through a loaded association" do
        h = repository(:sqlite3) do
          Host.first(:id => 1)
        end

        s = h.slices.first

        h.slices.delete(s)
        h.slices.size.should == 1

        s = repository(:sqlite3) do
          Slice.first(:id => s.id)
        end

        s.host.should be_nil
        s.host_id.should be_nil
      end

      it "should load the associated instances, in the correct order" do
        h = repository(:sqlite3) do
          Host.first(:id => 1)
        end

        h.slices.should_not be_nil
        h.slices.size.should == 2
        h.slices.first.id.should == 2 # ordered by [:id.desc] 
        h.slices.last.id.should == 1

        s0 = repository(:sqlite3) do
          Slice.first(:id => 0)
        end

        s0.host.should be_nil
        s0.host_id.should be_nil
      end

      it "should add and save the associated instance" do
        h = repository(:sqlite3) do
          Host.first(:id => 1)
        end

        h.slices << Slice.new(:id => 3, :name => 'slice3')

        s = repository(:sqlite3) do
          Slice.first(:id => 3)
        end

        s.host.id.should == 1
      end

      it "should not save the associated instance if the parent is not saved" do
        repository(:sqlite3) do
          h = Host.new(:id => 10, :name => "host10")
          h.slices << Slice.new(:id => 10, :name => 'slice10')
        end

        repository(:sqlite3) do
          Slice.first(:id => 10).should be_nil
        end
      end

      it "should save the associated instance upon saving of parent" do
        repository(:sqlite3) do
          h = Host.new(:id => 10, :name => "host10")
          h.slices << Slice.new(:id => 10, :name => 'slice10')
          h.save
        end

        s = repository(:sqlite3) do
          Slice.first(:id => 10)
        end

        s.should_not be_nil
        s.host.should_not be_nil
        s.host.id.should == 10
      end

      it 'should save the associated instances upon saving of parent when mass-assigned' do
        repository(:sqlite3) do
          h = Host.create(:id => 10, :name => 'host10', :slices => [ Slice.new(:id => 10, :name => 'slice10') ])
        end

        s = repository(:sqlite3) do
          Slice.first(:id => 10)
        end

        s.should_not be_nil
        s.host.should_not be_nil
        s.host.id.should == 10
      end
      
      it 'should have finder-functionality' do
        h = repository(:sqlite3) do
           Host.first(:id => 1)
        end
        
        h.slices.should have(2).entries
        
        s = h.slices.all(:name => 'slice2')
        
        s.should have(1).entries
        s.first.id.should == 2
        
        h.slices.first(:name => 'slice2').should == s.first
      end

      describe "many-to-one and one-to-many associations combined" do
        before do
          @adapter = repository(:sqlite3).adapter

          Node.auto_migrate!(:sqlite3)

          @adapter.execute('INSERT INTO "nodes" ("id", "name", "parent_id") values (?, ?, NULL)', 1, 'r1')
          @adapter.execute('INSERT INTO "nodes" ("id", "name", "parent_id") values (?, ?, NULL)', 2, 'r2')
          @adapter.execute('INSERT INTO "nodes" ("id", "name", "parent_id") values (?, ?, ?)',    3, 'r1c1', 1)
          @adapter.execute('INSERT INTO "nodes" ("id", "name", "parent_id") values (?, ?, ?)',    4, 'r1c2', 1)
          @adapter.execute('INSERT INTO "nodes" ("id", "name", "parent_id") values (?, ?, ?)',    5, 'r1c3', 1)
          @adapter.execute('INSERT INTO "nodes" ("id", "name", "parent_id") values (?, ?, ?)',    6, 'r1c1c1', 3)
        end

        it "should properly set #parent" do
          repository :sqlite3 do
            r1 = Node.get 1
            r1.parent.should be_nil

            n3 = Node.get 3
            n3.parent.should == r1

            n6 = Node.get 6
            n6.parent.should == n3
          end
        end

        it "should properly set #children" do
          repository :sqlite3 do
            r1 = Node.get(1)
            off = r1.children
            off.size.should == 3
            off.include?(Node.get(3)).should be_true
            off.include?(Node.get(4)).should be_true
            off.include?(Node.get(5)).should be_true
          end
        end

        it "should allow to create root nodes" do
          repository :sqlite3 do
            r = Node.create!(:name => "newroot")
            r.parent.should be_nil
            r.children.size.should == 0
          end
        end

        it "should properly delete nodes" do
          repository :sqlite3 do
            r1 = Node.get 1

            r1.children.size.should == 3
            r1.children.delete(Node.get(4))
            Node.get(4).parent.should be_nil
            r1.children.size.should == 2
          end
        end
      end

      describe '#through' do
        before(:all) do
          module Sweets
            class Shop
              include DataMapper::Resource
              def self.default_repository_name
                :sqlite3
              end
              property :id, Integer, :serial => true
              property :name, String
              has n, :cakes, :class_name => 'Sweets::Cake'
              has n, {:cakes => :slices}, :class_name => 'Sweets::Slice'
              has 1, :shop_owner, :class_name => 'Sweets::ShopOwner'
              #              has 1, :shop_owner => :wife, :class_name => 'Sweets::Wife'
              has n, {:shop_owner => :children}, :class_name => 'Sweets::Child'
              #              has n, {:cakes => :recipe}, :class_name => 'Sweets::Recipe'
            end

            class ShopOwner
              include DataMapper::Resource
              def self.default_repository_name
                :sqlite3
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :shop, :class_name => 'Sweets::Shop'
              has 1, :wife, :class_name => 'Sweets::Wife'
              has n, :children, :class_name => 'Sweets::Child'
            end
            
            class Wife
              include DataMapper::Resource
              def self.default_repository_name
                :sqlite3
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :shop_owner, :class_name => 'Sweets::ShopOwner'
            end
            
            class Child
              include DataMapper::Resource
              def self.default_repository_name
                :sqlite3
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :shop_owner, :class_name => 'Sweets::ShopOwner'
            end
            
            class Cake
              include DataMapper::Resource
              def self.default_repository_name
                :sqlite3
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :shop, :class_name => 'Sweets::Shop'
              has n, :slices, :class_name => 'Sweets::Slice'
              has 1, :recipe, :class_name => 'Sweets::Recipe'
            end
            
            class Recipe
              include DataMapper::Resource
              def self.default_repository_name
                :sqlite3
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :cake, :class_name => 'Sweets::Cake'
            end
            
            class Slice
              include DataMapper::Resource
              def self.default_repository_name
                :sqlite3
              end
              property :id, Integer, :serial => true
              property :size, Integer
              belongs_to :cake, :class_name => 'Sweets::Cake'
            end
            
            repository(:sqlite3) do
              Shop.auto_migrate!(:sqlite3)
              Cake.auto_migrate!(:sqlite3)
              Slice.auto_migrate!(:sqlite3)
              ShopOwner.auto_migrate!(:sqlite3)
              Wife.auto_migrate!(:sqlite3)
              Child.auto_migrate!(:sqlite3)
              Recipe.auto_migrate!(:sqlite3)
              
              betsys = Shop.new(:name => "Betsy's")
              betsys.save
              german_chocolate = Cake.new(:name => 'German Chocolate')
              betsys.cakes << german_chocolate
              german_chocolate.save
              #              schwarzwald = Recipe.new(:name => 'Schwarzwald Cake')
              #              german_chocolate.recipe = schwarzwald
              10.times do |i| german_chocolate.slices << Slice.new(:size => i) end
              
              #              schwarzwald.save!

              short_cake = Cake.new(:name => 'Short Cake')
              betsys.cakes << short_cake
              short_cake.save
              #              shortys_special = Recipe.new(:name => "Shorty's Special")
              #              short_cake.recipe = shortys_special
              5.times do |i| short_cake.slices << Slice.new(:size => i) end
              #              shortys_special.save!

              betsy = ShopOwner.new(:name => 'Betsy')
              betsys.shop_owner = betsy
              betsys.save
              barry = Wife.new(:name => 'Barry')
              betsy.wife = barry
              barry.save

              5.times { |i| betsy.children << Child.new(:name => "Snotling nr #{i}") }
            end
          end
        end

        it "should return the right children for one_to_many => one_to_many relationships" do
          DataMapper.repository(:sqlite3) do
            Sweets::Shop.first.slices.size.should == 15
            10.times do |i|
              Sweets::Shop.first.slices.select do |slice|
                slice.cake == Sweets::Cake.first("name" => "German Chocolate") && slice.size == i
              end
            end
          end
        end
        it "should return the right children for one_to_one => one_to_many relationships" do
          DataMapper.repository(:sqlite3) do
            Sweets::Shop.first.children.size.should == 5
          end
        end
      end
    end
  end
end
