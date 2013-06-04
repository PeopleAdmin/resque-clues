require 'time'

module Resque
  module Plugins
    module Clues
      # Module to be mixed in that provides cross-cutting operations to
      # be used by multiple classes.
      module Util
        # A unique event hash crafted from the hostname, process and time.
        def event_hash
          Digest::MD5.hexdigest("#{hostname}#{process}#{Time.new.utc.to_f}")
        end

        # The hostname Resque is running on.
        def hostname
          `hostname`.chop
        end

        # The process id.
        def process
          $$
        end

        # The current UTC time in iso 8601 format.
        def now
          Time.new.utc.iso8601
        end

        # The delta of time between the passed time and now.
        def time_delta_since(start)
          result = Time.now.utc.to_f - start.to_f
          result >= 0.0 ? result : 0.0
        end

        # Convenience method to determine if resque-clues is properly
        # configured.
        def clues_configured?
          Resque::Plugins::Clues.configured?
        end

        # Convenience method to access the resque-clues event publisher.
        def event_publisher
          Resque::Plugins::Clues.event_publisher
        end

        # Recursively symbolizes all keys of the passed hash.  Is an
        # equivalent to active_support's symbolize_keys, but I did not
        # want to introduce the depencency just for this method.
        def symbolize(hash)
          hash.inject({}) do |memo, kv|
            memo.tap do
              if kv[1].instance_of? Hash
                memo[kv[0].to_sym] = symbolize(kv[1])
              else
                memo[kv[0].to_sym] = kv[1]
              end
            end
          end
        end

        # Prepares a hash by symbolizing its keys and injecting the hostname
        # and process into its metadata (if present)
        def prepare(hash)
          symbolize(hash).tap do |hash|
            if hash[:metadata]
              hash[:metadata][:hostname] = hostname
              hash[:metadata][:process] = process
              yield(hash) if block_given?
            end
          end
        end
      end
    end
  end
end
