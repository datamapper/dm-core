require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe DataMapper::Associations::ManyToMany::Proxy do
  before :all do
    class Editor
      include DataMapper::Resource

      def self.default_repository_name; ADAPTER end

      property :id, Serial
      property :name, String

      has n, :books, :through => Resource
    end

    Object.send(:remove_const, :Book) if defined?(Book)

    class Book
      include DataMapper::Resource

      def self.default_repository_name; ADAPTER end

      property :id, Serial
      property :title, String

      has n, :editors, :through => Resource
    end

    [ Book, Editor, BookEditor ].each { |k| k.auto_migrate! }

    repository(ADAPTER) do
      book_1 = Book.create(:title => "Dubliners")
      book_2 = Book.create(:title => "Portrait of the Artist as a Young Man")
      book_3 = Book.create(:title => "Ulysses")

      editor_1 = Editor.create(:name => "Jon Doe")
      editor_2 = Editor.create(:name => "Jane Doe")

      BookEditor.create(:book => book_1, :editor => editor_1)
      BookEditor.create(:book => book_2, :editor => editor_1)
      BookEditor.create(:book => book_1, :editor => editor_2)
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

    be = BookEditor.new(:book_id => book.id, :editor_id => 2)
    book.book_editors << be
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
    be = BookEditor.get(3,1)
    book.book_editors.delete(be)
    book.save
    book.reload
    book = Book.get(3)
    book.book_editors.size.should == 2
    book.editors.size.should == 2
  end

  it "should be clearable" do
    repository(ADAPTER) do
      book = Book.get(2)
      book.editors.size.should == 1
      book.editors.clear
      book.save
      book.reload
      book.book_editors.size.should == 0
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
    book.book_editors.size.should == 1
    book.editors.size.should == 1
    book.save
    book.reload
    Editor.get(1).books.should_not include(book)
  end

  it "should be destroyable" do
    pending 'cannot destroy a collection yet' do
      book = Book.get(3)
      book.editors.destroy
      book.save
      book.reload
      book.editors.size.should == 0
    end
  end

  describe 'with natural keys' do
    before :all do
      class Author
        include DataMapper::Resource

        def self.default_repository_name; ADAPTER end

        property :name, String, :key => true

        has n, :books, :through => Resource
      end

      class Book
        has n, :authors, :through => Resource
      end

      [ Author, AuthorBook ].each { |k| k.auto_migrate! }

      @author = Author.create(:name =>  'James Joyce')

      @book_1 = Book.get!(1)
      @book_2 = Book.get!(2)
      @book_3 = Book.get!(3)

      AuthorBook.create(:book => @book_1, :author => @author)
      AuthorBook.create(:book => @book_2, :author => @author)
      AuthorBook.create(:book => @book_3, :author => @author)
    end

    it 'should have a join resource where the natural key is a property' do
      AuthorBook.properties[:author_name].primitive.should == String
    end

    it 'should have a join resource where every property is part of the key' do
      AuthorBook.key.should == AuthorBook.properties.to_a
    end

    it 'should correctly link records' do
      @author.books.should have(3).entries
      @book_1.authors.should have(1).entries
      @book_2.authors.should have(1).entries
      @book_3.authors.should have(1).entries
    end
  end
end
