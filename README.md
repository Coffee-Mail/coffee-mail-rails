<div align="center">

# ☕ CoffeeMail Rails

**Integração oficial da CoffeeMail com Rails 7.1+: envie e-mails do ActionMailer pela API CoffeeMail e receba webhooks verificados como `ActiveSupport::Notifications`.**

[![Gem](https://img.shields.io/gem/v/coffeemail-rails)](https://rubygems.org/gems/coffeemail-rails)
[![CI](https://github.com/Coffee-Mail/coffee-mail-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/Coffee-Mail/coffee-mail-rails/actions/workflows/ci.yml)
[![Rails](https://img.shields.io/badge/rails-7.1%20%7C%207.2%20%7C%208.0-CC0000)](#-requisitos)
[![Licença: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue.svg)](LICENSE)

</div>

---

## 📑 Sumário

- [Visão geral](#-visão-geral)
- [Status do projeto](#-status-do-projeto)
- [Requisitos](#-requisitos)
- [Instalação](#-instalação)
- [Início rápido](#-início-rápido)
- [Configuração](#️-configuração)
- [Tratamento de erros](#️-tratamento-de-erros)
- [Referência](#-referência)
- [Webhooks](#-webhooks)
- [Versionamento e releases](#-versionamento-e-releases)
- [Testes e qualidade](#-testes-e-qualidade)
- [Estrutura do repositório](#️-estrutura-do-repositório)
- [Contribuição](#-contribuição)
- [Projetos relacionados](#-projetos-relacionados)
- [Licença](#-licença)

## ✨ Visão geral

- **Delivery method nativo**: `config.action_mailer.delivery_method = :coffeemail`. Os seus mailers continuam iguais: multipart, anexos (inclusive `attachments.inline`), Cc, Bcc, Reply-To e `deliver_later`.
- **Sobre o SDK oficial**: a entrega e a verificação de webhook usam a gem [`coffeemail`](https://github.com/Coffee-Mail/coffee-mail-sdk-ruby), com o mesmo contrato dos SDKs Node.js, Python, PHP, Java e Go.
- **Configuração do jeito Rails**: `config.coffeemail`, `credentials.coffeemail` ou `ENV`, nessa ordem.
- **Webhooks como eventos**: uma Rack app montável verifica a assinatura e publica `webhook.coffeemail` em `ActiveSupport::Notifications`.
- **Mesmo papel do `coffee-mail-laravel`** no ecossistema Ruby, com os mesmos headers de controle.

## 🚦 Status do projeto

| Item | Estado |
| --- | --- |
| Versão | `0.1.0` (ainda não publicada) |
| Rails | 7.1, 7.2 e 8.0 (matriz do CI) |
| Especificação | [`specs/SPEC.md`](specs/SPEC.md), com cada requisito coberto por teste |

## 📋 Requisitos

- Ruby 3.3 ou superior e Rails 7.1 ou superior.
- Uma chave de API (`cm_live_...` ou `cm_test_...`) e um domínio verificado no dashboard da CoffeeMail.

## 📦 Instalação

```bash
bundle add coffeemail-rails
bin/rails g coffeemail:install --delivery-method
```

O gerador cria `config/initializers/coffeemail.rb`, monta a rota do webhook e, com `--delivery-method`, define `:coffeemail` em `config/environments/production.rb`. Rodar de novo não duplica nada.

## 🚀 Início rápido

```ruby
config.action_mailer.delivery_method = :coffeemail
```

```ruby
class PedidoMailer < ApplicationMailer
  def confirmacao(pedido)
    headers["X-CoffeeMail-Idempotency-Key"] = "pedido-#{pedido.id}"
    mail(to: pedido.cliente_email, subject: "Pedido ##{pedido.id} confirmado")
  end
end

PedidoMailer.confirmacao(pedido).deliver_later
```

Depois da entrega, `mail.message_id` traz o id do e-mail no CoffeeMail.

## ⚙️ Configuração

| Opção | `credentials.coffeemail` | `ENV` | Padrão |
| --- | --- | --- | --- |
| `config.coffeemail.api_key` | `api_key` | `COFFEEMAIL_API_KEY` | — |
| `config.coffeemail.locale` | `locale` | `COFFEEMAIL_LOCALE` | `pt-BR` |
| `config.coffeemail.timeout` | `timeout` | `COFFEEMAIL_TIMEOUT` | `10` |
| `config.coffeemail.webhook_secret` | `webhook_secret` | `COFFEEMAIL_WEBHOOK_SECRET` | — |
| `config.coffeemail.webhook_tolerance` | `webhook_tolerance` | `COFFEEMAIL_WEBHOOK_TOLERANCE` | `300` |
| `config.coffeemail.retry_policy` | — | — | `nil` (`CoffeeMail::RetryPolicy`) |
| `config.coffeemail.transport` | — | — | transporte do SDK (testes, proxy) |

- Sem chave, a aplicação sobe normalmente; o erro `CoffeeMail::MissingApiKeyError` só aparece no primeiro envio.
- `config.action_mailer.coffeemail_settings = { api_key:, locale:, timeout: }` sobrepõe a configuração para o ActionMailer.
- `CoffeeMail::Rails.client` dá acesso ao client completo do SDK (domínios, templates, audiências etc.), compartilhado pelo processo.

### Headers de controle

| Header no mailer | Efeito |
| --- | --- |
| `X-CoffeeMail-Idempotency-Key` (ou `Idempotency-Key`) | vira `x-idempotency-key`: reenviar a mesma chave devolve o mesmo e-mail |
| `X-CoffeeMail-Sandbox: true` | simula o envio, sem entregar |
| `X-CoffeeMail-Scheduled-At` | agenda o envio (ISO-8601) |

Os demais headers custom (`X-*`, `List-Unsubscribe`...) seguem para a API. Sem chave de idempotência, a API deduplica envios idênticos pelo hash do payload.

## 🛡️ Tratamento de erros

Uma falha levanta `CoffeeMail::Rails::DeliveryError`, com o erro do SDK em `#error` (e `#code`, como `VALIDATION_ERROR` ou `RATE_LIMIT_EXCEEDED`). É o contrato do ActionMailer: com `raise_delivery_errors = false`, a exceção é engolida; no `deliver_later`, o ActiveJob aplica a política de retry do seu job.

## 📚 Referência

| API | Descrição |
| --- | --- |
| `CoffeeMail::Rails::DeliveryMethod` | delivery method `:coffeemail` |
| `CoffeeMail::Rails.client` / `.reset!` | client do SDK compartilhado / descarta o client memoizado |
| `CoffeeMail::Rails.configure { \|config\| ... }` | configuração fora do Rails ou em testes |
| `CoffeeMail::Rails::WebhookApp` | Rack app de recebimento de webhooks |
| `CoffeeMail::Rails.on_webhook(*tipos) { \|event, payload\| }` | assinatura de webhooks verificados |
| `bin/rails g coffeemail:install [--delivery-method]` | gerador |

## 🔔 Webhooks

```ruby
Rails.application.routes.draw do
  mount CoffeeMail::Rails::WebhookApp.new, at: "/webhooks/coffeemail"
end
```

```ruby
CoffeeMail::Rails.on_webhook("email.bounced", "email.complained") do |event, payload|
  Supressao.registrar!(event.data, tentativa: payload[:idempotency_key])
end
```

- A assinatura (`x-webhook-signature`) é verificada pelo SDK: HMAC-SHA256 de `timestamp.idempotency_key.corpo_bruto`, em tempo constante, com janela de 5 minutos.
- Respostas: `204` aceito, `401` assinatura inválida ou expirada, `400` JSON inválido, `405` método diferente de POST, `500` sem segredo configurado ou quando um subscriber levanta exceção, para que a API retente (até 5 vezes).
- O payload não traz o id do e-mail, e `x-webhook-idempotency-key` muda a cada tentativa de entrega: ela não serve para deduplicar retentativas.

## 🔖 Versionamento e releases

- [Versionamento Semântico](https://semver.org/lang/pt-BR/). A API pública só recebe **adições e depreciações**; o CI compara as assinaturas RBS com as da última versão publicada.
- Uma tag `vX.Y.Z` dispara o release: confere a tag com `CoffeeMail::Rails::VERSION` e o `CHANGELOG.md`, roda os gates e publica no RubyGems (trusted publishing).

## 🧪 Testes e qualidade

```bash
bundle exec rake                          # todos os gates
RAILS_VERSION="~> 7.1.0" bundle update rails && bundle exec rspec   # outra versão do Rails
bin/check-spec-coverage --report          # matriz SPEC × testes
```

- Os testes rodam num app dummy (`spec/dummy`) com o transporte falso do SDK; o payload de ponta a ponta é validado contra o OpenAPI de `POST /emails`.
- Até a primeira versão do SDK ser publicada, o `Gemfile` usa o SDK local (`COFFEEMAIL_SDK_PATH`, padrão `../coffee-mail-sdk-ruby`).

## 🗂️ Estrutura do repositório

```
├── lib/coffeemail/rails.rb              configuração, client e on_webhook
├── lib/coffeemail/rails/                delivery method, mapper do Mail, webhook app, railtie
├── lib/generators/coffeemail/install/   gerador coffeemail:install
├── sig/                                 assinaturas RBS (Steep)
├── specs/SPEC.md                        especificação (requisitos RB-RAILS-*)
├── spec/                                RSpec + app dummy
└── rubocop/, tools/, bin/               regras da casa e gates
```

## 🤝 Contribuição

Veja o [CONTRIBUTING.md](CONTRIBUTING.md). Vulnerabilidades: siga o [SECURITY.md](SECURITY.md).

## 🔗 Projetos relacionados

| Repositório | Papel |
| --- | --- |
| [coffee-mail-sdk-ruby](https://github.com/Coffee-Mail/coffee-mail-sdk-ruby) | SDK oficial Ruby (`coffeemail`) |
| **coffee-mail-rails** (você está aqui) | Integração Rails (`coffeemail-rails`) |
| [coffee-mail-laravel](https://github.com/Coffee-Mail/coffee-mail-laravel) | Integração Laravel (`coffeemail/coffeemail-laravel`) |
| [coffee-mail-sdk-workbench](https://github.com/Coffee-Mail/coffee-mail-sdk-workbench) | Bancada de validação dos SDKs por spec |

## 📄 Licença

[MIT](LICENSE).
