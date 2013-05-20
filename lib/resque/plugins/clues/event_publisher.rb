require 'pp'

module Resque
  module Plugins
    module Clues
      module EventPublisher
        EVENT_TYPES = %w[enqueued dequeued destroyed perform_started perform_finished failed]

        class StandardOut
          EVENT_TYPES.each do |event_type|
            define_method(event_type) do |queue, metadata, klass, *args|
              puts({event_type: event_type.to_s,
                    queue: queue,
                    metadata: metadata,
                    worker_class: klass,
                    args: args})
            end
          end
        end
      end
    end
  end
end
