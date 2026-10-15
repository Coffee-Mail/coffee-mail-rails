# frozen_string_literal: true

require "yaml"

RSpec.describe "Gates de qualidade e release" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:ci) { YAML.load_file(File.join(root, ".github/workflows/ci.yml")) }
  let(:release) { YAML.load_file(File.join(root, ".github/workflows/release.yml")) }
  let(:ci_runs) { ci.dig("jobs", "check", "steps").map { |step| step["run"].to_s }.join("\n") }

  it "RB-RAILS-QA-01 matriz Rails 7.1, 7.2 e 8.0 × Ruby 3.3 e estável com app dummy" do
    matrix = ci.dig("jobs", "check", "strategy", "matrix")

    expect(matrix["rails"]).to eq(["~> 7.1.0", "~> 7.2.0", "~> 8.0.0"])
    expect(matrix["ruby"]).to eq(%w[3.3 ruby])
    expect(Rails.application).to be_a(Dummy::Application)
  end

  it "RB-RAILS-QA-02 os mesmos gates do SDK rodam no CI" do
    gates = ["check-version-sync", "rubocop --only CoffeeMail", "steep check", "rspec", "check-spec-coverage",
             "check-api-compat"]

    expect(gates.reject { |gate| ci_runs.include?(gate) }).to be_empty
    expect(File.read(File.join(root, "spec/spec_helper.rb"))).to include("minimum_coverage line: 85, branch: 78")
    expect(ci.dig("jobs", "vulnerabilities", "steps").map { |step| step["run"].to_s }).to include(
      "bundle exec bundler-audit check --update",
    )
  end

  it "RB-RAILS-QA-04 README no roteiro único, arquivos de comunidade e sem repositório privado" do
    readme = File.read(File.join(root, "README.md"))
    sections = ["Visão geral", "Status do projeto", "Requisitos", "Instalação", "Início rápido", "Configuração",
                "Tratamento de erros", "Referência", "Webhooks", "Versionamento e releases", "Testes e qualidade",
                "Estrutura do repositório", "Contribuição", "Projetos relacionados", "Licença"]
    files = %w[LICENSE CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md CHANGELOG.md AGENTS.md]
    sources = Dir[File.join(root, "{lib,spec,sig,bin,tools,rubocop,.github}/**/*"), File.join(root, "*.md")]
              .select { |path| File.file?(path) }

    expect(sections.reject { |section| readme.match?(/^## .*#{Regexp.escape(section)}/) }).to be_empty
    expect(files.reject { |file| File.exist?(File.join(root, file)) }).to be_empty
    expect(sources.select { |path| File.read(path).scrub.match?(/coffee-mail-(?:a)pi|coffee-mail-(?:w)eb/) })
      .to be_empty
  end

  it "RB-RAILS-QA-05 release por tag com verificação de versão e trusted publishing" do
    steps = release.dig("jobs", "release", "steps")

    expect(release.dig(true, "push", "tags") || release.dig("on", "push", "tags")).to eq(["v*"])
    expect(release.fetch("permissions")).to include("id-token" => "write")
    expect(steps.map { |step| step["run"].to_s }.join).to include('bin/check-version-sync --tag "$GITHUB_REF_NAME"')
    expect(steps.map { |step| step["uses"] }).to include("rubygems/release-gem@v1")
  end
end
