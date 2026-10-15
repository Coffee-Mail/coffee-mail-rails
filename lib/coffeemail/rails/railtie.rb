# frozen_string_literal: true

require "rails/railtie"

module CoffeeMail
  module Rails
    # Liga a gem ao Rails: `config.coffeemail`, credentials e o delivery method `:coffeemail`.
    class Railtie < ::Rails::Railtie
      config.coffeemail = ActiveSupport::OrderedOptions.new

      initializer "coffeemail.configuration" do |app|
        CoffeeMail::Rails.setup(options: app.config.coffeemail, credentials: -> { app.credentials.coffeemail })
      end

      initializer "coffeemail.delivery_method" do
        ActiveSupport.on_load(:action_mailer) do
          add_delivery_method :coffeemail, CoffeeMail::Rails::DeliveryMethod
        end
      end
    end
  end
end
