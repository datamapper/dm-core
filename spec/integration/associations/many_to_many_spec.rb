require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))
require 'pp'

describe "ManyToMany" do
  before(:all) do

    class Editor
      include DataMapper::Resource

      def self.default_repository_name; ADAPTER end

      property :id, Serial
      property :name, String

      has n, :books, :through => Resource
    end

    class Book
      include DataMapper::Resource

      def self.default_repository_name; ADAPTER end

      property :id, Serial
      property :title, String

      has n, :editors, :through => Resource
    end

    [Book, Editor, BooksEditor].each { |k| k.auto_migrate!(ADAPTER) }
    
    adapter = repository(ADAPTER).adapter
    adapter.execute("INSERT INTO books_editors (book_id, editor_id) VALUES (1, 1)")
    adapter.execute("INSERT INTO books_editors (book_id, editor_id) VALUES (2, 1)")
    adapter.execute("INSERT INTO books_editors (book_id, editor_id) VALUES (1, 2)")

    def BooksEditor.default_repository_name; ADAPTER end

    repository(ADAPTER) do
      Book.create!(:title => "Dubliners")
      Book.create!(:title => "Portrait of the Artist as a Young Man")
      Book.create!(:title => "Ulysses")
      Editor.create!(:name => "Jon Doe")
      Editor.create!(:name => "Jane Doe")
    end

  end

  it "should correctly link records" do
    Editor.get(1).books.size.should == 2
    Editor.get(2).books.size.should == 1
    Book.get(1).editors.size.should == 2
    Book.get(2).editors.size.should == 1
  end

  it "should be able to have associated objects manually added" do
    book = Book.get(3)
    # book.editors.size.should == 0

    be = BooksEditor.new(:book_id => book.id, :editor_id => 2)
    book.books_editors << be
    book.save

    book.reload
    book.editors.size.should == 1
  end

  it "should automatically added necessary through class" do
    book = Book.get(3)
    book.editors << Editor.get(1)
    book.editors << Editor.new(:name => "Jimmy John")
    book.save
    book.editors.size.should == 3
  end

  it "should react correctly to a new record" do
    book = Book.new(:title => "Finnegan's Wake")
    book.editors << Editor.get(2)
    book.save
    book.editors.size.should == 1
    Editor.get(2).books.size.should == 3
  end
  
  it "should be able to delete intermediate model" do
    book = Book.get(3)
    be = BooksEditor.get(3,1)
    book.books_editors.delete(be)
    book.save
    book.reload
    book = Book.get(3)
    book.books_editors.size.should == 2
    book.editors.size.should == 2
  end

  it "should be clearable" do
    repository(ADAPTER) do
      book = Book.get(2)
      book.editors.size.should == 1
      book.editors.clear
      book.save
      book.reload
      book.books_editors.size.should == 0
      book.editors.size.should == 0
    end
    repository(ADAPTER) do
      Book.get(2).editors.size.should == 0
    end
  end

  it "should be able to delete one object" do
    book = Book.get(1)
    editor = book.editors.first

    book.editors.size.should == 2
    book.editors.delete(editor)
    book.books_editors.size.should == 1
    book.editors.size.should == 1
    book.save
    book.reload
    Editor.get(1).books.should_not include(book)
  end
  
  it "should be destroyable" do
    book = Book.get(3)
    book.editors.destroy
    book.save
    book.reload
    book.editors.size.should == 0
  end
end
