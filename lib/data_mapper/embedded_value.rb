module DataMapper
  
# == EmbeddedValue
# As an alternative to an extraneous has_one association, EmbeddedValue offers a means 
# to serialize component objects to a table without having to define an entirely new model.
#
# Example:
#
#   class Person < DataMapper::Base 
#     
#     property :name, :string
#     property :occupation, :string
#     
#     embed :address, :prefix => true do
#       property :street, :string
#       property :city, :string
#       property :state, :string, :size => 2
#       property :zip_code, :string, :size => 10
#       
#       def city_state_zip_code
#         "#{city}, #{state} #{zip_code}"
#       end
#       
#     end 
#   end
#
# Columns for the Address model will appear in the Person table.  Passing 
# <tt>:prefix => true</tt> will prefix the column name with the parent table's name.
# The default behavior is to use the columns as they are defined.  Using the above
# example, the database table structure will become:
#
#   Column                      Datatype, Options
#   ===============================================================
#   name                         :string
#   occupation                   :string
#   address_street               :string
#   address_city                 :string
#   address_state                :string, :size => 2
#   address_zip_code             :string, :size => 10
#
# EmbeddedValue's become instance methods off of an instance of the parent 
# class and return a sub-class of the parent class.
#
#   bob = Person.first(:name => 'Bob')
#   bob.address                         # => #<Person::Address:0x1a492b8>
#   bob.address.city                    # => "Pittsburgh"
#   bob.address.city_state_zip_code     # => "Pitsburgh, PA 90210"
  
  class EmbeddedValue
    EMBEDDED_PROPERTIES = []
    
    def initialize(instance)
      @instance = instance
      @container_prefix = ''
    end

    def self.inherited(base)
      base.const_set('EMBEDDED_PROPERTIES', [])
    end
    
    # add an embedded property.  For more information about how to define properties, visit Property.
    def self.property(name, type, options = {})
      # set lazy option on the mapping if defined in the embed block
      options[:lazy] ||= @container_lazy
      
      options[:reader] ||= options[:accessor] || @container_reader_visibility
      options[:writer] ||= options[:accessor] || @container_writer_visibility
      
      property_name = @container_prefix ? @container_prefix + name.to_s : name
      
      property = containing_class.property(property_name, type, options)
      define_property_getter(name, property)
      define_property_setter(name, property)
    end
    
    # define embedded property getters
    def self.define_property_getter(name, property) # :nodoc:

      # add the method on the embedded class
      class_eval <<-EOS
        #{property.reader_visibility.to_s}
        def #{name}
          #{"@instance.lazy_load!("+ property.name.inspect + ")" if property.lazy?}
          @instance.instance_variable_get(#{property.instance_variable_name.inspect})
        end
      EOS

      # add a shortcut boolean? method if applicable (ex: activated?)
      if property.type == :boolean
        class_eval("alias #{property.name}? #{property.name}")
      end
    end
    
    # define embedded property setters
    def self.define_property_setter(name, property)  # :nodoc:

      # add the method on the embedded class
      class_eval <<-EOS
        #{property.writer_visibility.to_s}
        def #{name.to_s.sub(/\?$/, '')}=(value)
          @instance.instance_variable_set(#{property.instance_variable_name.inspect}, value)
        end
      EOS
    end
    
    # returns the class in which the EmbeddedValue is declared
    def self.containing_class
      @containing_class || @containing_class = begin
        tree = name.split('::')
        tree.pop
        tree.inject(Object) { |klass, current| klass.const_get(current) }
      end
    end
    
    def self.define(container, name, options, &block)
      embedded_class, embedded_class_name, accessor_name = nil

      accessor_name = name.to_s
      embedded_class_name = Inflector.camelize(accessor_name)
      embedded_class = Class.new(EmbeddedValue)
      container.const_set(embedded_class_name, embedded_class) unless container.const_defined?(embedded_class_name)

      if options[:prefix]
        container_prefix = options[:prefix].kind_of?(String) ? options[:prefix] : "#{accessor_name}_"
        embedded_class.instance_variable_set('@container_prefix', container_prefix)
      end

      embedded_class.instance_variable_set('@containing_class', container)

      embedded_class.instance_variable_set('@container_lazy', !!options[:lazy])
      embedded_class.instance_variable_set('@container_reader_visibility', options[:reader] || options[:accessor] || :public)
      embedded_class.instance_variable_set('@container_writer_visibility', options[:writer] || options[:accessor] || :public)

      embedded_class.class_eval(&block) if block_given?

      container.class_eval <<-EOS
        def #{accessor_name}
          #{embedded_class_name}.new(self)
        end
      EOS
    end
    
  end
  
end # module DataMapper
