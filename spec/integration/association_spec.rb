require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if ADAPTER
  repository(ADAPTER) do
    class Engine
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Serial
      property :name, String

      has n, :yards
      has n, :fussy_yards, :class_name => 'Yard', :rating.gte => 3, :type => 'particular'
    end

    class Yard
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Serial
      property :name, String
      property :rating, Integer
      property :type, String

      belongs_to :engine
    end

    class Pie
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Serial
      property :name, String

      belongs_to :sky
    end

    class Sky
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Serial
      property :name, String

      has 1, :pie
    end

    class Host
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Serial
      property :name, String

      has n, :slices, :order => [:id.desc]
    end

    class Slice
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Serial
      property :name, String

      belongs_to :host
    end

    class Node
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id, Serial
      property :name, String

      has n, :children, :class_name => 'Node', :child_key => [ :parent_id ]
      belongs_to :parent, :class_name => 'Node', :child_key => [ :parent_id ]
    end

    module Models
      class Project
        include DataMapper::Resource

        def self.default_repository_name
          ADAPTER
        end

        property :title, String, :length => 255, :key => true
        property :summary, DataMapper::Types::Text

        has n, :tasks, :class_name => 'Models::Task'
        has 1, :goal, :class_name => 'Models::Goal'
      end

      class Goal
        include DataMapper::Resource

        def self.default_repository_name
          ADAPTER
        end

        property :title, String, :length => 255, :key => true
        property :summary, DataMapper::Types::Text

        belongs_to :project, :class_name => "Models::Project"
      end

      class Task
        include DataMapper::Resource

        def self.default_repository_name
          ADAPTER
        end

        property :title, String, :length => 255, :key => true
        property :description, DataMapper::Types::Text

        belongs_to :project, :class_name => 'Models::Project'
      end
    end

    class Galaxy
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :name, String, :key => true, :length => 255
      property :size, Float,  :key => true, :precision => 15, :scale => 6
    end

    class Star
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      belongs_to :galaxy
    end
  end

  describe DataMapper::Associations do
    describe 'namespaced associations' do
      before do
        Models::Project.auto_migrate!(ADAPTER)
        Models::Task.auto_migrate!(ADAPTER)
        Models::Goal.auto_migrate!(ADAPTER)
      end

      it 'should allow namespaced classes in parent and child for many <=> one' do
        m = Models::Project.new(:title => 'p1', :summary => 'sum1')
        m.tasks << Models::Task.new(:title => 't1', :description => 'desc 1')
        m.save

        t = Models::Task.first(:title => 't1')

        t.project.should_not be_nil
        t.project.title.should == 'p1'
        t.project.tasks.size.should == 1

        p = Models::Project.first(:title => 'p1')

        p.tasks.size.should == 1
        p.tasks[0].title.should == 't1'
      end

      it 'should allow namespaced classes in parent and child for one <=> one' do
        g = Models::Goal.new(:title => "g2", :description => "desc 2")
        p = Models::Project.create!(:title => "p2", :summary => "sum 2", :goal => g)

        pp = Models::Project.first(:title => 'p2')
        pp.goal.title.should == "g2"

        g = Models::Goal.first(:title => "g2")

        g.project.should_not be_nil
        g.project.title.should == 'p2'

        g.project.goal.should_not be_nil
      end
    end

    describe 'many to one associations' do
      before do
        Engine.auto_migrate!(ADAPTER)
        Yard.auto_migrate!(ADAPTER)

        engine1 = Engine.create!(:name => 'engine1')
        engine2 = Engine.create!(:name => 'engine2')
        yard1   = Yard.create!(:name => 'yard1', :engine => engine1)
        yard2   = Yard.create!(:name => 'yard2')
      end

      it '#belongs_to' do
        yard = Yard.new
        yard.should respond_to(:engine)
        yard.should respond_to(:engine=)
      end

      it 'should load without the parent'

      it 'should allow substituting the parent' do
        yard1   = Yard.first(:name => 'yard1')
        engine2 = Engine.first(:name => 'engine2')

        yard1.engine = engine2
        yard1.save
        Yard.first(:name => 'yard1').engine.should == engine2
      end

      it '#belongs_to with namespaced models' do
        repository(ADAPTER) do
          module FlightlessBirds
            class Ostrich
              include DataMapper::Resource
              property :id, Serial
              property :name, String
              belongs_to :sky # there's something sad about this :'(
            end
          end

          FlightlessBirds::Ostrich.properties.slice(:sky_id).should_not be_empty
        end
      end

      it 'should load the associated instance' do
        engine1 = Engine.first(:name => 'engine1')
        Yard.first(:name => 'yard1').engine.should == engine1
      end

      it 'should save the association key in the child' do
        engine2 = Engine.first(:name => 'engine2')

        Yard.create!(:name => 'yard3', :engine => engine2)
        Yard.first(:name => 'yard3').engine.should == engine2
      end

      it 'should set the association key immediately' do
        engine = Engine.first(:name => 'engine1')
        Yard.new(:engine => engine).engine_id.should == engine.id
      end

      it 'should save the parent upon saving of child' do
        e = Engine.new(:name => 'engine10')
        y = Yard.create!(:name => 'yard10', :engine => e)

        y.engine.name.should == 'engine10'
        Engine.first(:name => 'engine10').should_not be_nil
      end

      it 'should convert NULL parent ids into nils' do
        Yard.first(:name => 'yard2').engine.should be_nil
      end

      it 'should save nil parents as NULL ids' do
        y1 = Yard.create!(:id => 20, :name => 'yard20')
        y2 = Yard.create!(:id => 30, :name => 'yard30', :engine => nil)

        y1.id.should == 20
        y1.engine.should be_nil
        y2.id.should == 30
        y2.engine.should be_nil
      end

      it 'should respect length on foreign keys' do
        property = Star.relationships[:galaxy].child_key[:galaxy_name]
        property.length.should == 255
      end

      it 'should respect precision and scale on foreign keys' do
        property = Star.relationships[:galaxy].child_key[:galaxy_size]
        property.precision.should == 15
        property.scale.should == 6
      end
    end

    describe 'one to one associations' do
      before do
        Sky.auto_migrate!(ADAPTER)
        Pie.auto_migrate!(ADAPTER)

        pie1 = Pie.create!(:name => 'pie1')
        pie2 = Pie.create!(:name => 'pie2')
        sky1 = Sky.create!(:name => 'sky1', :pie => pie1)
      end

      it '#has 1' do
        s = Sky.new
        s.should respond_to(:pie)
        s.should respond_to(:pie=)
      end

      it 'should allow substituting the child' do
        sky1 = Sky.first(:name => 'sky1')
        pie1 = Pie.first(:name => 'pie1')
        pie2 = Pie.first(:name => 'pie2')

        sky1.pie.should == pie1
        pie2.sky.should be_nil

        sky1.pie = pie2
        sky1.save

        pie2.sky.should == sky1
        pie1.reload.sky.should be_nil
      end

      it 'should load the associated instance' do
        sky1 = Sky.first(:name => 'sky1')
        pie1 = Pie.first(:name => 'pie1')

        sky1.pie.should == pie1
      end

      it 'should save the association key in the child' do
        pie2 = Pie.first(:name => 'pie2')

        sky2 = Sky.create!(:id => 2, :name => 'sky2', :pie => pie2)
        pie2.sky.should == sky2
      end

      it 'should save the children upon saving of parent' do
        p = Pie.new(:id => 10, :name => 'pie10')
        s = Sky.create!(:id => 10, :name => 'sky10', :pie => p)

        p.sky.should == s

        Pie.first(:name => 'pie10').should_not be_nil
      end

      it 'should save nil parents as NULL ids' do
        p1 = Pie.create!(:id => 20, :name => 'pie20')
        p2 = Pie.create!(:id => 30, :name => 'pie30', :sky => nil)

        p1.id.should == 20
        p1.sky.should be_nil
        p2.id.should == 30
        p2.sky.should be_nil
      end
    end

    describe 'one to many associations' do
      before do
        Host.auto_migrate!(ADAPTER)
        Slice.auto_migrate!(ADAPTER)
        Engine.auto_migrate!(ADAPTER)
        Yard.auto_migrate!(ADAPTER)

        host1  = Host.create!(:name => 'host1')
        host2  = Host.create!(:name => 'host2')
        slice1 = Slice.create!(:name => 'slice1', :host => host1)
        slice2 = Slice.create!(:name => 'slice2', :host => host1)
        slice3 = Slice.create!(:name => 'slice3')
      end

      it '#has n' do
        h = Host.new
        h.should respond_to(:slices)
      end

      it 'should allow removal of a child through a loaded association' do
        host1  = Host.first(:name => 'host1')
        slice2 = host1.slices.first

        host1.slices.size.should == 2
        host1.slices.delete(slice2)
        host1.slices.size.should == 1

        slice2 = Slice.first(:name => 'slice2')
        slice2.host.should_not be_nil

        host1.save

        slice2.reload.host.should be_nil
      end

      it 'should use the IdentityMap correctly' do
        repository(ADAPTER) do
          host1 = Host.first(:name => 'host1')

          slice =  host1.slices.first
          slice2 = host1.slices(:order => [:id]).last # should be the same as 1
          slice3 = Slice.get(2) # should be the same as 1

          slice.object_id.should == slice2.object_id
          slice.object_id.should == slice3.object_id
        end
      end

      it '#<< should add exactly the parameters' do
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
        engine = Engine.get!(engine.id)
        engine.yards.size.should == 4
        4.times do |i|
          engine.yards.any? do |yard|
            yard.name == "yard nr #{i}"
          end.should == true
        end
      end

      it '#<< should add default values for relationships that have conditions' do
        # it should add default values
        engine = Engine.new(:name => 'my engine')
        engine.fussy_yards << Yard.new(:name => 'yard 1', :rating => 4 )
        engine.save
        Yard.first(:name => 'yard 1').type.should == 'particular'
        # it should not add default values if the condition's property already has a value
        engine.fussy_yards << Yard.new(:name => 'yard 2', :rating => 4, :type => 'not particular')
        engine.save
        Yard.first(:name => 'yard 2').type.should == 'not particular'
        # it should ignore non :eql conditions
        engine.fussy_yards << Yard.new(:name => 'yard 3')
        engine.save
        Yard.first(:name => 'yard 3').rating.should == nil
      end

      it 'should load the associated instances, in the correct order' do
        host1 = Host.first(:name => 'host1')

        host1.slices.should_not be_nil
        host1.slices.size.should == 2
        host1.slices.first.name.should == 'slice2' # ordered by [:id.desc]
        host1.slices.last.name.should == 'slice1'

        slice3 = Slice.first(:name => 'slice3')

        slice3.host.should be_nil
      end

      it 'should add and save the associated instance' do
        host1 = Host.first(:name => 'host1')
        host1.slices << Slice.new(:id => 4, :name => 'slice4')
        host1.save

        Slice.first(:name => 'slice4').host.should == host1
      end

      it 'should not save the associated instance if the parent is not saved' do
        h = Host.new(:id => 10, :name => 'host10')
        h.slices << Slice.new(:id => 10, :name => 'slice10')

        Slice.first(:name => 'slice10').should be_nil
      end

      it 'should save the associated instance upon saving of parent' do
        h = Host.new(:id => 10, :name => 'host10')
        h.slices << Slice.new(:id => 10, :name => 'slice10')
        h.save

        s = Slice.first(:name => 'slice10')

        s.should_not be_nil
        s.host.should == h
      end

      it 'should save the associated instances upon saving of parent when mass-assigned' do
        h = Host.create!(:id => 10, :name => 'host10', :slices => [ Slice.new(:id => 10, :name => 'slice10') ])

        s = Slice.first(:name => 'slice10')

        s.should_not be_nil
        s.host.should == h
      end

      it 'should have finder-functionality' do
        h = Host.first(:name => 'host1')

        h.slices.should have(2).entries

        s = h.slices.all(:name => 'slice2')

        s.should have(1).entries
        s.first.id.should == 2

        h.slices.first(:name => 'slice2').should == s.first
      end
    end

    describe 'many-to-one and one-to-many associations combined' do
      before do
        Node.auto_migrate!(ADAPTER)

        Node.create!(:name => 'r1')
        Node.create!(:name => 'r2')
        Node.create!(:name => 'r1c1',   :parent_id => 1)
        Node.create!(:name => 'r1c2',   :parent_id => 1)
        Node.create!(:name => 'r1c3',   :parent_id => 1)
        Node.create!(:name => 'r1c1c1', :parent_id => 3)
      end

      it 'should properly set #parent' do
        r1 = Node.get 1
        r1.parent.should be_nil

        n3 = Node.get 3
        n3.parent.should == r1

        n6 = Node.get 6
        n6.parent.should == n3
      end

      it 'should properly set #children' do
        r1 = Node.get(1)
        off = r1.children
        off.size.should == 3
        off.include?(Node.get(3)).should be_true
        off.include?(Node.get(4)).should be_true
        off.include?(Node.get(5)).should be_true
      end

      it 'should allow to create root nodes' do
        r = Node.create!(:name => 'newroot')
        r.parent.should be_nil
        r.children.size.should == 0
      end

      it 'should properly delete nodes' do
        r1 = Node.get 1

        r1.children.size.should == 3
        r1.children.delete(Node.get(4))
        r1.save
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
              property :id, Serial
              property :name, String
              has n, :cakes,                                :class_name => 'Sweets::Cake'        # has n
              has n, :recipes,     :through => :cakes,      :class_name => 'Sweets::Recipe'      # has n => has 1
              has n, :ingredients, :through => :cakes,      :class_name => 'Sweets::Ingredient'  # has n => has 1 => has n
              has n, :creators,    :through => :cakes,      :class_name => 'Sweets::Creator'     # has n => has 1 => has 1
              has n, :slices,      :through => :cakes,      :class_name => 'Sweets::Slice'       # has n => has n
              has n, :bites,       :through => :cakes,      :class_name => 'Sweets::Bite'        # has n => has n => has n
              has n, :shapes,      :through => :cakes,      :class_name => 'Sweets::Shape'       # has n => has n => has 1
              has n, :customers,   :through => :cakes,      :class_name => 'Sweets::Customer'    # has n => belongs_to (pending)
              has 1, :shop_owner,                           :class_name => 'Sweets::ShopOwner'   # has 1
              has 1, :wife,        :through => :shop_owner, :class_name => 'Sweets::Wife'        # has 1 => has 1
              has 1, :ring,        :through => :shop_owner, :class_name => 'Sweets::Ring'        # has 1 => has 1 => has 1
              has n, :coats,       :through => :shop_owner, :class_name => 'Sweets::Coat'        # has 1 => has 1 => has n
              has n, :children,    :through => :shop_owner, :class_name => 'Sweets::Child'       # has 1 => has n
              has n, :toys,        :through => :shop_owner, :class_name => 'Sweets::Toy'         # has 1 => has n => has n
              has n, :boogers,     :through => :shop_owner, :class_name => 'Sweets::Booger'      # has 1 => has n => has 1
            end

            class ShopOwner
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              belongs_to :shop, :class_name => 'Sweets::Shop'
              has 1, :wife,                            :class_name => 'Sweets::Wife'
              has n, :children,                        :class_name => 'Sweets::Child'
              has n, :toys,     :through => :children, :class_name => 'Sweets::Toy'
              has n, :boogers,  :through => :children, :class_name => 'Sweets::Booger'
              has n, :coats,    :through => :wife,     :class_name => 'Sweets::Coat'
              has 1, :ring,     :through => :wife,     :class_name => 'Sweets::Ring'
              has n, :schools,  :through => :children, :class_name => 'Sweets::School'
            end

            class Wife
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              belongs_to :shop_owner, :class_name => 'Sweets::ShopOwner'
              has 1, :ring,  :class_name => 'Sweets::Ring'
              has n, :coats, :class_name => 'Sweets::Coat'
            end

            class Coat
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              belongs_to :wife, :class_name => 'Sweets::Wife'
            end

            class Ring
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              belongs_to :wife, :class_name => 'Sweets::Wife'
            end

            class Child
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              belongs_to :shop_owner, :class_name => 'Sweets::ShopOwner'
              has n, :toys,   :class_name => 'Sweets::Toy'
              has 1, :booger, :class_name => 'Sweets::Booger'
            end

            class Booger
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              belongs_to :child, :class_name => 'Sweets::Child'
            end

            class Toy
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              belongs_to :child, :class_name => 'Sweets::Child'
            end

            class Cake
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              belongs_to :shop, :class_name => 'Sweets::Shop'
              belongs_to :customer, :class_name => 'Sweets::Customer'
              has n, :slices,                           :class_name => 'Sweets::Slice'
              has n, :bites,       :through => :slices, :class_name => 'Sweets::Bite'
              has 1, :recipe,                           :class_name => 'Sweets::Recipe'
              has n, :ingredients, :through => :recipe, :class_name => 'Sweets::Ingredient'
              has 1, :creator,     :through => :recipe, :class_name => 'Sweets::Creator'
              has n, :shapes,      :through => :slices, :class_name => 'Sweets::Shape'
            end

            class Recipe
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              belongs_to :cake, :class_name => 'Sweets::Cake'
              has n, :ingredients, :class_name => 'Sweets::Ingredient'
              has 1, :creator,     :class_name => 'Sweets::Creator'
            end

            class Customer
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              has n, :cakes, :class_name => 'Sweets::Cake'
            end

            class Creator
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              belongs_to :recipe, :class_name => 'Sweets::Recipe'
            end

            class Ingredient
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              belongs_to :recipe, :class_name => 'Sweets::Recipe'
            end

            class Slice
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
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
              property :id, Serial
              property :name, String
              belongs_to :slice, :class_name => 'Sweets::Slice'
            end

            class Bite
              include DataMapper::Resource
              def self.default_repository_name
                ADAPTER
              end
              property :id, Serial
              property :name, String
              belongs_to :slice, :class_name => 'Sweets::Slice'
            end

            DataMapper::Resource.descendants.each do |descendant|
              descendant.auto_migrate!(ADAPTER) if descendant.name =~ /^Sweets::/
            end

            betsys = Shop.new(:name => "Betsy's")
            betsys.save

            #
            # has n
            #

            german_chocolate = Cake.new(:name => 'German Chocolate')
            betsys.cakes << german_chocolate
            german_chocolate.save
            short_cake = Cake.new(:name => 'Short Cake')
            betsys.cakes << short_cake
            short_cake.save

            # has n => belongs_to

            old_customer = Customer.new(:name => 'John Johnsen')
            old_customer.cakes << german_chocolate
            old_customer.cakes << short_cake
            german_chocolate.save
            short_cake.save
            old_customer.save

            # has n => has 1

            schwarzwald = Recipe.new(:name => 'Schwarzwald Cake')
            schwarzwald.save
            german_chocolate.recipe = schwarzwald
            german_chocolate.save
            shortys_special = Recipe.new(:name => "Shorty's Special")
            shortys_special.save
            short_cake.recipe = shortys_special
            short_cake.save

            # has n => has 1 => has 1

            runar = Creator.new(:name => 'Runar')
            schwarzwald.creator = runar
            runar.save
            berit = Creator.new(:name => 'Berit')
            shortys_special.creator = berit
            berit.save

            # has n => has 1 => has n

            4.times do |i| schwarzwald.ingredients << Ingredient.new(:name => "Secret ingredient nr #{i}") end
            6.times do |i| shortys_special.ingredients << Ingredient.new(:name => "Well known ingredient nr #{i}") end

            # has n => has n

            10.times do |i| german_chocolate.slices << Slice.new(:size => i) end
            5.times do |i| short_cake.slices << Slice.new(:size => i) end
            german_chocolate.slices.size.should == 10
            # has n => has n => has 1

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

            # has n => has n => has n
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
            # has 1
            #

            betsy = ShopOwner.new(:name => 'Betsy')
            betsys.shop_owner = betsy
            betsys.save

            # has 1 => has 1

            barry = Wife.new(:name => 'Barry')
            betsy.wife = barry
            barry.save

            # has 1 => has 1 => has 1

            golden = Ring.new(:name => 'golden')
            barry.ring = golden
            golden.save

            # has 1 => has 1 => has n

            3.times do |i|
              barry.coats << Coat.new(:name => "Fancy coat nr #{i}")
            end
            barry.save

            # has 1 => has n

            5.times do |i|
              betsy.children << Child.new(:name => "Snotling nr #{i}")
            end
            betsy.save

            # has 1 => has n => has n

            betsy.children.each do |child|
              4.times do |i|
                child.toys << Toy.new(:name => "Cheap toy nr #{i}")
              end
              child.save
            end

            # has 1 => has n => has 1

            betsy.children.each do |child|
              booger = Booger.new(:name => 'Nasty booger')
              child.booger = booger
              child.save
            end
          end
        end
      end

      #
      # has n
      #

      it 'should return the right children for has n => has n relationships' do
        Sweets::Shop.first.slices.size.should == 15
        10.times do |i|
          Sweets::Shop.first.slices.select do |slice|
            slice.cake == Sweets::Cake.first(:name => 'German Chocolate') && slice.size == i
          end
        end
      end

      it 'should return the right children for has n => has n => has 1' do
        Sweets::Shop.first.shapes.size.should == 15
        Sweets::Shop.first.shapes.select do |shape|
          shape.name == 'square'
        end.size.should == 10
        Sweets::Shop.first.shapes.select do |shape|
          shape.name == 'round'
        end.size.should == 5
      end

      it 'should return the right children for has n => has n => has n' do
        Sweets::Shop.first.bites.size.should == 75
        Sweets::Shop.first.bites.select do |bite|
          bite.slice.cake == Sweets::Cake.first(:name => 'German Chocolate')
        end.size.should == 60
        Sweets::Shop.first.bites.select do |bite|
          bite.slice.cake == Sweets::Cake.first(:name => 'Short Cake')
        end.size.should == 15
      end

      it 'should return the right children for has n => belongs_to relationships' do
        Sweets::Customer.first.cakes.size.should == 2
        customers = Sweets::Shop.first.customers.select do |customer|
          customer.name == 'John Johnsen'
        end
        customers.size.should == 1
        # another example can be found here: http://pastie.textmate.org/private/tt1hf1syfsytyxdgo4qxawﬂ
      end

      it 'should return the right children for has n => has 1 relationships' do
        Sweets::Shop.first.recipes.size.should == 2
        Sweets::Shop.first.recipes.select do |recipe|
          recipe.name == 'Schwarzwald Cake'
        end.size.should == 1
        Sweets::Shop.first.recipes.select do |recipe|
          recipe.name == "Shorty's Special"
        end.size.should == 1
      end

      it 'should return the right children for has n => has 1 => has 1 relationships' do
        Sweets::Shop.first.creators.size.should == 2
        Sweets::Shop.first.creators.any? do |creator|
          creator.name == 'Runar'
        end.should == true
        Sweets::Shop.first.creators.any? do |creator|
          creator.name == 'Berit'
        end.should == true
      end

      it 'should return the right children for has n => has 1 => has n relationships' do
        Sweets::Shop.first.ingredients.size.should == 10
        4.times do |i|
          Sweets::Shop.first.ingredients.any? do |ingredient|
            ingredient.name == "Secret ingredient nr #{i}" && ingredient.recipe.cake == Sweets::Cake.first(:name => 'German Chocolate')
          end.should == true
        end
        6.times do |i|
          Sweets::Shop.first.ingredients.any? do |ingredient|
            ingredient.name == "Well known ingredient nr #{i}" && ingredient.recipe.cake == Sweets::Cake.first(:name => 'Short Cake')
          end.should == true
        end
      end

      #
      # has 1
      #

      it 'should return the right children for has 1 => has 1 relationships' do
        Sweets::Shop.first.wife.should == Sweets::Wife.first
      end

      it 'should return the right children for has 1 => has 1 => has 1 relationships' do
        Sweets::Shop.first.ring.should == Sweets::Ring.first
      end

      it 'should return the right children for has 1 => has 1 => has n relationships' do
        Sweets::Shop.first.coats.size.should == 3
        3.times do |i|
          Sweets::Shop.first.coats.any? do |coat|
            coat.name == "Fancy coat nr #{i}"
          end.should == true
        end
      end

      it 'should return the right children for has 1 => has n relationships' do
        Sweets::Shop.first.children.size.should == 5
        5.times do |i|
          Sweets::Shop.first.children.any? do |child|
            child.name == "Snotling nr #{i}"
          end.should == true
        end
      end

      it 'should return the right children for has 1 => has n => has 1 relationships' do
        Sweets::Shop.first.boogers.size.should == 5
        Sweets::Shop.first.boogers.inject(Set.new) do |sum, booger|
          sum << booger.child_id
        end.size.should == 5
      end

      it 'should return the right children for has 1 => has n => has n relationships' do
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

      it 'should raise exception if you try to change it' do
        lambda do
          Sweets::Shop.first.wife = Sweets::Wife.new(:name => 'Larry')
        end.should raise_error(DataMapper::Associations::ImmutableAssociationError)
      end

    end

    if false # Many to many not yet implemented
    describe "many to many associations" do
      before(:all) do
        class RightItem
          include DataMapper::Resource

          def self.default_repository_name
            ADAPTER
          end

          property :id, Serial
          property :name, String

          has n..n, :left_items
        end

        class LeftItem
          include DataMapper::Resource

          def self.default_repository_name
            ADAPTER
          end

          property :id, Serial
          property :name, String

          has n..n, :right_items
        end

        RightItem.auto_migrate!
        LeftItem.auto_migrate!
      end

      def create_item_pair(number)
        @ri = RightItem.new(:name => "ri#{number}")
        @li = LeftItem.new(:name => "li#{number}")
      end

      it "should add to the assocaiton from the left" do
        pending "Waiting on Many To Many to be implemented"
        create_item_pair "0000"
        @ri.save; @li.save
        @ri.should_not be_new_record
        @li.should_not be_new_record

        @li.right_items << @ri
        @li.right_items.should include(@ri)
        @li.reload
        @ri.reload
        @li.right_items.should include(@ri)
      end

      it "should add to the association from the right" do
        create_item_pair "0010"
        @ri.save; @li.save
        @ri.should_not be_new_record
        @li.should_not be_new_record

        @ri.left_items << @li
        @ri.left_items.should include(@li)
        @li.reload
        @ri.reload
        @ri.left_items.should include(@li)
      end

      it "should load the assocaited collection from the either side" do
        pending "Waiting on Many To Many to be implemented"
        create_item_pair "0020"
        @ri.save; @li.save
        @ri.left_items << @li
        @ri.reload; @li.reload

        @ri.left_items.should include(@li)
        @li.right_items.should include(@ri)
      end

      it "should load the assocatied collection from the right" do
        pending "Waiting on Many To Many to be implemented"
        create_item_pair "0030"
        @ri.save; @li.save
        @li.right_items << @li
        @ri.reload; @li.reload

        @ri.left_items.should include(@li)
        @li.right_items.should include(@ri)

      end

      it "should save the left side of the association if new record" do
        pending "Waiting on Many To Many to be implemented"
        create_item_pair "0040"
        @ri.save
        @li.should be_new_record
        @ri.left_items << @li
        @li.should_not be_new_record
      end

      it "should save the right side of the assocaition if new record" do
        pending "Waiting on Many To Many to be implemented"
        create_item_pair "0050"
        @li.save
        @ri.should be_new_record
        @li.right_items << @ri
        @ri.should_not be_new_record
      end

      it "should save both side of the assocaition if new record" do
        pending "Waiting on Many To Many to be implemented"
        create_item_pair "0060"
        @li.should be_new_record
        @ri.should be_new_record
        @ri.left_items << @li
        @ri.should_not be_new_record
        @li.should_not be_new_record
      end

      it "should remove an item from the left collection without destroying the item" do
        pending "Waiting on Many To Many to be implemented"
        create_item_pair "0070"
        @li.save; @ri.save
        @ri.left_items << @li
        @ri.reload; @li.reload
        @ri.left_items.should include(@li)
        @ri.left_items.delete(@li)
        @ri.left_items.should_not include(@li)
        @li.reload
        LeftItem.get(@li.id).should_not be_nil
      end

      it "should remove an item from the right collection without destroying the item" do
        pending "Waiting on Many To Many to be implemented"
        create_item_pair "0080"
        @li.save; @ri.save
        @li.right_items << @ri
        @li.reload; @ri.reload
        @li.right_items.should include(@ri)
        @li.right_items.delete(@ri)
        @li.right_items.should_not include(@ri)
        @ri.reload
        RightItem.get(@ri.id).should_not be_nil
      end

      it "should remove the item from the collection when an item is deleted" do
        pending "Waiting on Many To Many to be implemented"
        create_item_pair "0090"
        @li.save; @ri.save
        @ri.left_items << @li
        @ri.reload; @li.reload
        @ri.left_items.should include(@li)
        @li.destroy
        @ri.reload
        @ri.left_items.should_not include(@li)
      end
    end
  end
  end
end
