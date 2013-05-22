require 'digest/md5'

module Resque
  module Plugins
    module Clues
      module QueueDecorator
        include Resque::Plugins::Clues::EventHashable

        def push(queue, item)
          item[:metadata] = {
            event_hash: event_hash
          }
          _base_push(queue, item)
        end

        def pop(queue)
          _base_pop(queue)
        end

        def self.extended(klass)
          alias_method :_base_push, :push
          alias_method :_base_pop, :pop
        end
      end
    end
  end
end
