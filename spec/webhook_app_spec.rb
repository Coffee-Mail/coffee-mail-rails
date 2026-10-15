# frozen_string_literal: true

require "openssl"
require "rack/test"

RSpec.describe CoffeeMail::Rails::WebhookApp do
  include Rack::Test::Methods

  let(:app) { Rails.application }
  let(:secret) { "whsec_dummy" }
  let(:payload) do
    JSON.generate("event_type" => "email.bounced", "webhook_id" => "w1", "data" => { "to" => "a@x.com" })
  end

  def signed_headers(body, timestamp: Time.now.to_i, key: "0123456789abcdef", with_secret: secret)
    digest = OpenSSL::HMAC.hexdigest("SHA256", with_secret, "#{timestamp}.#{key}.#{body}")
    { "HTTP_X_WEBHOOK_SIGNATURE" => "sha256=#{digest}", "HTTP_X_WEBHOOK_TIMESTAMP" => timestamp.to_s,
      "HTTP_X_WEBHOOK_IDEMPOTENCY_KEY" => key, "CONTENT_TYPE" => "application/json" }
  end

  def deliver(body = payload, headers = signed_headers(body), method: :post)
    public_send(method, "/webhooks/coffeemail", body, headers)
    last_response
  end

  def with_subscriber(*types, &)
    received = []
    subscriber = CoffeeMail::Rails.on_webhook(*types) { |event, data| received << [event, data] }
    yield received
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it "RB-RAILS-WHK-01 é uma Rack app montável nas rotas" do
    expect(deliver.status).to eq(204)
    expect(described_class.new.call(Rack::MockRequest.env_for("/", method: "GET")).first).to eq(405)
  end

  it "RB-RAILS-WHK-02 usa a verificação do SDK com segredo e tolerância configurados" do
    allow(CoffeeMail::Webhook).to receive(:from_rack).and_call_original
    deliver

    expect(CoffeeMail::Webhook).to have_received(:from_rack).with(anything, secret: secret, tolerance: 300)
  end

  it "RB-RAILS-WHK-03 responde 401 para assinatura ausente, inválida ou expirada" do
    missing = deliver(payload, { "CONTENT_TYPE" => "application/json" }).status
    wrong = deliver(payload, signed_headers(payload, with_secret: "whsec_outro")).status
    expired = deliver(payload, signed_headers(payload, timestamp: Time.now.to_i - 3600)).status

    expect([missing, wrong, expired]).to eq([401, 401, 401])
    expect(JSON.parse(last_response.body)["error"]).to include("Assinatura")
  end

  it "RB-RAILS-WHK-03 responde 400 para JSON inválido, 405 fora de POST e 500 sem segredo" do
    invalid = deliver("[1]").status
    not_allowed = deliver(method: :get).status
    app_without_secret = described_class.new(configuration: CoffeeMail::Rails::Configuration.new(env: {}))
    status, = app_without_secret.call(Rack::MockRequest.env_for("/", method: "POST", input: payload))

    expect([invalid, not_allowed, status]).to eq([400, 405, 500])
  end

  it "RB-RAILS-WHK-04 publica webhook.coffeemail com evento, chave e test" do
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("webhook.coffeemail") { |*, data| events << data }
    deliver(payload, signed_headers(payload).merge("HTTP_X_WEBHOOK_TEST" => "true"))

    expect(events.size).to eq(1)
    expect(events.first[:event]).to be_a(CoffeeMail::Webhook::Event)
    expect(events.first).to include(idempotency_key: "0123456789abcdef", test: true)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it "RB-RAILS-WHK-05 on_webhook filtra por tipo de evento" do
    with_subscriber("email.delivered") do |delivered|
      with_subscriber do |all|
        deliver

        expect(delivered).to be_empty
        expect(all.map { |event, _| event.event_type }).to eq(["email.bounced"])
        expect(all.first.last).to include(:idempotency_key)
      end
    end
  end

  it "RB-RAILS-WHK-06 exceção em subscriber responde 500 para a API retentar" do
    subscriber = CoffeeMail::Rails.on_webhook { raise ArgumentError, "falhou" }

    expect(deliver.status).to eq(500)
    expect(JSON.parse(last_response.body)["error"]).to include("Falha ao processar")
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
