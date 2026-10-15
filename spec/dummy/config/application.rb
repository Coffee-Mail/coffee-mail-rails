# frozen_string_literal: true

require "logger"
require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"
require "coffeemail/rails"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.secret_key_base = "0" * 64
    config.logger = Logger.new(nil)
    config.active_support.deprecation = :silence
    config.action_mailer.delivery_method = :coffeemail
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.default_url_options = { host: "exemplo.com.br" }
    config.coffeemail.api_key = "cm_test_dummy"
    config.coffeemail.webhook_secret = "whsec_dummy"
  end
end
