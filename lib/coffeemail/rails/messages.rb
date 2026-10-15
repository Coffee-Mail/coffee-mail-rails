# frozen_string_literal: true

module CoffeeMail
  module Rails
    # @api private
    module Messages
      PT_BR = {
        MISSING_FROM: "O e-mail precisa de ao menos um remetente (From).",
        MISSING_TO: "O e-mail precisa de ao menos um destinatário (To).",
        DELIVERY_FAILED: "Falha ao entregar o e-mail pelo CoffeeMail: {message} ({code}, status {status})",
        MISSING_WEBHOOK_SECRET: "O segredo de webhook (COFFEEMAIL_WEBHOOK_SECRET) não está configurado.",
        INVALID_SIGNATURE: "Assinatura do webhook ausente, inválida ou expirada.",
        INVALID_PAYLOAD: "O corpo do webhook não é um objeto JSON válido.",
        METHOD_NOT_ALLOWED: "Use POST para entregar webhooks.",
        SUBSCRIBER_FAILED: "Falha ao processar o webhook na aplicação.",
      }.freeze

      EN = {
        MISSING_FROM: "The email needs at least one sender (From).",
        MISSING_TO: "The email needs at least one recipient (To).",
        DELIVERY_FAILED: "Failed to deliver the email through CoffeeMail: {message} ({code}, status {status})",
        MISSING_WEBHOOK_SECRET: "The webhook secret (COFFEEMAIL_WEBHOOK_SECRET) is not configured.",
        INVALID_SIGNATURE: "Webhook signature is missing, invalid or expired.",
        INVALID_PAYLOAD: "The webhook body is not a valid JSON object.",
        METHOD_NOT_ALLOWED: "Use POST to deliver webhooks.",
        SUBSCRIBER_FAILED: "The application failed to process the webhook.",
      }.freeze

      CATALOG = { CoffeeMail::Locale::PT_BR => PT_BR, CoffeeMail::Locale::EN => EN }.freeze

      module_function

      def message(locale, key, params = {})
        template = CATALOG.fetch(locale) { PT_BR }.fetch(key)
        params.reduce(template) { |text, (name, value)| text.gsub("{#{name}}", value.to_s) }
      end
    end
  end
end
