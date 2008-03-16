require 'bigdecimal' 
require 'bigdecimal/util'

module DataMapper
  module Adapters
    module Sql
      # Coersion is a mixin that allows for coercing database values to Ruby Types.
      #
      # DESIGN: Probably should handle the opposite scenario here too. I believe that's
      # currently in DataMapper::Repository, which is obviously not a very good spot for
      # it.
      module Coersion
        
        class CoersionError < StandardError
        end
        
        TRUE_ALIASES = ['true'.freeze, 'TRUE'.freeze, '1'.freeze, 1]
        FALSE_ALIASES = [nil, '0'.freeze, 0]
        
        def self.included(base)
          base.const_set('TRUE_ALIASES', TRUE_ALIASES.dup)
          base.const_set('FALSE_ALIASES', FALSE_ALIASES.dup)
        end
        
        def type_cast_boolean(raw_value)
          return nil if raw_value.nil? || (raw_value.respond_to?(:empty?) && raw_value.empty?)
          case raw_value
            when TrueClass, FalseClass then raw_value
            when *self::class::TRUE_ALIASES then true
            when *self::class::FALSE_ALIASES then false
            else raise CoersionError.new("Can't type-cast #{raw_value.inspect} to a boolean")
          end
        end
        
        def type_cast_string(raw_value)
          return nil if raw_value.blank?
          # type-cast values should be immutable for memory conservation
          raw_value
        end
        
        def type_cast_text(raw_value)
          return nil if raw_value.blank?
          # type-cast values should be immutable for memory conservation
          raw_value
        end
        
        def type_cast_class(raw_value)
          return nil if raw_value.blank?
          Object::recursive_const_get(raw_value)
        end
        
        def type_cast_integer(raw_value)
          return nil if raw_value.blank?
          raw_value.to_i
        rescue ArgumentError
          nil
        end
        
        def type_cast_decimal(raw_value)
          return nil if raw_value.blank?
          raw_value.to_d
        rescue ArgumentError 
          nil 
        end
                
        def type_cast_float(raw_value)
          return nil if raw_value.blank?
          case raw_value
            when Float then raw_value
            when Numeric, String then raw_value.to_f
            else CoersionError.new("Can't type-cast #{raw_value.inspect} to a float")
          end
        end
        
        def type_cast_datetime(raw_value)
          return nil if raw_value.blank?
          
          case raw_value
            when "0000-00-00 00:00:00" then nil
            when DateTime then raw_value
            when Date then DateTime.new(raw_value) rescue nil
            when String then DateTime::parse(raw_value) rescue nil
            else raise CoersionError.new("Can't type-cast #{raw_value.inspect} to a datetime")
          end
        end
        
        def type_cast_date(raw_value)
          return nil if raw_value.blank?
          
          case raw_value
            when Date then raw_value
            when DateTime, Time then Date::civil(raw_value.year, raw_value.month, raw_value.day)
            when String then Date::parse(raw_value)
            else raise CoersionError.new("Can't type-cast #{raw_value.inspect} to a date")
          end
        end
        
        def type_cast_object(raw_value)
          return nil if raw_value.blank?

          begin
            YAML.load(raw_value)
          rescue
            raise CoersionError.new("Can't type-cast #{raw_value.inspect} to an object")
          end
        end
        
        def type_cast_value(type, raw_value)
          return nil if raw_value.blank?
          
          case type
          when :string then type_cast_string(raw_value)
          when :text then type_cast_text(raw_value)
          when :boolean then type_cast_boolean(raw_value)
          when :class then type_cast_class(raw_value)
          when :integer then type_cast_integer(raw_value)
          when :decimal then type_cast_decimal(raw_value)
          when :float then type_cast_float(raw_value)
          when :datetime then type_cast_datetime(raw_value)
          when :date then type_cast_date(raw_value)
          when :object then type_cast_object(raw_value)
          else
            if respond_to?("type_cast_#{type}")
              send("type_cast_#{type}", raw_value)
            else
              raise "Don't know how to type-cast #{{ type => raw_value }.inspect }"
            end
          end
        end

      end # module Coersion
    end
  end  
end
