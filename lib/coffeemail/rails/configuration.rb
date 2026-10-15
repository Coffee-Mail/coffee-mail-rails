# frozen_string_literal: true

require "active_support/ordered_options"

module CoffeeMail
  module Rails
    # Resolve a configuração na ordem `config.coffeemail` → `credentials.coffeemail` → `ENV` → padrão.
    class Configuration
      # Variáveis de ambiente lidas como último recurso.
      ENV_KEYS = {
        api_key: "COFFEEMAIL_API_KEY",
        locale: "COFFEEMAIL_LOCALE",
        timeout: "COFFEEMAIL_TIMEOUT",
        webhook_secret: "COFFEEMAIL_WEBHOOK_SECRET",
        webhook_tolerance: "COFFEEMAIL_WEBHOOK_TOLERANCE",
      }.freeze
      # Timeout padrão, em segundos.
      DEFAULT_TIMEOUT = 10
      # Janela padrão de tolerância do webhook, em segundos.
      DEFAULT_WEBHOOK_TOLERANCE = 300
      # Valor numérico aceito em timeout e tolerância.
      NUMERIC = /\A\d+(?:\.\d+)?\z/

      # @return [ActiveSupport::OrderedOptions] opções explícitas (`config.coffeemail`)
      attr_reader :options

      # @param options [ActiveSupport::OrderedOptions]
      # @param credentials [#call] devolve o Hash `credentials.coffeemail` (ou nil)
      # @param env [#fetch]
      def initialize(options: ActiveSupport::OrderedOptions.new, credentials: -> {}, env: ENV)
        @options = options
        @credentials = credentials
        @env = env
      end

      # @return [String, nil]
      def api_key = resolve(:api_key)

      # @return [String]
      def locale = resolve(:locale) || CoffeeMail::Locale::DEFAULT

      # @return [Numeric]
      def timeout = numeric(resolve(:timeout), DEFAULT_TIMEOUT)

      # @return [CoffeeMail::RetryPolicy, nil]
      def retry_policy = options[:retry_policy]

      # @return [#call, nil] transporte do SDK (testes, proxy, instrumentação)
      def transport = options[:transport]

      # @return [String, nil]
      def webhook_secret = resolve(:webhook_secret)

      # @return [Integer]
      def webhook_tolerance = numeric(resolve(:webhook_tolerance), DEFAULT_WEBHOOK_TOLERANCE).to_i

      # Kwargs para `CoffeeMail::Client.new`.
      # @param overrides [Hash] valores que prevalecem (ex.: `coffeemail_settings` do mailer)
      # @return [Hash]
      def client_options(overrides = {})
        base = { api_key: api_key, locale: locale, timeout: timeout, retry_policy: retry_policy, transport: transport }
        base.merge(overrides.to_h.transform_keys(&:to_sym).slice(*base.keys).compact)
      end

      # @return [String]
      def inspect = "#<CoffeeMail::Rails::Configuration locale=#{locale} timeout=#{timeout}>"

      private

      def resolve(key)
        [options[key], credential(key), @env.fetch(ENV_KEYS.fetch(key), nil)].find { |value| present?(value) }
      end

      def credential(key)
        source = @credentials.call
        source.respond_to?(:[]) ? source[key] : nil
      end

      def present?(value)
        !value.nil? && !value.to_s.strip.empty?
      end

      def numeric(value, fallback)
        return value.to_s.to_f if value.is_a?(Numeric) && value.positive?

        value.to_s.match?(NUMERIC) && value.to_f.positive? ? value.to_f : fallback
      end
    end
  end
end
