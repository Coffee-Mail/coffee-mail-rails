# frozen_string_literal: true

require "ripper"
require "tmpdir"
require "rails/generators"
require_relative "../lib/generators/coffeemail/install/install_generator"

RSpec.describe Coffeemail::Generators::InstallGenerator do
  let(:root) { Dir.mktmpdir }

  before do
    FileUtils.mkdir_p(File.join(root, "config/environments"))
    File.write(File.join(root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
    File.write(File.join(root, "config/environments/production.rb"), "Rails.application.configure do\nend\n")
  end

  after { FileUtils.remove_entry(root) }

  def run_generator(*args)
    described_class.start(args, destination_root: root, quiet: true)
  end

  def read(path) = File.read(File.join(root, path))

  it "RB-RAILS-GEN-01 cria o initializer com credentials e ENV" do
    run_generator
    initializer = read("config/initializers/coffeemail.rb")

    expect(initializer).to include("config.coffeemail.api_key", "credentials.dig(:coffeemail, :api_key)",
                                   "COFFEEMAIL_WEBHOOK_SECRET")
    expect(Ripper.sexp(initializer)).not_to be_nil
  end

  it "RB-RAILS-GEN-02 monta a rota do webhook sem duplicar ao rodar de novo" do
    2.times { run_generator }

    expect(read("config/routes.rb").scan("CoffeeMail::Rails::WebhookApp").size).to eq(1)
    expect(read("config/routes.rb")).to include('mount CoffeeMail::Rails::WebhookApp.new, at: "/webhooks/coffeemail"')
  end

  it "RB-RAILS-GEN-03 --delivery-method configura produção uma única vez" do
    run_generator
    without_flag = read("config/environments/production.rb")
    2.times { run_generator("--delivery-method") }

    expect(without_flag).not_to include("delivery_method")
    expect(read("config/environments/production.rb").scan("delivery_method = :coffeemail").size).to eq(1)
  end
end
