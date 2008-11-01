require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe "Resource" do
  before(:each) do
  end

  describe "#field" do
    it "supplies the field in the data-store which the property corresponds to"
  end

  describe "#unique" do
    it "is true for fields that explicitly given uniq index"

    it "is true for serial fields"

    it "is true for keys"
  end

  describe "#hash" do

  end

  describe "#equal?" do

  end

  describe "#length" do

  end

  describe "#index" do

  end

  describe "#unique_index" do

  end

  describe "#lazy?" do

  end

  describe "#key?" do

  end

  describe "#serial?" do

  end

  describe "#nullable?" do

  end

  describe "#custom?" do
    it "is true for custom fields (not provided by dm-core)"
  end
end
