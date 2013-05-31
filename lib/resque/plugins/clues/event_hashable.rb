module Resque
  module Plugins
    module Clues
      # Module that may be mixed in to allow the generation of event
      # hashes -- unique values for a combination of host, process and
      # time.
      module EventHashable
        # Returns an MD5 hash based on the host, process and time.
        def event_hash
          Digest::MD5.hexdigest("#{hostname}#{process}#{time}")
        end

        private
        def hostname
          `hostname`.chop
        end

        def process
          $$
        end

        def time
          Time.new.utc.to_f
        end
      end
    end
  end
end
