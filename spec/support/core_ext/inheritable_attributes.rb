class Class
  def class_inheritable_reader(*ivars)
    instance_reader = ivars.pop[:reader] if ivars.last.is_a?(Hash)

    ivars.each do |ivar|
      self.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{ivar}
          return @#{ivar} if defined?(@#{ivar})
          return nil      if self.object_id == #{self.object_id}
          ivar = superclass.#{ivar}
          return nil if ivar.nil?
          @#{ivar} = DataMapper::Ext.try_dup(ivar)
        end
      RUBY

      unless instance_reader == false
        self.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{ivar}
            self.class.#{ivar}
          end
        RUBY
      end
    end
  end

  def class_inheritable_writer(*ivars)
    instance_writer = ivars.pop[:instance_writer] if ivars.last.is_a?(Hash)
    ivars.each do |ivar|
      self.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{ivar}=(obj)
          @#{ivar} = obj
        end
      RUBY
      unless instance_writer == false
        self.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{ivar}=(obj) self.class.#{ivar} = obj end
        RUBY
      end
    end
  end

  def class_inheritable_accessor(*syms)
    class_inheritable_reader(*syms)
    class_inheritable_writer(*syms)
  end
end
