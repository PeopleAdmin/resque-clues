require 'digest/md5'
require 'time'

module Resque
  module Plugins
    module Clues
      # Module capable of redefining the Job#perform and Job#failed methods so
      # that they publish perform_started, perform_finished and failed events.
      module JobExtension
        CLUES = Resque::Plugins::Clues
        # Invoked when this module is included by a class.  Will redefine the
        # perform and failed methods on that class.
        #
        # klass:: The klass including this module.
        def self.included(klass)
          define_perform(klass)
          define_failed(klass)
        end

        private
        # (Re)defines the perform method so that it will broadcast a
        # perform_started event, invoke the original perform method, and
        # then broadcast a perform_finished event if no exceptions are
        # encountered.  The time to perform is calculated and included in
        # the metadata of the perform_finished event.
        #
        # klass:: The class to define the perform method on.
        def self.define_perform(klass) # :doc:
          klass.send(:define_method, :perform) do
            return _base_perform unless CLUES.configured?
            item = CLUES.prepare(payload)
            CLUES.event_publisher.perform_started(CLUES.now, queue, item['clues_metadata'], item['class'], *item['args'])
            @perform_started = Time.now
            _base_perform.tap do
              item['clues_metadata']['time_to_perform'] = CLUES.time_delta_since(@perform_started)
              CLUES.event_publisher.perform_finished(CLUES.now, queue, item['clues_metadata'], item['class'], *item['args'])
            end
          end
        end

        # (Re)defines the failed method so that it will add time to perform,
        # exception, error message and backtrace data to the job's payload
        # metadata, then broadcast a failed event including that information.
        #
        # klass::  The class to define the failed method on.
        #
        def self.define_failed(klass) # :doc:
          klass.send(:define_method, :fail) do |exception|
            _base_fail(exception).tap do
              if CLUES.configured?
                item = CLUES.prepare(payload)
                item['clues_metadata']['time_to_perform'] = CLUES.time_delta_since(@perform_started)
                item['clues_metadata']['exception'] = exception.class
                item['clues_metadata']['message'] = exception.message
                item['clues_metadata']['backtrace'] = exception.backtrace
                CLUES.event_publisher.failed(CLUES.now, queue, item['clues_metadata'], item['class'], *item['args'])
              end
            end
          end
        end
      end
    end
  end
end
