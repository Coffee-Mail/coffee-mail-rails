# frozen_string_literal: true

RSpec.describe CoffeeMail::Rails::Configuration do
  def build(options: {}, credentials: nil, env: {})
    described_class.new(options: ActiveSupport::OrderedOptions.new.merge!(options),
                        credentials: -> { credentials }, env: env)
  end

  it "RB-RAILS-CFG-01 o Railtie expõe config.coffeemail com as opções da gem" do
    options = Rails.application.config.coffeemail

    expect(options).to be_a(ActiveSupport::OrderedOptions)
    expect(options.api_key).to eq("cm_test_dummy")
    expect(CoffeeMail::Rails.configuration.options).to equal(options)
    expect(build(options: { retry_policy: CoffeeMail::RetryPolicy.new(max_attempts: 2) }).retry_policy).to be_enabled
  end

  it "RB-RAILS-CFG-02 resolve config, depois credentials, depois ENV, depois o padrão" do
    env = { "COFFEEMAIL_API_KEY" => "cm_env", "COFFEEMAIL_LOCALE" => "en", "COFFEEMAIL_WEBHOOK_SECRET" => "whsec_env" }
    from_config = build(options: { api_key: "cm_config" }, credentials: { api_key: "cm_cred" }, env: env)
    from_credentials = build(options: { api_key: " " }, credentials: { api_key: "cm_cred" }, env: env)
    from_env = build(env: env)
    defaults = build

    expect([from_config.api_key, from_credentials.api_key, from_env.api_key]).to eq(%w[cm_config cm_cred cm_env])
    expect([from_env.locale, defaults.locale, defaults.timeout,
            defaults.webhook_tolerance]).to eq(["en", "pt-BR", 10, 300])
    expect(from_env.webhook_secret).to eq("whsec_env")
    expect(defaults.api_key).to be_nil
  end

  it "RB-RAILS-CFG-02 credentials ausentes ou sem a chave não quebram" do
    expect(build(credentials: nil).api_key).to be_nil
    expect(build(credentials: {}).webhook_secret).to be_nil
  end

  it "RB-RAILS-CFG-03 client único, preguiçoso e thread-safe; reset! descarta" do
    first = Array.new(8) { Thread.new { CoffeeMail::Rails.client } }.map(&:value)
    CoffeeMail::Rails.reset!

    expect(first.uniq.size).to eq(1)
    expect(CoffeeMail::Rails.client).not_to equal(first.first)
  end

  it "RB-RAILS-CFG-03 configure altera as opções e recria o client" do
    before = CoffeeMail::Rails.client
    CoffeeMail::Rails.configure { |config| config.timeout = 3 }

    expect(CoffeeMail::Rails.client).not_to equal(before)
    expect(CoffeeMail::Rails.client.timeout).to eq(3.0)
  ensure
    CoffeeMail::Rails.configuration.options.delete(:timeout)
  end

  it "RB-RAILS-CFG-04 sem chave a aplicação sobe e o erro só aparece no uso" do
    CoffeeMail::Rails.setup(options: ActiveSupport::OrderedOptions.new, credentials: -> {})
    stub_const("ENV", ENV.to_h.except("COFFEEMAIL_API_KEY"))

    expect { CoffeeMail::Rails.configuration }.not_to raise_error
    expect { CoffeeMail::Rails.client }.to raise_error(CoffeeMail::MissingApiKeyError)
  ensure
    CoffeeMail::Rails.setup(options: Rails.application.config.coffeemail,
                            credentials: -> { Rails.application.credentials.coffeemail })
  end

  it "RB-RAILS-CFG-05 timeout e tolerância não numéricos caem no padrão" do
    invalid = build(options: { timeout: "rápido", webhook_tolerance: "-5" })
    valid = build(env: { "COFFEEMAIL_TIMEOUT" => "2.5", "COFFEEMAIL_WEBHOOK_TOLERANCE" => "600" })

    expect([invalid.timeout, invalid.webhook_tolerance]).to eq([10, 300])
    expect([valid.timeout, valid.webhook_tolerance]).to eq([2.5, 600])
  end

  it "RB-RAILS-CFG-06 inspect não mostra chave nem segredo" do
    config = build(options: { api_key: "cm_live_segredo", webhook_secret: "whsec_segredo" })

    expect(config.inspect).not_to include("segredo")
    expect(CoffeeMail::Rails.client.inspect).not_to include("cm_test_dummy")
  end
end
