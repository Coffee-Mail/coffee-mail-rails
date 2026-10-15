# frozen_string_literal: true

require_relative "lib/coffeemail/rails/version"

Gem::Specification.new do |spec|
  spec.name = "coffeemail-rails"
  spec.version = CoffeeMail::Rails::VERSION
  spec.authors = ["CoffeeMail"]
  spec.summary = "Integração Rails do CoffeeMail: delivery method do ActionMailer e webhooks verificados."
  spec.description = "Envia e-mails do ActionMailer pela API CoffeeMail (delivery method :coffeemail), configura o " \
                     "client via config, credentials ou ENV e recebe webhooks verificados como " \
                     "ActiveSupport::Notifications."
  spec.homepage = "https://github.com/Coffee-Mail/coffee-mail-rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true",
  }

  spec.files = Dir["lib/**/*", "sig/**/*.rbs", "README.md", "LICENSE", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "actionmailer", ">= 7.1", "< 9"
  spec.add_dependency "coffeemail", "~> 0.1"
  spec.add_dependency "railties", ">= 7.1", "< 9"
end
