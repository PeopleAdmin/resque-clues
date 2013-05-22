module Resque
  module Plugins
    module Clues
      module EventHashable
        def event_hash
          Digest::MD5.hexdigest("#{hostname}#{process}#{time}")
        end

        private
        def hostname
          # TODO this needs to be changed as it will leak file descriptors
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
