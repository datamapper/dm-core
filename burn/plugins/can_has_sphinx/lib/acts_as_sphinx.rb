require "sphinx"

module ActsAsSphinx
  module ClassMethods
    # Associates the model class with a sphinx index, which will be used by find_with_sphinx method.
    # You can pass the following options:
    # 
    # :host   is the host name or an IP address where searchd daemon is running, default is localhost
    # :port   is the port number of the searchd process, default is 3312
    # :index  is the name of the index to be used, default is the name of the table for the current model class.
    def acts_as_sphinx(options = {})
      options.assert_valid_keys(SphinxClassMethods::VALID_OPTIONS)

      default_options = {:host => 'localhost', :port => 3312, :index => name.tableize}
      write_inheritable_attribute 'sphinx_options', options.reverse_merge(default_options)
      extend SphinxClassMethods
    end
  end
  
  def self.included(receiver)
    receiver.extend(ClassMethods)
  end
  
  module SphinxClassMethods
    VALID_OPTIONS = %w[mode offset page limit index weights host 
                       port range filter filter_range group_by sort_mode].map(&:to_sym)

    def sphinx_index
      read_inheritable_attribute('sphinx_options')[:index]
    end
    
    def sphinx_options
      read_inheritable_attribute 'sphinx_options'
    end
    
    # Performs a sphinx search and returns a hash object as defined by Sphinx#query method.
    # This methods accepts the same set of options as :sphinx option of find_with_sphinx method.
    def ask_sphinx(query, options = {})
      options.assert_valid_keys(VALID_OPTIONS)
      
      default_options = {:offset => 0, :limit => 20}
      default_options.merge! sphinx_options
      options.reverse_merge! default_options
      
      if options[:page] && options[:limit]
        options[:offset] = options[:limit] * (options[:page].to_i - 1)
        options[:offset] = 0 if options[:offset] < 0
      end
      
      sphinx = Sphinx.new
      sphinx.set_server options[:host], options[:port]
      sphinx.set_limits options[:offset], options[:limit]
      sphinx.set_weights options[:weights] if options[:weights]
      sphinx.set_id_range options[:range] if options[:range]
      
      options[:filter].each do |attr, values|
        sphinx.set_filter attr, [*values]
      end if options[:filter]
      
      options[:filter_range].each do |attr, (min, max)|
        sphinx.set_filter_range attr, min, max
      end if options[:filter_range]
      
      options[:group_by].each do |attr, func|
        funcion = Sphinx.const_get("SPH_GROUPBY_#{func.to_s.upcase}") \
          rescue raise("Unknown group by function #{func}")
        sphinx.set_group_by attr, funcion
      end if options[:group_by]
      
      if options[:mode]
        match_mode = Sphinx.const_get("SPH_MATCH_#{options[:mode].to_s.upcase}") \
          rescue raise("Unknown search mode #{options[:mode]}")
        sphinx.set_match_mode match_mode
      end
      
      if options[:sort_mode]
        sort_mode, sort_expr = options[:sort_mode]
        sort_mode = Sphinx.const_get("SPH_SORT_#{sort_mode.to_s.upcase}") \
          rescue raise("Unknown sort mode #{sort_mode}")
        sphinx.set_sort_mode sort_mode, sort_expr
      end
      
      sphinx.query query, options[:index]
    end
    
    # Find all model objects using sphinx index.
    # Besides regular ActiveRecord::Base#find method's options, you can specify
    # :sphinx key that points to a hash with the following sphinx specific parameters:
    # 
    # :mode       defines the search mode (:all, :any, :boolean, :extended)
    # :sort_mode  defines the sort mode (:relevance, :attr_desc, :attr_asc, :time_segments, :extended),
    #             for example :sort_mode => [:attr_desc, 'myattr']
    # :limit      restricts result to a specified number of objects, default is 20
    # :offset     make this method return from a specific offset, default is 0
    # :page       can be used instead of :offset option to specify the page number
    # :host       overrides the default value of this option, see acts_as_sphinx method
    # :port       overrides the default value of this option, see acts_as_sphinx method
    # :index      overrides the default index name
    # :weight     is an array of weights for each index component (used in the relevance algorithm)
    # :range      is an array that defines the range document ids to be used, e.g. :range => [min, max]
    # :fiter and :filter_range 
    #             options define a search filter by an attribute
    # :group_by   makes the search result to be grouped by an attribute, e.g. :group_by => [attr, function],
    #             where function is :day, :week, :month, :year, or :attr
    # 
    # The returned array has three special attributes:
    # 
    #   ary.total returns a total hits retrieved for this search
    #   ary.total_found returns a total number of hits found while scanning indexes.
    #   ary.time returns a time spent performing the search.
    def find_with_sphinx(query, options = {})
      result = ask_sphinx(query, options.delete(:sphinx) || {})
      records = result[:matches].empty? ? [] : find(result[:matches].keys, options)
      records = records.sort_by{|r| -result[:matches][r.id][:weight] }
      %w[total total_found time].map(&:to_sym).each do |method|
        class << records; self end.send(:define_method, method) {result[method]}
      end
      records
    end
  end
end

ActiveRecord::Base.send :include, ActsAsSphinx