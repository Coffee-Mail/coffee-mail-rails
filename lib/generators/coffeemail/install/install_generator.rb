# frozen_string_literal: true

require "rails/generators/base"

module Coffeemail
  module Generators
    # `bin/rails g coffeemail:install [--delivery-method]`: initializer, rota do webhook e, opcionalmente, o
    # delivery method em produção. Rodar de novo não duplica nada.
    class InstallGenerator < ::Rails::Generators::Base
      # Linha de rota montada pelo gerador.
      ROUTE = 'mount CoffeeMail::Rails::WebhookApp.new, at: "/webhooks/coffeemail"'
      # Configuração do delivery method em produção.
      DELIVERY_METHOD = "  config.action_mailer.delivery_method = :coffeemail\n"
      # Âncora do bloco de configuração do ambiente.
      CONFIGURE_ANCHOR = /Rails\.application\.configure do\n/
      # Arquivos tocados pelo gerador.
      INITIALIZER = "config/initializers/coffeemail.rb"
      # Arquivo de rotas.
      ROUTES = "config/routes.rb"
      # Ambiente de produção.
      PRODUCTION = "config/environments/production.rb"

      source_root File.expand_path("templates", __dir__)

      class_option :delivery_method, type: :boolean, default: false,
                                     desc: "Define :coffeemail como delivery method em produção"

      # @return [void]
      def create_initializer
        template "coffeemail.rb", INITIALIZER, skip: true
      end

      # @return [void]
      def mount_webhook_route
        return if contains?(ROUTES, "CoffeeMail::Rails::WebhookApp")

        route ROUTE
      end

      # @return [void]
      def configure_delivery_method
        return unless options[:delivery_method]
        return if contains?(PRODUCTION, "delivery_method = :coffeemail")

        inject_into_file PRODUCTION, DELIVERY_METHOD, after: CONFIGURE_ANCHOR
      end

      private

      def contains?(relative, text)
        path = File.join(destination_root, relative)
        File.exist?(path) && File.read(path).include?(text)
      end
    end
  end
end
