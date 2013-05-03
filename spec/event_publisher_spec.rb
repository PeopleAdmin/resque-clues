require 'spec_helper'

describe Resque::Plugins::Clues::EventPublisher do
  it "should pass Resque lint detection" do
    Resque::Plugin.lint(Resque::Plugins::Clues::EventPublisher) 
  end
end
