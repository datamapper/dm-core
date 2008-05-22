require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if ADAPTER
  repository(ADAPTER) do
    class Engine
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, :serial => true
      property :name, String
      one_to_many :yards
      one_to_many :fussy_yards, :class_name => "Yard", :rating.gte => 3, :type => "particular"
    end

    class Yard
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, :serial => true
      property :engine_id, Integer

      property :name, String
      property :rating, Integer
      property :type, String

      many_to_one :engine
    end

    class Pie
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, :serial => true
      property :sky_id, Integer

      property :name, String

      one_to_one :sky
    end

    class Sky
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, :serial => true
      property :pie_id, Integer

      property :name, String

      one_to_one :pie
    end

    class Host
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, :serial => true
      property :name, String

      one_to_many :slices, :order => [:id.desc]
    end

    class Slice
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, :serial => true
      property :host_id, Integer

      property :name, String

      many_to_one :host
    end

    class Node
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, :serial => true
      property :parent_id, Integer

      property :name, String

      one_to_many :children, :class_name => "Node", :child_key => [ :parent_id ]
      many_to_one :parent, :class_name => "Node", :child_key => [ :parent_id ]
    end

    module Models

      class Project
        include DataMapper::Resource

        def self.default_repository_name
          ADAPTER
        end

        property :title, String, :length => 255, :key => true
        property :summary, DataMapper::Types::Text

        one_to_many :tasks, :class_name => "Models::Task"
      end

      class Task
        include DataMapper::Resource

        def self.default_repository_name
          ADAPTER
        end

        property :title, String, :length => 255, :key => true
        property :description, DataMapper::Types::Text
        property :project_title, String, :length => 255

        many_to_one :project, :class_name => "Models::Project"
      end
    end
  end

  describe DataMapper::Associations do
    before :all do
      @adapter = repository(ADAPTER).adapter
    end

    describe "namespaced associations" do
      before do
        Models::Project.auto_migrate!(ADAPTER)
        Models::Task.auto_migrate!(ADAPTER)
      end

      it 'should allow namespaced classes in parent and child' do
        m = Models::Project.new(:title => "p1", :summary => "sum1")
        m.tasks << Models::Task.new(:title => "t1", :description => "desc 1")
        m.save

        t = Models::Task.first(:title => "t1")

        t.project.should_not be_nil
        t.project.title.should == 'p1'
        t.project.tasks.size.should == 1

        p = Models::Project.first(:title => 'p1')

        p.tasks.size.should == 1
        p.tasks[0].title.should == "t1"
      end
    end

    describe "many to one associations" do
      before do
        Engine.auto_migrate!(ADAPTER)
        Yard.auto_migrate!(ADAPTER)

        engine1 = Engine.create!(:name => 'engine1')
        engine2 = Engine.create!(:name => 'engine2')
        yard1   = Yard.create!(:name => 'yard1', :engine => engine1)
        yard2   = Yard.create!(:name => 'yard2')
      end

      it "should load without the parent"

      it 'should allow substituting the parent' do
        y, e = nil, nil

        y = Yard.first(:id => 1)
        e = Engine.first(:id => 2)

        y.engine = e
        y.save

        y = Yard.first(:id => 1)

        y.engine_id.should == 2
      end

      it "#many_to_one" do
        yard = Yard.new
        yard.should respond_to(:engine)
        yard.should respond_to(:engine=)
      end

      it "#many_to_one with namespaced models" do
        repository(ADAPTER) do
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
      end

      it "should load the associated instance" do
        y = Yard.first(:id => 1)

        y.engine.should_not be_nil
        y.engine.id.should == 1
        y.engine.name.should == "engine1"
      end

      it 'should save the association key in the child' do
        e = Engine.first(:id => 2)
        Yard.create(:id => 3, :name => 'yard2', :engine => e)

        Yard.first(:id => 3).engine_id.should == 2
      end

      it 'should save the parent upon saving of child' do
        y = nil
        e = Engine.new(:id => 10, :name => "engine10")
        y = Yard.new(:id => 10, :name => "Yard10", :engine => e)
        y.save

        y.engine_id.should == 10
        Engine.first(:id => 10).should_not be_nil
      end

      it 'should convert NULL parent ids into nils' do
        y = Yard.first(:id => 2)

        y.engine.should be_nil
      end

      it 'should save nil parents as NULL ids' do
        pending "Broken. I'm guessing Resource#attributes= doesn't make any concessions for associations (probably not what we want to do anyways), and more importantly, that many_to_one accessor= methods don't properly handle nils."

        y1,y2 = nil, nil

        y1 = Yard.new(:id => 20, :name => "Yard20")
        r.save(y1)

        y2 = Yard.create!(:id => 30, :name => "Yard30", :engine => nil)

        y1.id.should == 20
        y1.engine_id.should be_nil
        y2.id.should == 30
        y2.engine_id.should be_nil
      end
    end

    describe "one to one associations" do
      before do
        Sky.auto_migrate!(ADAPTER)
        Pie.auto_migrate!(ADAPTER)

        @adapter.execute('INSERT INTO "skies" ("id", "name") values (?, ?)', 1, 'sky1')
        @adapter.execute('INSERT INTO "pies" ("id", "name", "sky_id") values (?, ?, ?)', 1, 'pie1', 1)
        @adapter.execute('INSERT INTO "pies" ("id", "name") values (?, ?)', 2, 'pie2')
      end

      it 'should allow substituting the child' do
        s, p = nil, nil

        s = Sky.first(:id => 1)
        p = Pie.first(:id => 2)

        s.pie = p

        p1 = Pie.first(:id => 1)

        p1.sky_id.should be_nil

        p2 = Pie.first(:id => 2)

        p2.sky_id.should == 1
      end

      it "#one_to_one" do
        s = Sky.new
        s.should respond_to(:pie)
        s.should respond_to(:pie=)
      end

      it "should load the associated instance" do
        s = Sky.first(:id => 1)

        s.pie.should_not be_nil
        s.pie.id.should == 1
        s.pie.name.should == "pie1"
      end

      it 'should save the association key in the child' do
        p = Pie.first(:id => 2)
        Sky.create(:id => 2, :name => 'sky2', :pie => p)

        Pie.first(:id => 2).sky_id.should == 2
      end

      it 'should save the children upon saving of parent' do
        p = Pie.new(:id => 10, :name => "pie10")
        s = Sky.new(:id => 10, :name => "sky10", :pie => p)

        s.save

        p.sky_id.should == 10

        Pie.first(:id => 10).should_not be_nil
      end

      it 'should save nil parents as NULL ids' do
        p1, p2 = nil, nil

        p1 = Pie.new(:id => 20, :name => "Pie20")
        p1.save

        p2 = Pie.create!(:id => 30, :name => "Pie30", :sky => nil)

        p1.id.should == 20
        p1.sky_id.should be_nil
        p2.id.should == 30
        p2.sky_id.should be_nil
      end
    end

    describe "one to many associations" do
      before do
        Host.auto_migrate!(ADAPTER)
        Slice.auto_migrate!(ADAPTER)
        Engine.auto_migrate!(ADAPTER)
        Yard.auto_migrate!(ADAPTER)

        @adapter.execute('INSERT INTO "hosts" ("id", "name") values (?, ?)', 1, 'host1')
        @adapter.execute('INSERT INTO "hosts" ("id", "name") values (?, ?)', 2, 'host2')
        @adapter.execute('INSERT INTO "slices" ("id", "name", "host_id") values (?, ?, NULL)', 0, 'slice0')
        @adapter.execute('INSERT INTO "slices" ("id", "name", "host_id") values (?, ?, ?)', 1, 'slice1', 1)
        @adapter.execute('INSERT INTO "slices" ("id", "name", "host_id") values (?, ?, ?)', 2, 'slice2', 1)
      end

      it "#one_to_many" do
        h = Host.new
        h.should respond_to(:slices)
      end

      it "should allow removal of a child through a loaded association" do
        h = Host.first(:id => 1)

        s = h.slices.first

        h.slices.delete(s)
        h.slices.size.should == 1

        s = Slice.first(:id => s.id)

        s.host.should be_nil
        s.host_id.should be_nil
      end

      it "should use the IdentityMap correctly" do
        repository(ADAPTER) do
          h = Host.first(:id => 1)

          slice =  h.slices.first
          slice2 = h.slices(:order => [:id.asc]).last # should be the same as 1
          slice3 = Slice.get(2) # should be the same as 1

          slice.should == slice2
          slice.should == slice3
          slice.object_id.should == slice2.object_id
          slice.object_id.should == slice3.object_id
        end
      end

      it "#<< should add exactly the parameters" do
        engine = Engine.new(:name => 'my engine')
        4.times do |i|
          engine.yards << Yard.new(:name => "yard nr #{i}")
        end
        engine.save
        engine.yards.size.should == 4
        4.times do |i|
          engine.yards.any? do |yard|
            yard.name == "yard nr #{i}"
          end.should == true
        end
        engine = Engine[engine.id]
        engine.yards.size.should == 4
        4.times do |i|
          engine.yards.any? do |yard|
            yard.name == "yard nr #{i}"
          end.should == true
        end
      end

      it "#<< should add default values for relationships that have conditions" do
        # it should add default values
        engine = Engine.new(:name => 'my engine')
        engine.fussy_yards << Yard.new(:name => "yard 1", :rating => 4 )
        engine.save
        Yard.first(:name => "yard 1").type.should == "particular"
        # it should not add default values if the condition's property already has a value
        engine.fussy_yards << Yard.new(:name => "yard 2", :rating => 4, :type => "not particular")
        Yard.first(:name => "yard 2").type.should == "not particular"
        # it should ignore non :eql conditions
        engine.fussy_yards << Yard.new(:name => "yard 3")
        Yard.first(:name => "yard 3").rating.should == nil
      end

      it "should load the associated instances, in the correct order" do
        h = Host.first(:id => 1)

        h.slices.should_not be_nil
        h.slices.size.should == 2
        h.slices.first.id.should == 2 # ordered by [:id.desc]
        h.slices.last.id.should == 1

        s0 = Slice.first(:id => 0)

        s0.host.should be_nil
        s0.host_id.should be_nil
      end

      it "should add and save the associated instance" do
        h = Host.first(:id => 1)

        h.slices << Slice.new(:id => 3, :name => 'slice3')

        s = Slice.first(:id => 3)

        s.host.id.should == 1
      end

      it "should not save the associated instance if the parent is not saved" do
        h = Host.new(:id => 10, :name => "host10")
        h.slices << Slice.new(:id => 10, :name => 'slice10')

        Slice.first(:id => 10).should be_nil
      end

      it "should save the associated instance upon saving of parent" do
        h = Host.new(:id => 10, :name => "host10")
        h.slices << Slice.new(:id => 10, :name => 'slice10')
        h.save

        s = Slice.first(:id => 10)

        s.should_not be_nil
        s.host.should_not be_nil
        s.host.id.should == 10
      end

      it 'should save the associated instances upon saving of parent when mass-assigned' do
        h = Host.create(:id => 10, :name => 'host10', :slices => [ Slice.new(:id => 10, :name => 'slice10') ])

        s = Slice.first(:id => 10)

        s.should_not be_nil
        s.host.should_not be_nil
        s.host.id.should == 10
      end

      it 'should have finder-functionality' do
        h = Host.first(:id => 1)

        h.slices.should have(2).entries

        s = h.slices.all(:name => 'slice2')

        s.should have(1).entries
        s.first.id.should == 2

        h.slices.first(:name => 'slice2').should == s.first
      end
    end

    describe "many-to-one and one-to-many associations combined" do
      before do
        Node.auto_migrate!(ADAPTER)

        Node.create!(:name => 'r1')
        Node.create!(:name => 'r2')
        Node.create!(:name => 'r1c1',   :parent_id => 1)
        Node.create!(:name => 'r1c2',   :parent_id => 1)
        Node.create!(:name => 'r1c3',   :parent_id => 1)
        Node.create!(:name => 'r1c1c1', :parent_id => 3)
      end

      it "should properly set #parent" do
        r1 = Node.get 1
        r1.parent.should be_nil

        n3 = Node.get 3
        n3.parent.should == r1

        n6 = Node.get 6
        n6.parent.should == n3
      end

      it "should properly set #children" do
        r1 = Node.get(1)
        off = r1.children
        off.size.should == 3
        off.include?(Node.get(3)).should be_true
        off.include?(Node.get(4)).should be_true
        off.include?(Node.get(5)).should be_true
      end

      it "should allow to create root nodes" do
        r = Node.create!(:name => "newroot")
        r.parent.should be_nil
        r.children.size.should == 0
      end

      it "should properly delete nodes" do
        r1 = Node.get 1

        r1.children.size.should == 3
        r1.children.delete(Node.get(4))
        Node.get(4).parent.should be_nil
        r1.children.size.should == 2
      end
    end

    describe 'through-associations' do
      before :all do
        repository(ADAPTER) do
          module Sweets
            class Shop
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              has n, :cakes, :class_name => 'Sweets::Cake'                                     # one_to_many
              has n, {:cakes => :recipe}, :class_name => 'Sweets::Recipe'                      # one_to_many => one_to_one
              has n, {:cakes => :ingredients}, :class_name => 'Sweets::Ingredient'             # one_to_many => one_to_one => one_to_many
              has n, {:cakes => :creator}, :class_name => 'Sweets::Creator'                    # one_to_many => one_to_one => one_to_one
              has n, {:cakes => :slices}, :class_name => 'Sweets::Slice'                       # one_to_many => one_to_many
              has n, {:cakes => :bites}, :class_name => 'Sweets::Bite'                         # one_to_many => one_to_many => one_to_many
              has n, {:cakes => :shape}, :class_name => 'Sweets::Shape'                        # one_to_many => one_to_many => one_to_one
              has n, {:cakes => :customers}, :class_name => 'Sweets::Customer'                 # one_to_many => many_to_one (pending)
              has 1, :shop_owner, :class_name => 'Sweets::ShopOwner'                           # one_to_one
              has 1, {:shop_owner => :wife}, :class_name => 'Sweets::Wife'                     # one_to_one => one_to_one
              has 1, {:shop_owner => :ring}, :class_name => 'Sweets::Ring'                     # one_to_one => one_to_one => one_to_one
              has n, {:shop_owner => :coats}, :class_name => 'Sweets::Coat'                    # one_to_one => one_to_one => one_to_many
              has n, {:shop_owner => :children}, :class_name => 'Sweets::Child'                # one_to_one => one_to_many
              has n, {:shop_owner => :toys}, :class_name => 'Sweets::Toy'                      # one_to_one => one_to_many => one_to_many
              has n, {:shop_owner => :booger}, :class_name => 'Sweets::Booger'                 # one_to_one => one_to_many => one_to_one
            end

            class ShopOwner
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :shop, :class_name => 'Sweets::Shop'
              has 1, :wife, :class_name => 'Sweets::Wife'
              has n, :children, :class_name => 'Sweets::Child'
              has n, {:children => :toys}, :class_name => 'Sweets::Toy'
              has n, {:children => :booger}, :class_name => 'Sweets::Booger'
              has n, {:wife => :coats}, :class_name => 'Sweets::Coat'
              has 1, {:wife => :ring}, :class_name => 'Sweets::Ring'
              has n, {:children => :schools}, :class_name => 'Sweets::School'
            end

            class Wife
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :shop_owner, :class_name => 'Sweets::ShopOwner'
              has 1, :ring, :class_name => 'Sweets::Ring'
              has n, :coats, :class_name => 'Sweets::Coat'
            end

            class Coat
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :wife, :class_name => 'Sweets::Wife'
            end

            class Ring
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :wife, :class_name => 'Sweets::Wife'
            end

            class Child
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :shop_owner, :class_name => 'Sweets::ShopOwner'
              has n, :toys, :class_name => 'Sweets::Toy'
              has 1, :booger, :class_name => 'Sweets::Booger'
            end

            class Booger
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :child, :class_name => 'Sweets::Child'
            end

            class Toy
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :child, :class_name => 'Sweets::Child'
            end

            class Cake
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :shop, :class_name => 'Sweets::Shop'
              belongs_to :customer, :class_name => 'Sweets::Customer'
              has n, :slices, :class_name => 'Sweets::Slice'
              has n, {:slices => :bites}, :class_name => 'Sweets::Bite'
              has 1, :recipe, :class_name => 'Sweets::Recipe'
              has n, {:recipe => :ingredients}, :class_name => 'Sweets::Ingredient'
              has 1, {:recipe => :creator}, :class_name => 'Sweets::Creator'
              has n, {:slices => :shape}, :class_name => 'Sweets::Shape'
            end

            class Recipe
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :cake, :class_name => 'Sweets::Cake'
              has n, :ingredients, :class_name => 'Sweets::Ingredient'
              has 1, :creator, :class_name => 'Sweets::Creator'
            end

            class Customer
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              has n, :cakes, :class_name => 'Sweets::Cake'
            end

            class Creator
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :recipe, :class_name => 'Sweets::Recipe'
            end

            class Ingredient
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :recipe, :class_name => 'Sweets::Recipe'
            end

            class Slice
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :size, Integer
              belongs_to :cake, :class_name => 'Sweets::Cake'
              has n, :bites, :class_name => 'Sweets::Bite'
              has 1, :shape, :class_name => 'Sweets::Shape'
            end

            class Shape
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :slice, :class_name => 'Sweets::Slice'
            end

            class Bite
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Integer, :serial => true
              property :name, String
              belongs_to :slice, :class_name => 'Sweets::Slice'
            end

            DataMapper::Resource.descendents.each do |descendent|
              descendent.auto_migrate!(ADAPTER) if descendent.name =~ /^Sweets::/
            end

            betsys = Shop.new(:name => "Betsy's")
            betsys.save

            #
            # one_to_many
            #

            german_chocolate = Cake.new(:name => 'German Chocolate')
            betsys.cakes << german_chocolate
            german_chocolate.save
            short_cake = Cake.new(:name => 'Short Cake')
            betsys.cakes << short_cake
            short_cake.save

            # one_to_many => many_to_one

            old_customer = Customer.new(:name => 'John Johnsen')
            old_customer.cakes << german_chocolate
            old_customer.cakes << short_cake
            german_chocolate.save
            short_cake.save

            # one_to_many => one_to_one

            schwarzwald = Recipe.new(:name => 'Schwarzwald Cake')
            schwarzwald.save
            german_chocolate.recipe = schwarzwald
            german_chocolate.save
            shortys_special = Recipe.new(:name => "Shorty's Special")
            shortys_special.save
            short_cake.recipe = shortys_special
            short_cake.save

            # one_to_many => one_to_one => one_to_one

            runar = Creator.new(:name => "Runar")
            schwarzwald.creator = runar
            runar.save
            berit = Creator.new(:name => 'Berit')
            shortys_special.creator = berit
            berit.save

            # one_to_many => one_to_one => one_to_many

            4.times do |i| schwarzwald.ingredients << Ingredient.new(:name => "Secret ingredient nr #{i}") end
            6.times do |i| shortys_special.ingredients << Ingredient.new(:name => "Well known ingredient nr #{i}") end

            # one_to_many => one_to_many

            10.times do |i| german_chocolate.slices << Slice.new(:size => i) end
            5.times do |i| short_cake.slices << Slice.new(:size => i) end
            german_chocolate.slices.size.should == 10
            # one_to_many => one_to_many => one_to_one

            german_chocolate.slices.each do |slice|
              shape = Shape.new(:name => 'square')
              slice.shape = shape
              shape.save
            end
            short_cake.slices.each do |slice|
              shape = Shape.new(:name => 'round')
              slice.shape = shape
              shape.save
            end

            # one_to_many => one_to_many => one_to_many
            german_chocolate.slices.each do |slice|
              6.times do |i|
                slice.bites << Bite.new(:name => "Big bite nr #{i}")
              end
            end
            short_cake.slices.each do |slice|
              3.times do |i|
                slice.bites << Bite.new(:name => "Small bite nr #{i}")
              end
            end

            #
            # one_to_one
            #

            betsy = ShopOwner.new(:name => 'Betsy')
            betsys.shop_owner = betsy
            betsys.save

            # one_to_one => one_to_one

            barry = Wife.new(:name => 'Barry')
            betsy.wife = barry
            barry.save

            # one_to_one => one_to_one => one_to_one

            golden = Ring.new(:name => 'golden')
            barry.ring = golden
            golden.save

            # one_to_one => one_to_one => one_to_many

            3.times do |i|
              barry.coats << Coat.new(:name => "Fancy coat nr #{i}")
            end

            # one_to_one => one_to_many

            5.times { |i| betsy.children << Child.new(:name => "Snotling nr #{i}") }

            # one_to_one => one_to_many => one_to_many

            betsy.children.each do |child|
              4.times do |i|
                child.toys << Toy.new(:name => "Cheap toy nr #{i}")
              end
            end

            # one_to_one => one_to_many => one_to_one

            betsy.children.each do |child|
              booger = Booger.new(:name => 'Nasty booger')
              child.booger = booger
              booger.save
            end
          end
        end
      end

      #
      # one_to_many
      #

      it "should return the right children for one_to_many => one_to_many relationships" do
        Sweets::Shop.first.slices.size.should == 15
        10.times do |i|
          Sweets::Shop.first.slices.select do |slice|
            slice.cake == Sweets::Cake.first("name" => "German Chocolate") && slice.size == i
          end
        end
      end

      it "should return the right children for one_to_many => one_to_many => one_to_one" do
        Sweets::Shop.first.shape.size.should == 15
        Sweets::Shop.first.shape.select do |shape|
          shape.name == "square"
        end.size.should == 10
        Sweets::Shop.first.shape.select do |shape|
          shape.name == "round"
        end.size.should == 5
      end

      it "should return the right children for one_to_many => one_to_many => one_to_many" do
        Sweets::Shop.first.bites.size.should == 75
        Sweets::Shop.first.bites.select do |bite|
          bite.slice.cake == Sweets::Cake.first(:name => "German Chocolate")
        end.size.should == 60
        Sweets::Shop.first.bites.select do |bite|
          bite.slice.cake == Sweets::Cake.first(:name => "Short Cake")
        end.size.should == 15
      end

      it "should return the right children for one_to_many => many_to_one relationships" do
        pending("Implement through for one_to_many => many_to_one relationship")
        Sweets::Customer.first.cakes.size.should == 2
        Sweets::Shop.first.customers.select do |customer|
          customer.name == 'John Johnsen'
        end.size.should == 1
        # another example can be found here: http://pastie.textmate.org/private/tt1hf1syfsytyxdgo4qxaw
      end

      it "should return the right children for one_to_many => one_to_one relationships" do
        Sweets::Shop.first.recipe.size.should == 2
        Sweets::Shop.first.recipe.select do |recipe|
          recipe.name == "Schwarzwald Cake"
        end.size.should == 1
        Sweets::Shop.first.recipe.select do |recipe|
          recipe.name == "Shorty's Special"
        end.size.should == 1
      end

      it "should return the right children for one_to_many => one_to_one => one_to_one relationships" do
        Sweets::Shop.first.creator.size.should == 2
        Sweets::Shop.first.creator.any? do |creator|
          creator.name == "Runar"
        end.should == true
        Sweets::Shop.first.creator.any? do |creator|
          creator.name == "Berit"
        end.should == true
      end

      it "should return the right children for one_to_many => one_to_one => one_to_many relationships" do
        Sweets::Shop.first.ingredients.size.should == 10
        4.times do |i|
          Sweets::Shop.first.ingredients.any? do |ingredient|
            ingredient.name == "Secret ingredient nr #{i}" && ingredient.recipe.cake == Sweets::Cake.first(:name => "German Chocolate")
          end.should == true
        end
        6.times do |i|
          Sweets::Shop.first.ingredients.any? do |ingredient|
            ingredient.name == "Well known ingredient nr #{i}" && ingredient.recipe.cake == Sweets::Cake.first(:name => "Short Cake")
          end.should == true
        end
      end

      #
      # one_to_one
      #

      it "should return the right children for one_to_one => one_to_one relationships" do
        Sweets::Shop.first.wife.should == Sweets::Wife.first
      end

      it "should return the right children for one_to_one => one_to_one => one_to_one relationships" do
        Sweets::Shop.first.ring.should == Sweets::Ring.first
      end

      it "should return the right children for one_to_one => one_to_one => one_to_many relationships" do
        Sweets::Shop.first.coats.size.should == 3
        3.times do |i|
          Sweets::Shop.first.coats.any? do |coat|
            coat.name == "Fancy coat nr #{i}"
          end.should == true
        end
      end

      it "should return the right children for one_to_one => one_to_many relationships" do
        Sweets::Shop.first.children.size.should == 5
        5.times do |i|
          Sweets::Shop.first.children.any? do |child|
            child.name == "Snotling nr #{i}"
          end.should == true
        end
      end

      it "should return the right children for one_to_one => one_to_many => one_to_one relationships" do
        Sweets::Shop.first.booger.size.should == 5
        Sweets::Shop.first.booger.inject(Set.new) do |sum, booger|
          sum << booger.child_id
        end.size.should == 5
      end

      it "should return the right children for one_to_one => one_to_many => one_to_many relationships" do
        Sweets::Shop.first.toys.size.should == 20
        5.times do |child_nr|
          4.times do |toy_nr|
            Sweets::Shop.first.toys.any? do |toy|
              toy.name == "Cheap toy nr #{toy_nr}" && toy.child = Sweets::Child.first(:name => "Snotling nr #{child_nr}")
            end.should == true
          end
        end
      end

      #
      # misc
      #

      it "should raise exception if you try to change it" do
        lambda do
          Sweets::Shop.first.wife = Sweets::Wife.new(:name => 'Larry')
        end.should raise_error(DataMapper::Associations::ImmutableAssociationError)
      end

    end
  end
end
