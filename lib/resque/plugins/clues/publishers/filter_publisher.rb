
module Resque
  module Plugins
    module Clues
      # Event publisher that monitors events and indexes them for data mining.
      class FilterPublisher

        attr_reader events

        # Initializer for the IndexerPublisher class
        # [Parameters]
        #  * options = Hash containing containing optional configuration parameters. See parameters below
        def initialize(options={})


        end

        # Publishes an event to the log.
        def publish(event_type, timestamp, queue, metadata, klass, *args)
          event = event_hash(event_type, timestamp, queue, metadata, klass, args)


          @events.push(event)


        end


        private
          def event_hash(event_type, timestamp, queue, metadata, klass, *args)
            current_event = {:event_type => event_type,
                             :timestamp => timestamp,
                             :queue => queue,
                             :metadata => metadata,
                             :klass => klass,
                             :args => args
                             }
          end




      end
    end
  end
end
