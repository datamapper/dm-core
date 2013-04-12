Maintained by the RightScale "Blue_team"

Why DataMapper?
===============

Open Development
----------------

DataMapper sports a very accessible code-base and a welcoming community.
Outside contributions and feedback are welcome and encouraged, especially
constructive criticism. Make your voice heard! [Submit an issue](https://github.com/datamapper/dm-core/issues),
speak up on our [mailing-list](http://groups.google.com/group/datamapper/),
chat with us on [irc](irc://irc.freenode.net/#datamapper), write a spec, get it
reviewed, ask for commit rights. It's as easy as that to become a contributor.

Identity Map
------------

One row in the data-store should equal one object reference. Pretty simple idea.
Pretty profound impact. If you run the following code in ActiveRecord you'll
see all `false` results. Do the same in DataMapper and it's
`true` all the way down.

``` ruby
  repository do
    @parent = Tree.first(:name => 'bob')

    @parent.children.each do |child|
      puts @parent.equal?(child.parent)  # => true
    end
  end
```

This makes DataMapper faster and allocate less resources to get things done.

Dirty Tracking
--------------

When you save a model back to your data-store, DataMapper will only write
the fields that actually changed. So it plays well with others. You can
use it in an Integration data-store without worrying that your application will
be a bad actor causing trouble for all of your other processes.

Eager Loading
-------------

Ready for something amazing? The following example executes only two queries
regardless of how many rows the inner and outer queries return.

``` ruby
  repository do
    Zoo.all.each { |zoo| zoo.exhibits.to_a }
  end
```

Pretty impressive huh? The idea is that you aren't going to load a set of
objects and use only an association in just one of them. This should hold up
pretty well against a 99% rule. When you don't want it to work like this, just
load the item you want in it's own set. So the DataMapper thinks ahead. We
like to call it "performant by default". This feature single-handedly wipes
out the "N+1 Query Problem". No need to specify an `:include` option in
your finders.

Laziness Can Be A Virtue
------------------------

Text fields are expensive in data-stores. They're generally stored in a
different place than the rest of your data. So instead of a fast sequential
read from your hard-drive, your data-store server has to hop around all over the
place to get what it needs. Since ActiveRecord returns everything by default,
adding a text field to a table slows everything down drastically, across the
board.

Not so with the DataMapper. Text fields are lazily loaded, meaning they
only load when you need them. If you want more control you can enable or
disable this feature for any field (not just text-fields) by passing a
`:lazy` option to your field mapping with a value of `true` or
`false`.

``` ruby
  class Animal
    include DataMapper::Resource

    property :name,        String
    property :description, Text, :lazy => false
  end
```

Plus, lazy-loading of Text fields happens automatically and intelligently when
working with associations.  The following only issues 2 queries to load up all
of the notes fields on each animal:

``` ruby
  repository do
    Animal.all.each { |animal| animal.description.to_a }
  end
```

Did you notice the `#to_a` call in the above example?  That
was necessary because even DataMapper collections are lazy.  If you don't
iterate over them, or in this case ask them to become Arrays, they won't
execute until you need them.  We needed to call `#to_a` to force
the lazy load because without it, the above example would have only
executed one query.  This extra bit of laziness can come in very handy,
for example:

``` ruby
  animals     = Animal.all
  description = 'foo'

  animals.each do |animal|
    animal.update(:description => description)
  end
```

In the above example, the Animals won't be retrieved until you actually
need them.  This comes in handy in cases where you initialize the
collection before you know if you need it, like in a web app controller.

Collection Chaining
-------------------

DataMapper's lazy collections are also handy because you can get the
same effect as named scopes, without any special syntax, eg:

``` ruby
  class Animal
    # ... setup ...

    def self.mammals
      all(:mammal => true)
    end

    def self.zoo(zoo)
      all(:zoo => zoo)
    end
  end

  zoo = Zoo.first(:name => 'Greater Vancouver Zoo')

  Animal.mammals.zoo(zoo).to_a  # => executes one query
```

In the above example, we ask the Animal model for all the mammals,
and then all the animals in a specific zoo, and DataMapper will chain
the collection queries together and execute a single query to retrieve
the matching records.  There's no special syntax, and no custom DSLs
to learn, it's just plain ruby all the way down.

You can even use this on association collections, eg:

``` ruby
  zoo.animals.mammals.to_a  # => executes one query
```

Custom Properties
-----------------

With DataMapper it is possible to create custom properties for your models.
Consider this example:

``` ruby
  module DataMapper
    class Property
      class Email < String
        required true
        format   /^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i
      end
    end
  end

  class User
    include DataMapper::Resource

    property :id,    Serial
    property :email, Email
  end
```

This way there won't be a need to repeat same property options every time you
add an email to a model. In the example above we create an Email property which
is just a String with additional pre-configured options: `required` and
`format`. Please note that it is possible to override these options when
declaring a property, like this:

``` ruby
  class Member
    include DataMapper::Resource

    property :id,    Serial
    property :email, Email, :required => false
  end
```

Plays Well With Others
----------------------

In ActiveRecord, all your fields are mapped, whether you want them or not.
This slows things down. In the DataMapper you define your mappings in your
model. So instead of an _ALTER TABLE ADD field_ in your data-store, you simply
add a `property :name, String` to your model. DRY. No schema.rb. No
migration files to conflict or die without reverting changes. Your model
drives the data-store, not the other way around.

Unless of course you want to map to a legacy data-store. Raise your hand if you
like seeing a method called `col2Name` on your model just because
that's what it's called in an old data-store you can't afford to change right
now? In DataMapper you control the mappings:

``` ruby
  class Fruit
    include DataMapper::Resource

    storage_names[:repo] = 'frt'

    property :name, String, :field => 'col2Name'
  end
```

All Ruby, All The Time
----------------------

It's great that ActiveRecord allows you to write SQL when you need to, but
should we have to so often?

DataMapper supports issuing your own query, but it also provides more helpers
and a unique hash-based condition syntax to cover more of the use-cases where
issuing your own SQL would have been the only way to go. For example, any
finder option that's non-standard is considered a condition. So you can write
`Zoo.all(:name => 'Dallas')` and DataMapper will look for zoos with the
name of 'Dallas'.

It's just a little thing, but it's so much nicer than writing
`Zoo.find(:all, :conditions => ['name = ?', 'Dallas'])`. What if you
need other comparisons though? Try these:

``` ruby
  # 'gt' means greater-than. We also do 'lt'.
  Person.all(:age.gt => 30)

  # 'gte' means greather-than-or-equal-to. We also do 'lte'.
  Person.all(:age.gte => 30)

  # 'not' allows you to match all people without the name "bob"
  Person.all(:name.not => 'bob')

  # If the value of a pair is an Array, we do an IN-clause for you.
  Person.all(:name.like => 'S%', :id => [ 1, 2, 3, 4, 5 ])

  # Does a NOT IN () clause for you.
  Person.all(:name.not => [ 'bob', 'rick', 'steve' ])
```

See? Fewer SQL fragments dirtying your Ruby code. And that's just a few of the
nice syntax tweaks DataMapper delivers out of the box...

Note on Patches/Pull Requests
-----------------------------

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

Copyright
---------

Copyright (c) 2012 Dan Kubb. See LICENSE for details.
