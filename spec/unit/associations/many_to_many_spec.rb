require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe DataMapper::Associations::ManyToMany do

  load_models_for_metaphor :vehicles

  it 'should allow a declaration' do
    lambda do
      class Supplier
        has n, :manufacturers, :through => Resource
      end
    end.should_not raise_error
  end
end

describe DataMapper::Associations::ManyToMany::Proxy do
end
