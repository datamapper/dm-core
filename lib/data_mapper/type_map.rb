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
        lookup_from_map(type)
      else
        lookup_by_type(type)
      end
    end

    def lookup_from_map(type)
      lookup_from_parent(type).merge(map(type).translate)
    end

    def lookup_from_parent(type)
      if !@parent.nil? && @parent.type_mapped?(type)
        @parent[type]
      else
        {}
      end
    end

    def lookup_by_type(type)
      raise "TypeMap Exception: type #{type} must have a default primitive or type map entry" unless type.respond_to?(:primitive) && !type.primitive.nil?

      lookup(type.primitive).merge(Type::PROPERTY_OPTIONS.inject({}) {|h, k| h[k] = type.send(k); h})
    end

    alias [] lookup

    def type_mapped?(type)
      @chains.has_key?(type) || (@parent.nil? ? false : @parent.type_mapped?(type))
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
        raise "method 'with' expects a hash" unless Hash === attributes
        @attributes.merge!(attributes)
        self
      end

      def translate
        @attributes.merge((@primitive.nil? ? {} : {:primitive => @primitive}))
      end
    end
  end
end
