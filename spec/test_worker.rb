class TestWorker
  @queue = :test_queue

  def self.perform(first, second)
  end
end

class InjectingWorker
  extend Resque::Plugins::Clues::Runtime
  @queue = :test_queue

  def self.perform(hash)
    hash.each do |k, v|
      clues_metadata[k] = v
    end
  end
end
