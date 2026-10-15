# frozen_string_literal: true

module CoffeeMail
  module Rails
    # Delivery method do ActionMailer: `config.action_mailer.delivery_method = :coffeemail`.
    #
    # `config.action_mailer.coffeemail_settings` (`api_key`, `locale`, `timeout`) sobrepõe a configuração global.
    class DeliveryMethod
      # @return [Hash] configurações do mailer
      attr_reader :settings

      # @param settings [Hash]
      def initialize(settings = {})
        @settings = settings.to_h
      end

      # Entrega o e-mail e grava o id do CoffeeMail em `mail.message_id`.
      #
      # @param mail [Mail::Message]
      # @return [CoffeeMail::Response]
      # @raise [DeliveryError] com remetente/destinatário ausente ou falha da API
      def deliver!(mail)
        mapped = MessageMapper.call(mail)
        error_key = mapped.error_key
        raise DeliveryError, Messages.message(locale, error_key) if error_key

        send_through_api(mail, mapped.payload)
      end

      private

      def send_through_api(mail, payload)
        response = client.emails.send(from: payload.fetch(:from), to: payload.fetch(:to), **payload.except(:from, :to))
        error = response.error
        raise delivery_error(error) if error

        mail.message_id = response.data.id
        response
      end

      def client
        overrides = CoffeeMail::Rails.configuration.client_options(settings)
        default = CoffeeMail::Rails.configuration.client_options
        overrides == default ? CoffeeMail::Rails.client : CoffeeMail::Client.new(**overrides)
      end

      def locale = CoffeeMail::Rails.configuration.client_options(settings).fetch(:locale)

      def delivery_error(error)
        message = Messages.message(locale, :DELIVERY_FAILED, message: error.message, code: error.code,
                                                             status: error.status)
        DeliveryError.new(message, error: error)
      end
    end
  end
end
