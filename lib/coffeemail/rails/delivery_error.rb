# frozen_string_literal: true

module CoffeeMail
  module Rails
    # Falha de entrega levantada pelo delivery method (o ActionMailer decide se ela sobe via `raise_delivery_errors`).
    class DeliveryError < StandardError
      # @return [CoffeeMail::Error, nil] erro original do SDK
      attr_reader :error

      # @param message [String]
      # @param error [CoffeeMail::Error, nil]
      def initialize(message, error: nil)
        super(message)
        @error = error
      end

      # @return [String, nil] código canônico do SDK
      def code = error&.code

      # @return [Exception, nil]
      def cause = error || super
    end
  end
end
