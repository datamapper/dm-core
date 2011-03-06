module DataMapper; module Ext
  module Object
    # Returns the value of the specified constant.
    #
    # @overload full_const_get(obj, name)
    #   Returns the value of the specified constant in +obj+.
    #   @param [Object] obj The root object used as origin.
    #   @param [String] name The name of the constant to get, e.g. "Merb::Router".
    #
    # @overload full_const_get(name)
    #   Returns the value of the fully-qualified constant.
    #   @param [String] name The name of the constant to get, e.g. "Merb::Router".
    #
    # @return [Object] The constant corresponding to +name+.
    #
    # @api semipublic
    def self.full_const_get(obj, name = nil)
      obj, name = ::Object, obj if name.nil?

      list = name.split("::")
      list.shift if DataMapper::Ext.blank?(list.first)
      list.each do |x|
        # This is required because const_get tries to look for constants in the
        # ancestor chain, but we only want constants that are HERE
        obj = obj.const_defined?(x) ? obj.const_get(x) : obj.const_missing(x)
      end
      obj
    end

    # Sets the specified constant to the given +value+.
    #
    # @overload full_const_set(obj, name)
    #   Sets the specified constant in +obj+ to the given +value+.
    #   @param [Object] obj The root object used as origin.
    #   @param [String] name The name of the constant to set, e.g. "Merb::Router".
    #   @param [Object] value The value to assign to the constant.
    #
    # @overload full_const_set(name)
    #   Sets the fully-qualified constant to the given +value+.
    #   @param [String] name The name of the constant to set, e.g. "Merb::Router".
    #   @param [Object] value The value to assign to the constant.
    #
    # @return [Object] The constant corresponding to +name+.
    #
    # @api semipublic
    def self.full_const_set(obj, name, value = nil)
      obj, name, value = ::Object, obj, name if value.nil?

      list = name.split("::")
      toplevel = DataMapper::Ext.blank?(list.first)
      list.shift if toplevel
      last = list.pop
      obj = list.empty? ? ::Object : DataMapper::Ext::Object.full_const_get(list.join("::"))
      obj.const_set(last, value) if obj && !obj.const_defined?(last)
    end
  end
end; end
