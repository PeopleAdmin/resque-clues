require 'resque'
require 'resque/plugins/clues/event_hashable'
require 'resque/plugins/clues/util'
require 'resque/plugins/clues/decorator'
require 'resque/plugins/clues/event_publisher'
require 'resque/plugins/clues/version'

module Resque
  def self.clues_configured?
    !self.event_publisher.nil?
  end
end

Resque.send(:alias_method, :_base_push, :push)
Resque.send(:alias_method, :_base_pop, :pop)
Resque.send(:extend, Resque::Plugins::Clues::QueueDecorator)
Resque::Job.send(:alias_method, :_base_perform, :perform)
Resque::Job.send(:include, Resque::Plugins::Clues::JobDecorator)
