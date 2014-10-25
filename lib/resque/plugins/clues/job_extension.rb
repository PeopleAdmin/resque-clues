require 'digest/md5'
require 'time'

module Resque
  module Plugins
    module Clues
      # Module capable of redefining the Job#perform and Job#failed methods so
      # that they publish perform_started, perform_finished and failed events.
      module JobExtension
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
          klass.send(:define_method, :_clues_perform) do
            if Clues.configured? and payload['clues_metadata']
              Clues.event_publisher.publish(:perform_started, Clues.now, queue, payload['clues_metadata'], payload['class'], *payload['args'])
              @perform_started = Time.now
              Clues::Runtime.clues_metadata = payload['clues_metadata']
              _base_perform.tap do
                payload['clues_metadata']['_time_to_perform'] =
                  payload['clues_metadata']['time_to_perform'] =
                    Clues.time_delta_since(@perform_started)
                Clues::Runtime.merge!(payload['clues_metadata'])
                Clues.event_publisher.publish(:perform_finished, Clues.now, queue, payload['clues_metadata'], payload['class'], *payload['args'])
              end
            else
              _base_perform
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
          klass.send(:define_method, :_clues_fail) do |exception|
            _base_fail(exception).tap do
              metadata = payload['clues_metadata']
              if Clues.configured? and metadata
                metadata['_time_to_perform'] =
                  metadata['time_to_perform'] =
                    Clues.time_delta_since(@perform_started)
                metadata['_exception'] =
                  metadata['exception'] =
                    exception.class.name
                metadata['_message'] =
                  metadata['message'] =
                    exception.message
                metadata['_backtrace'] =
                  metadata['backtrace'] =
                    exception.backtrace
                Clues::Runtime.merge!(metadata)
                Clues.event_publisher.publish(:failed, Clues.now, queue, metadata, payload['class'], *payload['args'])
              end
            end
          end
        end
      end
    end
  end
end
