module DataMapper
  class TypeMap
    
    attr_accessor :parent, :chains
    
    def initialize(parent = nil, &blk)
      @parent, @chains = parent, {}
      
      blk.call(self) unless blk.nil?
    end
    
    def map(type)
      @chains[type] ||= TypeChain.new
    end
    
    def lookup(type)
      if type_mapped?(type)
        return @parent[type].merge((@chains[type].nil?) ? {} : translate(@chains[type])) if @parent.type_mapped?(type) if @parent
        return translate(@chains[type])
      end

      raise "TypeMap Exception: type #{type} must have a default primitive or type map entry" unless type.respond_to?(:primitive) && !type.primitive.nil? 

      lookup(type.primitive).merge(Type::PROPERTY_OPTIONS.inject({}) {|h, k| h[k] = type.send(k); h})
    end
    
    alias_method :[], :lookup
    
    def type_mapped?(type)
      @chains.has_key?(type) || (@parent.nil? ? false : @parent.type_mapped?(type))
    end
    
    def translate(chain)
      chain.attributes.merge((chain.primitive.nil? ? {} : {:primitive => chain.primitive})) unless chain.nil?
    end
    
    class TypeChain
      attr_accessor :primitive, :attributes
      
      def initialize
        @attributes = {}
      end
      
      def to(primitive)
        @primitive = primitive
        self
      end
      
      def with(attributes)
        @attributes = attributes
        self
      end
    end
  end
end