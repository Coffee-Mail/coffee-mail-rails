# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec/"
  add_filter "/tools/"
  add_filter "/rubocop/"
  minimum_coverage line: 85, branch: 78
end

ENV["RAILS_ENV"] = "test"
require_relative "dummy/config/environment"
require_relative "support/fake_transport"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.after do
    CoffeeMail::Rails.configuration.options.delete(:transport)
    CoffeeMail::Rails.reset!
  end
end
