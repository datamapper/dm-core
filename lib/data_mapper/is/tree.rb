module DataMapper
	module Is
		module Tree
      def self.included(base)
        base.extend(ClassMethods)
      end

      # An extension to DataMapper to easily allow the creation of tree structures from your DataMapper Models.
      # This requires a foreign key property for your model, which by default would be called :parent_id.
      #
			#   Example:
			#
      #   class Category < DataMapper::Base
			#			property :parent_id, :integer
			#			property :name, :string
			#
      #     is_a_tree :order => "name"
      #   end
      #
      #   root
      #     +- child
      #          +- grandchild1
      #          +- grandchild2
      #
      #   root        = Category.create("name" => "root")
      #   child       = root.children.create("name" => "child")
      #   grandchild1 = child1.children.create("name" => "grandchild1")
      #   grandchild2 = child2.children.create("name" => "grandchild2")
      #
      #   root.parent   # => nil
      #   child.parent  # => root
      #   root.children # => [child]
      #   root.children.first.children.first # => grandchild1
			#   Category.first_root  # => root
			#   Category.roots       # => [root]
      #
			# The following instance methods are added:
			# * <tt>children</tt> - Returns all nodes with the current node as their parent, in the order specified by
			#   <tt>:order</tt> (<tt>[grandchild1, grandchild2]</tt> when called on <tt>child</tt>)
			# * <tt>parent</tt> - Returns the node referenced by the foreign key (<tt>:parent_id</tt> by
			#   default) (<tt>root</tt> when called on <tt>child</tt>)
      # * <tt>siblings</tt> - Returns all the children of the parent, excluding the current node
			#   (<tt>[grandchild2]</tt> when called on <tt>grandchild1</tt>)
      # * <tt>generation</tt> - Returns all the children of the parent, including the current node (<tt>
			#   [grandchild1, grandchild2]</tt> when called on <tt>grandchild1</tt>)
      # * <tt>ancestors</tt> - Returns all the ancestors of the current node (<tt>[root, child1]</tt>
			#   when called on <tt>grandchild2</tt>)
      # * <tt>root</tt> - Returns the root of the current node (<tt>root</tt> when called on <tt>grandchild2</tt>)
			#
			# Author:: Timothy Bennett (http://lanaer.com)
			module ClassMethods
        # Configuration options are:
        #
        # * <tt>foreign_key</tt> - specifies the column name to use for tracking of the tree (default: +parent_id+)
        # * <tt>order</tt> - makes it possible to sort the children according to this SQL snippet.
        # * <tt>counter_cache</tt> - keeps a count in a +children_count+ column if set to +true+ (default: +false+).
        def is_a_tree(options = {})
          configuration = { :foreign_key => "parent_id" }
          configuration.update(options) if options.is_a?(Hash)

          belongs_to :parent, :class_name => name, :foreign_key => configuration[:foreign_key], :counter_cache => configuration[:counter_cache]
          has_many :children, :class_name => name, :foreign_key => configuration[:foreign_key], :order => configuration[:order]

					include DataMapper::Is::Tree::InstanceMethods

					class_eval <<-CLASS
						def self.roots
							self.all :#{configuration[:foreign_key]} => nil, :order => #{configuration[:order].inspect}
						end

						def self.first_root
							self.first :#{configuration[:foreign_key]} => nil, :order => #{configuration[:order].inspect}
						end
					CLASS

					class << self
						alias_method :root, :first_root # for people used to the ActiveRecord acts_as_tree
					end
        end

				alias_method :can_has_tree, :is_a_tree # just for fun ;)
      end

      module InstanceMethods
        # Returns list of ancestors, starting with the root.
        #
        #   grandchild1.ancestors # => [root, child]
        def ancestors
          node, nodes = self, []
          nodes << node = node.parent while node.parent
          nodes.reverse
        end

        # Returns the root node of the current node’s tree.
				#
				#		grandchild1.root # => root
        def root
          node = self
          node = node.parent while node.parent
          node
        end

        # Returns all siblings of the current node.
        #
        #   grandchild1.siblings # => [grandchild2]
        def siblings
          generation - [self]
        end

        # Returns all children of the current node’s parent.
        #
        #   grandchild1.generation # => [grandchild1, grandchild2]
        def generation
          parent ? parent.children : self.class.roots
        end

				alias_method :self_and_siblings, :generation # for those used to the ActiveRecord acts_as_tree
      end
		end
	end
end
