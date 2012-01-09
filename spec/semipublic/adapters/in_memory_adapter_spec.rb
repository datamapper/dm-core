require 'spec_helper'
require 'dm-core/spec/shared/adapter_spec'

describe 'Adapter' do
  supported_by :in_memory do
    describe 'DataMapper::Adapters::InMemoryAdapter' do
      let(:adapter)    { DataMapper::Spec.adapter }
      let(:repository) { DataMapper.repository(adapter.name) }

      it_should_behave_like 'An Adapter'
    end
  end
end
