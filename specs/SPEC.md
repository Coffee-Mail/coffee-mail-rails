# SPEC — Integração Rails do CoffeeMail (`coffeemail-rails`)

| | |
| --- | --- |
| **Status** | Aprovado em 2026-10-14 |
| **Data** | 2026-10-14 |
| **Gem** | `coffeemail-rails` (livre no RubyGems em 2026-10-14) · `require "coffeemail/rails"` · módulo `CoffeeMail::Rails` |
| **Repositório** | `Coffee-Mail/coffee-mail-rails` |
| **Depende de** | `coffeemail ~> 0.1`, `railties` e `actionmailer` `>= 7.1, < 9` |
| **Ruby / Rails** | Ruby 3.3+ · CI: Rails 7.1, 7.2 e 8.0 (gemfiles por versão) × Ruby 3.3 e estável |
| **Referência** | `coffee-mail-laravel` (mesmo papel no ecossistema PHP) e o SPEC do SDK Ruby |

## 1. Método

O método é o mesmo do SDK. Cada requisito tem um ID `RB-RAILS-*`, o teste é escrito antes e leva o ID no nome, e `bin/check-spec-coverage` vira gate do CI. As regras da casa valem por meio dos mesmos cops do SDK (copiados para `rubocop/cop/coffeemail/`). Notação: **[M]** é obrigatório e **[S]** é recomendado.

## 2. Decisões

| # | Decisão | Motivo |
| --- | --- | --- |
| D1 | A gem fica separada do SDK | O SDK continua sem dependência de Rails |
| D2 | Entrega via `ActionMailer::Base.add_delivery_method :coffeemail` | É a forma nativa: `config.action_mailer.delivery_method = :coffeemail` |
| D3 | A falha de entrega **levanta** `CoffeeMail::Rails::DeliveryError` | É o contrato do ActionMailer: `raise_delivery_errors` decide se a exceção sobe. É o único `raise` da gem fora da validação de configuração |
| D4 | O webhook é uma Rack app montável que publica `ActiveSupport::Notifications` | Funciona em Rails, Sinatra e Rack puro, sem controller gerado. É o equivalente ao evento `WebhookReceived` do Laravel |
| D5 | Ordem de configuração: `config.coffeemail` → `credentials.coffeemail` → `ENV` | Padrão do ecossistema Rails; o `ENV` mantém paridade com o Laravel (`COFFEEMAIL_*`) |
| D6 | Os headers de controle seguem os nomes do Laravel | Paridade: `X-CoffeeMail-Idempotency-Key`, `X-CoffeeMail-Sandbox` e `X-CoffeeMail-Scheduled-At` |

## 3. Configuração — `RB-RAILS-CFG`

| ID | Req. | Critério de aceite |
| --- | --- | --- |
| RB-RAILS-CFG-01 | [M] | O Railtie expõe `config.coffeemail` (`ActiveSupport::OrderedOptions`) com `api_key`, `locale`, `timeout`, `retry_policy`, `transport` (o ponto de injeção do SDK), `webhook_secret` e `webhook_tolerance` |
| RB-RAILS-CFG-02 | [M] | Cada valor é resolvido na ordem `config.coffeemail` → `Rails.application.credentials.coffeemail[...]` → `ENV` (`COFFEEMAIL_API_KEY`, `COFFEEMAIL_LOCALE`, `COFFEEMAIL_TIMEOUT`, `COFFEEMAIL_WEBHOOK_SECRET`, `COFFEEMAIL_WEBHOOK_TOLERANCE`). Os padrões são `pt-BR`, 10 s e 300 s |
| RB-RAILS-CFG-03 | [M] | `CoffeeMail::Rails.client` devolve um `CoffeeMail::Client` único por processo, criado de forma preguiçosa e thread-safe. `CoffeeMail::Rails.reset!` o descarta (para testes e recarga) |
| RB-RAILS-CFG-04 | [M] | Sem chave de API, a aplicação sobe normalmente; o `MissingApiKeyError` só aparece no primeiro uso do client ou da entrega |
| RB-RAILS-CFG-05 | [M] | Tolerância e timeout não numéricos caem no padrão sem quebrar o boot (paridade com o Laravel) |
| RB-RAILS-CFG-06 | [M] | Segredos (chave e webhook) nunca aparecem em `inspect`, em logs da gem nem em mensagens de erro |

## 4. Entrega pelo ActionMailer — `RB-RAILS-DLV`

| ID | Req. | Critério de aceite |
| --- | --- | --- |
| RB-RAILS-DLV-01 | [M] | `config.action_mailer.delivery_method = :coffeemail` entrega pelo `emails.send` do SDK. `config.action_mailer.coffeemail_settings` (`api_key`, `locale`, `timeout`) sobrepõe a configuração global para o mailer |
| RB-RAILS-DLV-02 | [M] | Remetente: o primeiro `From`, com nome de exibição (`{ email:, name: }`). Sem `From`, levanta `DeliveryError` sem chamar a API |
| RB-RAILS-DLV-03 | [M] | `To`, `Cc` e `Bcc` mantêm os nomes de exibição. Sem nenhum `To`, levanta `DeliveryError` sem chamar a API |
| RB-RAILS-DLV-04 | [M] | `Reply-To` usa o primeiro endereço. `Subject` é enviado como veio |
| RB-RAILS-DLV-05 | [M] | Corpo: `html_part` e `text_part` em multipart; em mensagem simples, o corpo vai para `html` ou `text` conforme o `Content-Type` |
| RB-RAILS-DLV-06 | [M] | Anexos viram `attachments` (`filename`, `content` em base64, `content_type`, `disposition` `attachment`/`inline` e `cid` sem `<>` nos inline), compatíveis com `attachments.inline[...]` do Rails |
| RB-RAILS-DLV-07 | [M] | Headers de controle: `X-CoffeeMail-Idempotency-Key` (ou `Idempotency-Key`) vira `idempotency_key:`, `X-CoffeeMail-Sandbox` (booleano) vira `sandbox:` e `X-CoffeeMail-Scheduled-At` vira `scheduled_at:`. Nenhum deles segue como header custom |
| RB-RAILS-DLV-08 | [M] | Os demais headers custom vão em `headers`, exceto os MIME padrão (`From`, `To`, `Cc`, `Bcc`, `Reply-To`, `Subject`, `Content-Type`, `MIME-Version`, `Date`, `Message-ID`, `Content-Transfer-Encoding`) |
| RB-RAILS-DLV-09 | [M] | No sucesso, `mail.message_id` recebe o id devolvido pela API |
| RB-RAILS-DLV-10 | [M] | Na falha, levanta `CoffeeMail::Rails::DeliveryError` com a mensagem e o código do SDK e o `CoffeeMail::Error` original em `#error` e em `cause`. Com `raise_delivery_errors = false`, o ActionMailer engole a exceção (comportamento nativo) |
| RB-RAILS-DLV-11 | [S] | `deliver_later` funciona sem configuração extra, porque a entrega roda no job do ActiveJob |

## 5. Webhooks — `RB-RAILS-WHK`

| ID | Req. | Critério de aceite |
| --- | --- | --- |
| RB-RAILS-WHK-01 | [M] | `CoffeeMail::Rails::WebhookApp` é uma Rack app montável: `mount CoffeeMail::Rails::WebhookApp.new, at: "/webhooks/coffeemail"` |
| RB-RAILS-WHK-02 | [M] | A verificação usa `CoffeeMail::Webhook.from_rack` do SDK com `webhook_secret` e `webhook_tolerance`. Não há segunda implementação de HMAC |
| RB-RAILS-WHK-03 | [M] | Respostas: `204` quando a entrega é válida, `401` com assinatura ausente, inválida ou expirada, `400` com payload que não é JSON e `500` sem segredo configurado. Só aceita `POST` (`405` nos demais) |
| RB-RAILS-WHK-04 | [M] | Entrega válida publica `ActiveSupport::Notifications.instrument("webhook.coffeemail", event:, idempotency_key:, test:)`, com o `CoffeeMail::Webhook::Event` do SDK |
| RB-RAILS-WHK-05 | [M] | `CoffeeMail::Rails.on_webhook(*event_types) { |event, payload| ... }` assina o evento filtrando por tipo (sem tipos, recebe todos) e devolve o subscriber para `unsubscribe` |
| RB-RAILS-WHK-06 | [M] | Uma exceção num subscriber não vira `204`: a app responde `500`, para que a API retente a entrega (até 5 vezes) |

## 6. Gerador — `RB-RAILS-GEN`

| ID | Req. | Critério de aceite |
| --- | --- | --- |
| RB-RAILS-GEN-01 | [M] | `bin/rails g coffeemail:install` cria `config/initializers/coffeemail.rb` com `config.coffeemail` lendo de `credentials` e `ENV` |
| RB-RAILS-GEN-02 | [M] | O gerador adiciona a rota `mount CoffeeMail::Rails::WebhookApp.new, at: "/webhooks/coffeemail"` e é idempotente (rodar duas vezes não duplica nada) |
| RB-RAILS-GEN-03 | [S] | `--delivery-method` também define `config.action_mailer.delivery_method = :coffeemail` em `config/environments/production.rb` |

## 7. Qualidade e release — `RB-RAILS-QA`

| ID | Req. | Critério de aceite |
| --- | --- | --- |
| RB-RAILS-QA-01 | [M] | O CI roda nas matrizes Rails 7.1, 7.2 e 8.0 × Ruby 3.3 e estável, com um app dummy em `spec/dummy` |
| RB-RAILS-QA-02 | [M] | Os mesmos gates do SDK: cops da casa, RuboCop, RBS + Steep strict, cobertura 85/78, `check-spec-coverage`, `check-version-sync`, `check-api-compat` e `bundler-audit` |
| RB-RAILS-QA-03 | [M] | Teste de ponta a ponta no app dummy: `deliver_now` com transporte falso do SDK valida o payload completo contra o schema de `POST /emails` do snapshot OpenAPI do SDK |
| RB-RAILS-QA-04 | [M] | README no roteiro único, CHANGELOG, arquivos de comunidade e `AGENTS.md`, sem citar repositório privado |
| RB-RAILS-QA-05 | [M] | Release por tag com trusted publishing, igual ao SDK. **A tag só é criada com autorização** |

## 8. Fora do escopo

- Inbound e Action Mailbox: a API não recebe e-mail.
- Templates do CoffeeMail como views do ActionMailer: o mailer pode passar `X-CoffeeMail-Template-Id` como dívida [S] futura, se houver demanda.
- Docs web: a página `docs/sdk/rails` fica para depois da 0.1.0 do SDK, no mesmo PR do web que publicar o SDK Ruby.

## 9. Aprovação

- [x] SPEC aprovado em 2026-10-14 (libera a implementação)
