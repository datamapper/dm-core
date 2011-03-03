module DataMapper; module Ext
  module Object
    # @param name<String> The name of the constant to get, e.g. "Merb::Router".
    #
    # @return [Object] The constant corresponding to the name.
    def self.full_const_get(obj, name = nil)
      obj, name = ::Object, obj if name.nil?

      list = name.split("::")
      list.shift if list.first.blank?
      list.each do |x|
        # This is required because const_get tries to look for constants in the
        # ancestor chain, but we only want constants that are HERE
        obj = obj.const_defined?(x) ? obj.const_get(x) : obj.const_missing(x)
      end
      obj
    end

    # @param name<String> The name of the constant to get, e.g. "Merb::Router".
    # @param value<Object> The value to assign to the constant.
    #
    # @return [Object] The constant corresponding to the name.
    def self.full_const_set(obj, name, value = nil)
      obj, name, value = ::Object, obj, name if value.nil?

      list = name.split("::")
      toplevel = list.first.blank?
      list.shift if toplevel
      last = list.pop
      obj = list.empty? ? ::Object : DataMapper::Ext::Object.full_const_get(list.join("::"))
      obj.const_set(last, value) if obj && !obj.const_defined?(last)
    end
  end
end; end
