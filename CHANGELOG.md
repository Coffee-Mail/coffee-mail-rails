# Changelog

Todas as mudanças relevantes deste projeto são documentadas aqui. O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto adota o [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

### Adicionado

- Delivery method `:coffeemail` do ActionMailer, com remetente e destinatários nomeados, multipart, anexos (inclusive inline), headers custom e headers de controle (`X-CoffeeMail-Idempotency-Key`, `X-CoffeeMail-Sandbox`, `X-CoffeeMail-Scheduled-At`).
- `config.coffeemail` com resolução por `credentials` e `ENV`, e `CoffeeMail::Rails.client` compartilhado e thread-safe.
- `CoffeeMail::Rails::WebhookApp`, Rack app montável que verifica as entregas com o SDK e publica `webhook.coffeemail` em `ActiveSupport::Notifications`, e `CoffeeMail::Rails.on_webhook`.
- Gerador `coffeemail:install` (initializer, rota do webhook e `--delivery-method`).
