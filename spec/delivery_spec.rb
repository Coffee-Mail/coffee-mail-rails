# frozen_string_literal: true

require "openapi_first"
require "rack"

RSpec.describe CoffeeMail::Rails::DeliveryMethod do
  let(:transport) { use_transport(FakeTransport.new) }
  let(:body) { transport.last_body }

  def deliver(**options)
    transport
    WelcomeMailer.welcome(to: "Ana Souza <ana@exemplo.com.br>", **options).deliver_now
  end

  it "RB-RAILS-DLV-01 delivery_method :coffeemail entrega pelo emails.send" do
    deliver

    expect(ActionMailer::Base.delivery_method).to eq(:coffeemail)
    expect(transport.requests.last.url).to eq("https://api.coffeemail.com.br/v1/product/emails")
    expect(transport.requests.last.headers["authorization"]).to eq("Bearer cm_test_dummy")
  end

  it "RB-RAILS-DLV-01 coffeemail_settings sobrepõe a configuração global" do
    transport
    message = WelcomeMailer.welcome(to: "ana@exemplo.com.br")
    message.delivery_method(described_class, api_key: "cm_test_mailer", locale: "en")
    message.deliver

    expect(transport.requests.last.headers).to include("authorization" => "Bearer cm_test_mailer",
                                                       "accept-language" => "en")
  end

  it "RB-RAILS-DLV-02 remetente com nome de exibição" do
    deliver

    expect(body["from"]).to eq("email" => "app@exemplo.com.br", "name" => "Minha App")
  end

  it "RB-RAILS-DLV-02 sem From levanta DeliveryError sem chamar a API" do
    transport

    expect { WelcomeMailer.anonymous.deliver_now }
      .to raise_error(CoffeeMail::Rails::DeliveryError, /remetente \(From\)/)
    expect(transport.requests).to be_empty
  end

  it "RB-RAILS-DLV-03 To, Cc e Bcc com nomes; sem To levanta DeliveryError" do
    deliver

    expect(body["to"]).to eq([{ "email" => "ana@exemplo.com.br", "name" => "Ana Souza" }])
    expect(body["cc"]).to eq([{ "email" => "copia@exemplo.com.br", "name" => "Copia" }])
    expect { WelcomeMailer.nobody.deliver_now }.to raise_error(CoffeeMail::Rails::DeliveryError, /destinatário/)
  end

  it "RB-RAILS-DLV-03 Bcc é enviado à API" do
    transport
    message = WelcomeMailer.welcome(to: "ana@exemplo.com.br")
    message.bcc = "Oculta <oculta@exemplo.com.br>"
    message.deliver

    expect(body["bcc"]).to eq([{ "email" => "oculta@exemplo.com.br", "name" => "Oculta" }])
  end

  it "RB-RAILS-DLV-04 Reply-To e Subject" do
    deliver

    expect(body).to include("replyTo" => { "email" => "suporte@exemplo.com.br" }, "subject" => "Bem-vinda!")
  end

  it "RB-RAILS-DLV-05 multipart usa html_part e text_part; mensagem simples usa o Content-Type" do
    deliver
    multipart = body
    WelcomeMailer.plain(to: "ana@exemplo.com.br").deliver_now

    expect(multipart).to include("html" => "<p>Olá, Ana!</p>\n", "text" => "Olá, Ana!\n")
    expect(transport.last_body).to include("text" => "Olá em texto")
    expect(transport.last_body).not_to have_key("html")
  end

  it "RB-RAILS-DLV-06 anexos em base64 e inline com cid" do
    deliver(attachment: { filename: "nota.txt", content: "conteúdo" },
            inline: { filename: "logo.png", content: "PNG" })
    attachments = body.fetch("attachments").to_h { |item| [item["filename"], item] }

    expect(attachments["nota.txt"]).to include("content" => Base64.strict_encode64("conteúdo"),
                                               "contentType" => "text/plain", "disposition" => "attachment")
    expect(attachments["nota.txt"]).not_to have_key("cid")
    expect(attachments["logo.png"]).to include("disposition" => "inline", "contentType" => "image/png")
    expect(attachments["logo.png"]["cid"]).to match(/\A[^<>]+@[^<>]+\z/)
  end

  it "RB-RAILS-DLV-07 headers de controle viram opções do SDK e não seguem como custom" do
    deliver(headers: { "X-CoffeeMail-Idempotency-Key" => "pedido-1", "X-CoffeeMail-Sandbox" => "true",
                       "X-CoffeeMail-Scheduled-At" => "2026-12-01T10:00:00.000Z" })

    expect(transport.requests.last.headers).to include("x-idempotency-key" => "pedido-1",
                                                       "x-coffeemail-sandbox" => "true")
    expect(body["scheduledAt"]).to eq("2026-12-01T10:00:00.000Z")
    expect(body).not_to have_key("headers")
  end

  it "RB-RAILS-DLV-07 Idempotency-Key também é aceito e sandbox falso não envia o header" do
    deliver(headers: { "Idempotency-Key" => "alt-1", "X-CoffeeMail-Sandbox" => "false" })

    expect(transport.requests.last.headers["x-idempotency-key"]).to eq("alt-1")
    expect(transport.requests.last.headers).not_to have_key("x-coffeemail-sandbox")
  end

  it "RB-RAILS-DLV-08 demais headers custom vão em headers, sem os MIME padrão" do
    deliver(headers: { "X-Pedido" => "123", "List-Unsubscribe" => "<mailto:sair@exemplo.com.br>" })

    expect(body["headers"]).to eq("X-Pedido" => "123", "List-Unsubscribe" => "<mailto:sair@exemplo.com.br>")
  end

  it "RB-RAILS-DLV-09 message_id recebe o id da API" do
    expect(deliver.message_id).to eq("e1")
  end

  it "RB-RAILS-DLV-10 falha da API levanta DeliveryError com o erro do SDK" do
    use_transport(FakeTransport.new(422,
                                    { "error" => { "code" => "DOMAIN_NOT_VERIFIED",
                                                   "message" => "Domínio não verificado" } }))

    expect { WelcomeMailer.welcome(to: "ana@exemplo.com.br").deliver_now }
      .to raise_error(CoffeeMail::Rails::DeliveryError) { |error|
        expect(error.message).to include("Domínio não verificado", "DOMAIN_NOT_VERIFIED", "422")
        expect([error.error.class, error.code,
                error.cause]).to eq([CoffeeMail::Error, "DOMAIN_NOT_VERIFIED", error.error])
      }
  end

  it "RB-RAILS-DLV-10 com raise_delivery_errors = false o ActionMailer engole a falha" do
    use_transport(FakeTransport.new(500, {}))
    ActionMailer::Base.raise_delivery_errors = false

    expect { WelcomeMailer.welcome(to: "ana@exemplo.com.br").deliver_now }.not_to raise_error
  ensure
    ActionMailer::Base.raise_delivery_errors = true
  end

  it "RB-RAILS-DLV-11 deliver_later entrega pelo ActiveJob" do
    transport
    ActiveJob::Base.queue_adapter = :inline
    WelcomeMailer.welcome(to: "ana@exemplo.com.br").deliver_later

    expect(transport.requests.size).to eq(1)
  ensure
    ActiveJob::Base.queue_adapter = :test
  end

  it "RB-RAILS-QA-03 payload completo é válido contra o schema de POST /emails" do
    deliver(headers: { "X-Pedido" => "1", "X-CoffeeMail-Idempotency-Key" => "k" },
            attachment: { filename: "nota.txt", content: "x" }, inline: { filename: "logo.png", content: "PNG" })
    request = transport.requests.last
    env = Rack::MockRequest.env_for(request.url, method: "POST", input: request.body,
                                                 "CONTENT_TYPE" => "application/json")
    validated = OpenapiFirst.load(File.expand_path("../openapi/product.json", __dir__)).validate_request(Rack::Request.new(env))

    expect(validated).to be_valid, validated.error&.message.to_s
  end
end
