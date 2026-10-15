# frozen_string_literal: true

class FakeTransport
  attr_reader :requests

  def initialize(status = 202, body = { "id" => "e1", "status" => "queued", "queuedAt" => "2026-10-14T10:00:00Z" })
    @status = status
    @body = body
    @requests = []
  end

  def call(request)
    @requests << request
    CoffeeMail::HttpResponse.new(status: @status, headers: {}, body: JSON.generate(@body))
  end

  def last_body = JSON.parse(requests.last.body)
end

module TransportHelpers
  def use_transport(transport)
    CoffeeMail::Rails.configuration.options.transport = transport
    CoffeeMail::Rails.reset!
    transport
  end
end

RSpec.configure { |config| config.include TransportHelpers }
