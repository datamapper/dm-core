require 'spec_helper'
require 'dm-core/support/ext/blank'

describe 'DataMapper::Ext.blank?', Object do
  it 'should be blank if it is nil' do
    object = Object.new
    class << object
      def nil?; true end
    end
    DataMapper::Ext.blank?(object).should == true
  end

  it 'should be blank if it is empty' do
    DataMapper::Ext.blank?({}).should == true
    DataMapper::Ext.blank?([]).should == true
  end

  it 'should not be blank if not nil or empty' do
    DataMapper::Ext.blank?(Object.new).should == false
    DataMapper::Ext.blank?([nil]).should == false
    DataMapper::Ext.blank?({ nil => 0 }).should == false
  end
end

describe 'DataMapper::Ext.blank?', Numeric do
  it 'should never be blank' do
    DataMapper::Ext.blank?(1).should == false
  end
end

describe 'DataMapper::Ext.blank?', NilClass do
  it 'should always be blank' do
    DataMapper::Ext.blank?(nil).should == true
  end
end

describe 'DataMapper::Ext.blank?', TrueClass do
  it 'should never be blank' do
    DataMapper::Ext.blank?(true).should == false
  end
end

describe 'DataMapper::Ext.blank?', FalseClass do
  it 'should always be blank' do
    DataMapper::Ext.blank?(false).should == true
  end
end

describe 'DataMapper::Ext.blank?', String do
  it 'should be blank if empty' do
    DataMapper::Ext.blank?('').should == true
  end

  it 'should be blank if it only contains whitespace' do
     DataMapper::Ext.blank?(' ').should == true
     DataMapper::Ext.blank?(" \r \n \t ").should == true
  end

  it 'should not be blank if it contains non-whitespace' do
    DataMapper::Ext.blank?(' a ').should == false
  end
end
