require 'time'
require 'delegate'

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
    end
  end
end
