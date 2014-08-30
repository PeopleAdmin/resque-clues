module Resque
  module Plugins
    module Clues
      ##
      # The Resque-Clues runtime environment.  Allows
      # jobs to access the clues metadata, add data to
      # it that will be broadcast with clues events,
      # etc...
      module Runtime
        class ContextNotEstablished < StandardError; end

        class << self
          ##
          # Access to the current thread's clues metadata
          # hash.
          def clues_metadata
            get_thread_local(:clues_metadata) || {}
          end

          ##
          # Specify the current thread's clues metadata
          # hash.
          def clues_metadata=(hash)
            set_thread_local(:clues_metadata, hash.dup)
          end

          ##
          # Clear the current clues runtime context
          def clear!
            delete_thread_local! :clues_metadata
          end

          ##
          # Merge any new data stored in the copy of the clues
          # metadata into an original clues_metadata hash,
          # ignoring anything that would overwrite existing
          # metadata and converting keys to strings.
          def merge!(original)
            clues_metadata.keys.each do |key|
              unless original.has_key?(key.to_s)
                original[key.to_s] = clues_metadata[key]
              end
            end
          end

          private
          def set_thread_local(name, val)
            Thread.current[name] = val
          end

          def get_thread_local(name)
            Thread.current[name]
          end

          def delete_thread_local!(name)
            Thread.current[name] = nil
          end
        end

        ##
        # Convenient access to the clues metadata hash
        # via mixin. Can be used from within a job's
        # perform method to store arbitrary data that
        # will be published with the resque clues
        # events.
        def clues_metadata
          Clues::Runtime.clues_metadata
        end
      end
    end
  end
end
