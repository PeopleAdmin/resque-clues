require 'time'

module Resque
  module Plugins
    module Clues
      # A unique event hash crafted from the hostname, process and time.
      def self.event_hash
        Digest::MD5.hexdigest("#{hostname}#{process}#{Time.now.utc.to_f}")
      end

      # The hostname Resque is running on.
      def self.hostname
        `hostname`.chop
      end

      # The process id.
      def self.process
        $$
      end

      # The current UTC time in iso 8601 format.
      def self.now
        Time.now.utc.iso8601
      end

      # The delta of time between the passed time and now.
      def self.time_delta_since(start)
        result = Time.now.utc.to_f - start.to_f
        result >= 0.0 ? result : 0.0
      end

      # Convenience method to determine if resque-clues is properly
      # configured.
      def self.clues_configured?
        Resque::Plugins::Clues.configured?
      end

      # Convenience method to access the resque-clues event publisher.
      def self.event_publisher
        Resque::Plugins::Clues.event_publisher
      end

      # Recursively symbolizes all keys of the passed hash.  Is an
      # equivalent to active_support's symbolize_keys, but I did not
      # want to introduce the depencency just for this method.
      def self.symbolize(hash)
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
      def self.prepare(hash)
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
