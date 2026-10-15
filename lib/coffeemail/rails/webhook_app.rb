# frozen_string_literal: true

require "json"
require "active_support/notifications"

module CoffeeMail
  module Rails
    # Rack app que recebe as entregas de webhook, verifica a assinatura com o SDK e publica
    # `ActiveSupport::Notifications` (`webhook.coffeemail`).
    #
    # @example config/routes.rb
    #   mount CoffeeMail::Rails::WebhookApp.new, at: "/webhooks/coffeemail"
    class WebhookApp
      # Único método aceito.
      POST = "POST"
      # Header da chave de idempotência da tentativa (formato Rack).
      IDEMPOTENCY_ENV = "HTTP_X_WEBHOOK_IDEMPOTENCY_KEY"
      # Headers das respostas.
      JSON_HEADERS = { "content-type" => "application/json" }.freeze
      # Status por motivo de falha da verificação.
      FAILURE_STATUSES = { payload: 400 }.freeze
      # Status de assinatura ausente, inválida ou expirada.
      UNAUTHORIZED = 401
      # Status da entrega aceita.
      NO_CONTENT = 204
      # Status de método não permitido.
      METHOD_NOT_ALLOWED = 405
      # Status de falha da aplicação (a API retenta a entrega).
      SERVER_ERROR = 500
      # Mensagem por motivo de falha da verificação.
      FAILURE_MESSAGES = { payload: :INVALID_PAYLOAD }.freeze

      # @param configuration [Configuration, nil] padrão: {CoffeeMail::Rails.configuration}
      def initialize(configuration: nil)
        @configuration = configuration
      end

      # @param env [Hash] env do Rack
      # @return [Array(Integer, Hash, Array<String>)]
      def call(env)
        return reply(METHOD_NOT_ALLOWED, :METHOD_NOT_ALLOWED) unless env["REQUEST_METHOD"] == POST

        secret = configuration.webhook_secret
        return reply(SERVER_ERROR, :MISSING_WEBHOOK_SECRET) if secret.to_s.strip.empty?

        verify(env, secret.to_s)
      end

      private

      def verify(env, secret)
        result = CoffeeMail::Webhook.from_rack(env, secret: secret, tolerance: configuration.webhook_tolerance)
        error = result.error
        return failure(error.is_a?(CoffeeMail::WebhookVerificationError) ? error.reason : :signature) if error

        publish(result.data, env[IDEMPOTENCY_ENV])
      end

      def configuration = @configuration || CoffeeMail::Rails.configuration

      def publish(event, idempotency_key)
        ActiveSupport::Notifications.instrument(NOTIFICATION, event: event, idempotency_key: idempotency_key,
                                                              test: event.test?) { event }
        [NO_CONTENT, {}, []]
      rescue StandardError
        reply(SERVER_ERROR, :SUBSCRIBER_FAILED)
      end

      def failure(reason)
        reply(FAILURE_STATUSES.fetch(reason, UNAUTHORIZED), FAILURE_MESSAGES.fetch(reason, :INVALID_SIGNATURE))
      end

      def reply(status, key)
        body = JSON.generate(error: Messages.message(configuration.locale, key))
        [status, JSON_HEADERS.dup, [body]]
      end
    end
  end
end
