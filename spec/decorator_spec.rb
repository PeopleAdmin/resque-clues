require 'spec_helper'

describe Resque::Plugins::Clues::Decorator do
  it "should pass Resque lint detection" do
    Resque::Plugin.lint(Resque::Plugins::Clues::Decorator) 
  end
end
