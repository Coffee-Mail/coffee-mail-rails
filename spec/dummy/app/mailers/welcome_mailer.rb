# frozen_string_literal: true

class WelcomeMailer < ActionMailer::Base
  default from: "Minha App <app@exemplo.com.br>"

  def welcome(to:, headers: {}, attachment: nil, inline: nil)
    headers.each { |name, value| self.headers[name] = value }
    attachments[attachment.fetch(:filename)] = attachment.fetch(:content) if attachment
    attachments.inline[inline.fetch(:filename)] = inline.fetch(:content) if inline
    mail(to: to, cc: "Copia <copia@exemplo.com.br>", reply_to: "suporte@exemplo.com.br", subject: "Bem-vinda!")
  end

  def plain(to:)
    mail(to: to, subject: "Texto puro", body: "Olá em texto", content_type: "text/plain")
  end

  def anonymous
    mail(to: "ana@exemplo.com.br", from: nil, subject: "Sem remetente", body: "x")
  end

  def nobody
    mail(to: nil, subject: "Sem destinatário", body: "x")
  end
end
