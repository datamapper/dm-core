require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe String do
  it 'should translate' do
    '%s is great!'.t('DataMapper').should == 'DataMapper is great!'
  end
end
