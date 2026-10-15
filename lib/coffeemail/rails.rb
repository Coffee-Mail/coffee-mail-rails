# frozen_string_literal: true

require "coffeemail"
require "active_support"
require "active_support/notifications"
require_relative "rails/version"
require_relative "rails/messages"
require_relative "rails/configuration"
require_relative "rails/delivery_error"
require_relative "rails/message_mapper"
require_relative "rails/delivery_method"
require_relative "rails/webhook_app"

module CoffeeMail
  # Integração Rails do CoffeeMail: delivery method do ActionMailer, client configurado e webhooks.
  module Rails
    # Nome do evento publicado em `ActiveSupport::Notifications` a cada webhook verificado.
    NOTIFICATION = "webhook.coffeemail"
    # Guarda a configuração e o client entre threads.
    LOCK = Mutex.new
    @configuration = Configuration.new
    @client = nil

    module_function

    # Define a origem da configuração. O Railtie chama isto no boot; fora do Rails, use {configure}.
    #
    # @param options [ActiveSupport::OrderedOptions]
    # @param credentials [#call]
    # @return [Configuration]
    def setup(options:, credentials: -> {})
      LOCK.synchronize do
        @client = nil
        @configuration = Configuration.new(options: options, credentials: credentials)
      end
    end

    # @yieldparam options [ActiveSupport::OrderedOptions]
    # @return [Configuration]
    def configure
      yield configuration.options
      reset!
      configuration
    end

    # @return [Configuration]
    def configuration = LOCK.synchronize { @configuration }

    # Client do SDK, criado no primeiro uso e compartilhado pelo processo.
    #
    # @return [CoffeeMail::Client]
    # @raise [CoffeeMail::MissingApiKeyError] sem chave configurada
    def client
      LOCK.synchronize do
        @client ||= CoffeeMail::Client.new(**@configuration.client_options)
      end
    end

    # Descarta o client memoizado (testes, recarga de credenciais).
    #
    # @return [nil]
    def reset!
      LOCK.synchronize { @client = nil }
      nil
    end

    # Assina os webhooks verificados, filtrando por tipo de evento.
    #
    # @example
    #   CoffeeMail::Rails.on_webhook("email.bounced") { |event, _payload| Suppression.from(event) }
    # @param event_types [Array<String>] sem tipos, recebe todos
    # @yieldparam event [CoffeeMail::Webhook::Event]
    # @yieldparam payload [Hash] `event`, `idempotency_key` e `test`
    # @return [Object] subscriber, para `ActiveSupport::Notifications.unsubscribe`
    def on_webhook(*event_types, &handler)
      ActiveSupport::Notifications.subscribe(NOTIFICATION) do |_name, _started, _finished, _id, payload|
        dispatch(handler, event_types, payload)
      end
    end

    # @api private
    def dispatch(handler, event_types, payload)
      event = payload[:event]
      return unless event.is_a?(CoffeeMail::Webhook::Event)

      handler.call(event, payload) if event_types.empty? || event_types.include?(event.event_type.to_s)
    end
  end
end

require_relative "rails/railtie" if defined?(Rails::Railtie)
