require "dm-core/support/deprecate"

module DataMapper
  module Resource
    extend Deprecate

    deprecate :persisted_state,   :persistence_state
    deprecate :persisted_state=,  :persistence_state=
    deprecate :persisted_state?,  :persistence_state?

  end # module Resource

end # module DataMapper
