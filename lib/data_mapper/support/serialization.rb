require 'rexml/document'

begin
  require 'faster_csv'
rescue LoadError
  nil
end

begin
  require 'json/ext'
rescue LoadError
  require 'json/pure'
end

module DataMapper
  module Support
    module Serialization
      
      def to_yaml(opts = {})
        
        YAML::quick_emit( object_id, opts ) do |out|
          out.map(nil, to_yaml_style ) do |map|
            database_context.table(self).columns.each do |column|
              lazy_load!(column.name) if column.lazy?
              value = get_value_for_column(column)
              map.add(column.to_s, value.is_a?(Class) ? value.to_s : value)
            end
            (self.instance_variable_get("@yaml_added") || []).each do |k,v|
              map.add(k.to_s, v)
            end
          end
        end
        
      end
      
      def to_xml
        to_xml_document.to_s
      end
      
      def xml_element_name ## overloadable
        Inflector.underscore(self.class.name)
      end
      
      def to_xml_document
        doc = REXML::Document.new
        
        table = database_context.table(self.class)
        # root = doc.add_element(Inflector.underscore(self.class.name))
        root = doc.add_element(xml_element_name)
        
        key_attribute = root.attributes << REXML::Attribute.new(table.key.to_s, key)
        
        # Single-quoted attributes are ugly. :p
        # NOTE: I don't want to break existing REXML specs for everyone, so I'm
        # overwriting REXML::Attribute#to_string just for this instance.
        def key_attribute.to_string
          %Q[#@expanded_name="#{to_s().gsub(/"/, '&quot;')}"] 
        end
        
        table.columns.each do |column|
          next if column.key?
          value = get_value_for_column(column)
          node = root.add_element(column.to_s)
          node << REXML::Text.new(value.to_s) unless value.nil?
        end
        
        doc
      end
      
      def to_json(*a)
        table = database_context.table(self.class)
        
        result = '{ '
        
        result << table.columns.map do |column|
          "#{column.name.to_json}: #{get_value_for_column(column).to_json(*a)}"
        end.join(', ')
        
        result << ' }'
        result
      end
      
      def to_csv(writer = "")
        FasterCSV.generate(writer) do |csv|
          csv << database_context.table(self.class).columns.map { |column| get_value_for_column(column) }
        end
        return writer
      end
      
      def get_value_for_column(column)
        send(column.type == :boolean ? column.name.to_s.ensure_ends_with('?') : column.name)
      end

    end
  end # module Support
end # module DataMapper