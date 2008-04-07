require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe DataMapper::Inflection do

  it 'should pluralize a word' do
    'car'.plural.should == 'cars'
    DataMapper::Inflection.pluralize('car').should == 'cars'
  end

  it 'should singularize a word' do
    "cars".singular.should == "car"
    DataMapper::Inflection.singularize('cars').should == 'car'
  end

  it 'should classify an underscored name' do
    DataMapper::Inflection.classify('data_mapper').should == 'DataMapper'
  end

  it 'should camelize an underscored name' do
    DataMapper::Inflection.camelize('data_mapper').should == 'DataMapper'
  end

  it 'should underscore a camelized name' do
    DataMapper::Inflection.underscore('DataMapper').should == 'data_mapper'
  end

  it 'should humanize names' do
    DataMapper::Inflection.humanize('employee_salary').should == 'Employee salary'
    DataMapper::Inflection.humanize('author_id').should == 'Author'
  end

  it 'should demodulize a module name' do
    DataMapper::Inflection.demodulize('DataMapper::Inflector').should == 'Inflector'
  end

  it 'should tableize a name (underscore with last word plural)' do
    DataMapper::Inflection.tableize('fancy_category').should == 'fancy_categories'
    DataMapper::Inflection.tableize('FancyCategory').should == 'fancy_categories'
  end

  it 'should create a fk name from a class name' do
    DataMapper::Inflection.foreign_key('Message').should == 'message_id'
    DataMapper::Inflection.foreign_key('Admin::Post').should == 'post_id'
  end





end
