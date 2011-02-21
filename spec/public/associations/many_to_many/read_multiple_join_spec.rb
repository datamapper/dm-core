require 'spec_helper'
describe 'Many to Many Associations read across multiple join associations' do
  before :all do
    class ::User
      include DataMapper::Resource

      property :id, Serial

      has n, :sales
      has n, :sale_items, :through => :sales
      has n, :items,      :through => :sale_items
    end

    class ::Sale
      include DataMapper::Resource

      property :id, Serial

      belongs_to :user
      has n, :sale_items
      has n, :items, :through => :sale_items
    end

    class ::SaleItem
      include DataMapper::Resource

      property :id, Serial

      belongs_to :sale
      belongs_to :item
    end

    class ::Item
      include DataMapper::Resource

      property :id, Serial

      has n, :sale_items
    end

    DataMapper.finalize
  end

  supported_by :all do
    before :all do
      @user = User.create
      @sale = @user.sales.create

      5.times { @sale.items.create }
    end

    before :all do
      @no_join = defined?(DataMapper::Adapters::InMemoryAdapter) && @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter) ||
                 defined?(DataMapper::Adapters::YamlAdapter)     && @adapter.kind_of?(DataMapper::Adapters::YamlAdapter)

      @skip = @no_join
    end

    before do
      pending if @skip
    end

    it 'should return all the created entries' do
      @user.items.to_a.should == Item.all.to_a
      @sale.items.to_a.should == Item.all.to_a
    end
  end
end
