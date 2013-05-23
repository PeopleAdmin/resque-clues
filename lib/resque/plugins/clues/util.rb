require 'time'

module Resque
  module Plugins
    module Clues
      module Util
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
      end
    end
  end
end
