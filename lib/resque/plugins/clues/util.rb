require 'time'

module Resque
  module Plugins
    module Clues
      module Util
        def now
          Time.new.utc.iso8601
        end

        def time_delta_since(start)
          start.to_f - Time.now.utc.to_f
        end

        def symbolize(hash)
          # resque is not rails dependent, so avoiding dependency just for
          # symbolize_keys!
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
      end
    end
  end
end
