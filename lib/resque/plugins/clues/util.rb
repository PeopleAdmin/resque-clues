require 'time'
require 'delegate'

module Resque
  module Plugins
    module Clues
      # Hash wrapper class that treats strings and symbols equivalently.
      class LooseHash < SimpleDelegator
        def initialize(item)
          super(item)
        end
        
        def [](key)
          result = __getobj__[key]
          unless result
            other_key = key.is_a?(String) ? key.to_sym : key.to_s
            result = __getobj__[other_key]
          end
          result
        end
      end

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

      # Prepares a hash by injecting the hostname
      # and process into its metadata (if present)
      def self.prepare(hash)
        LooseHash.new(hash).tap do |hash|
          if hash['clues_metadata']
            hash['clues_metadata']['hostname'] = hostname
            hash['clues_metadata']['process'] = process
            yield(hash) if block_given?
          end
        end
      end
    end
  end
end
