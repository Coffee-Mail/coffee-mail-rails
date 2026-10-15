# frozen_string_literal: true

Rails.application.routes.draw do
  mount CoffeeMail::Rails::WebhookApp.new, at: "/webhooks/coffeemail"
end
