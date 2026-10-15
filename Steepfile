# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature "sig"
  check "lib"
  ignore "lib/coffeemail/rails/railtie.rb", "lib/generators"
  collection_config "rbs_collection.yaml"
  library "json"
  configure_code_diagnostics(D::Ruby.strict) do |hash|
    hash[D::Ruby::UnannotatedEmptyCollection] = :hint
  end
end
