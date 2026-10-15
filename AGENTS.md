# AGENTS.md

Orientações para agentes de código neste repositório. As regras completas estão no [CONTRIBUTING.md](CONTRIBUTING.md) e o comportamento esperado está em [`specs/SPEC.md`](specs/SPEC.md).

## Comandos

```bash
bundle exec rake                         # todos os gates
bundle exec rspec                        # testes no app dummy (spec/dummy)
RAILS_VERSION="~> 7.1.0" bundle update rails && bundle exec rspec
bundle exec steep check                  # tipos (rbs collection + sig/)
bin/check-spec-coverage [--report]       # rastreabilidade SPEC × testes
```

## Regras

- Spec-driven: requisito `RB-RAILS-*` no SPEC → teste com o ID no nome → implementação.
- Dentro de `CoffeeMail::Rails`, a constante `Rails` é o próprio módulo: use `::Rails` para o framework.
- Toda a comunicação com a API passa pelo SDK `coffeemail`; nada de HTTP ou HMAC próprios aqui.
- `raise` só no delivery method (contrato do ActionMailer); `rescue` só na webhook app.
- O Railtie e o gerador ficam fora do Steep (DSL do Rails sem tipos); o resto é estrito.
- A gem não define base URL nem guarda segredos em `inspect`.
- Sem comentários fora do YARD de API pública; sem `else`/`case`; profundidade ≤ 3.
- Documentação, commits e PRs em português do Brasil; código em inglês.
- Este repositório é público: não cite nem linke repositórios privados.
