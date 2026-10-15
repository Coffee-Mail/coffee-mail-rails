# Contribuindo com o CoffeeMail Rails

Obrigado pelo interesse! Este guia resume como propor mudanças.

## Antes de começar

- Bugs e sugestões: abra uma issue usando um dos modelos.
- Vulnerabilidades: **não** abra issue pública; siga o [SECURITY.md](SECURITY.md).
- Mudanças grandes ou que alterem a API pública: abra uma issue para discussão antes do PR.

## Ambiente

- Ruby 3.3 ou superior. Até a 0.1.0 do SDK ser publicada, clone `coffee-mail-sdk-ruby` ao lado deste repositório (ou defina `COFFEEMAIL_SDK_PATH`).
- `RAILS_VERSION="~> 7.1.0" bundle update rails` troca a versão do Rails testada.
- `bundle install` e depois `bundle exec rake`, que precisa passar antes de qualquer PR. Ele roda as regras da casa, o RuboCop, o RBS com Steep em modo strict, os testes com cobertura mínima (85% de linhas e 78% de branches), a conformidade das requisições com o OpenAPI, a rastreabilidade do SPEC, a sincronização de versão e a compatibilidade da API pública.

## Desenvolvimento guiado por especificação

O comportamento do SDK é definido em [`specs/SPEC.md`](specs/SPEC.md), com requisitos numerados (`RB-RAILS-*`).

1. Comportamento novo ou alterado começa por um requisito no SPEC, com critério de aceite verificável.
2. O teste vem antes do código e o nome começa pelo ID: `it "RB-RAILS-DLV-07 headers de controle viram opções do SDK"`.
3. `bin/check-spec-coverage` falha se um requisito ficar sem teste ou se um teste citar um ID inexistente. `bin/check-spec-coverage --report` mostra a matriz de rastreabilidade.

## Regras de código

O SDK segue as regras de código da CoffeeMail, verificadas pelos cops em `rubocop/cop/coffeemail/`:

- Código em inglês; documentação, issues, commits e PRs em português do Brasil.
- Sem comentários, exceto o magic comment `frozen_string_literal` e YARD na API pública. `# rubocop:disable` também é comentário: exceções ficam no `.rubocop.yml`, com justificativa.
- Sem `else`, `elsif` e `case`: use retorno antecipado ou tabelas (`Hash#fetch`).
- Profundidade máxima 3, contando blocos.
- `raise` só no delivery method (é o contrato do ActionMailer) e `rescue` só na webhook app (exceção de subscriber vira `500`).
- Sem números e textos mágicos: use constantes congeladas.
- Sem saída em console na biblioteca.
- Cada comportamento novo vem com testes: caminho feliz e ao menos dois caminhos de erro.

## Compatibilidade

Mudanças na API pública devem **adicionar e depreciar**, nunca renomear ou remover. `bin/check-api-compat` compara as assinaturas RBS de `sig/` com as da última versão publicada.

## Mudanças no contrato da API

Mudanças de contrato entram primeiro no SDK `coffeemail`. Aqui, rode `bin/sync-spec` para atualizar o snapshot usado no teste de ponta a ponta do payload de `POST /emails`.

## Commits e PRs

- Mensagens em português, diretas, no formato `tipo(escopo): descrição` (ex.: `feat(emails): expõe metadata no envio`).
- Atualize o `CHANGELOG.md` na seção "Não lançado".
- Preencha o modelo de PR.
