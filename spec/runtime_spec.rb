require 'spec_helper'

module Resque
  module Plugins
    module Clues
      describe Runtime do
        before {Runtime.clear!}
        let(:clues_metadata) { {'a' => 1} }

        describe "class instance methods" do
          before { Runtime.clues_metadata = clues_metadata }

          describe "#clues_metadata= and #clues_metadata" do
            it "should allow setting and getting a clues metadata hash" do
              expect(Runtime.clues_metadata).to eq(clues_metadata)
            end

            it "should constrain visibility to the executing thread" do
              thread = Thread.new {Runtime.clues_metadata = {'b' => 2}}
              expect(Runtime.clues_metadata).to eq(clues_metadata)
            end

            it "should dupe the metadata so that its not directly modifiable" do
              Runtime.clues_metadata['b'] = 2
              expect(clues_metadata).to eq(clues_metadata)
            end
          end

          describe "#merge!" do
            it "should merge added data back into the original hash" do
              Runtime.clues_metadata['b'] = 2
              Runtime.merge!(clues_metadata)
              expect(clues_metadata).to eq({'a' => 1, 'b' => 2})
            end

            it "should not overwrite existing values" do
              Runtime.clues_metadata['a'] = 2
              Runtime.merge!(clues_metadata)
              expect(clues_metadata).to eq({'a' => 1})
            end

            it "should convert symbol keys to strings to preserve payload integrity" do
              Runtime.clues_metadata[:b] = 2
              Runtime.merge!(clues_metadata)
              expect(clues_metadata).to eq({'a' => 1, 'b' => 2})
            end
          end
        end

        describe "mixin methods" do
          subject {Object.new.extend(Runtime)}

          describe "#clues_metadata" do
            it "should allow access to the clues metadata once a runtime context is established" do
              Runtime.clues_metadata = clues_metadata
              expect(subject.clues_metadata).to eq(clues_metadata)
            end
          end
        end
      end
    end
  end
end
