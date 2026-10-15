# frozen_string_literal: true

require "base64"

module CoffeeMail
  module Rails
    # @api private
    module MessageMapper
      IGNORED_HEADERS = %w[
        from to cc bcc reply-to subject content-type mime-version date message-id content-transfer-encoding
        content-id content-disposition return-path
      ].freeze
      IDEMPOTENCY_HEADERS = %w[x-coffeemail-idempotency-key idempotency-key].freeze
      SANDBOX_HEADER = "x-coffeemail-sandbox"
      SCHEDULED_AT_HEADER = "x-coffeemail-scheduled-at"
      CONTROL_HEADERS = [*IDEMPOTENCY_HEADERS, SANDBOX_HEADER, SCHEDULED_AT_HEADER].freeze
      TRUTHY = %w[true 1 yes on].freeze
      HTML_MIME = "text/html"
      INLINE = "inline"
      ATTACHMENT = "attachment"
      CID_DELIMITERS = "<>"

      Result = Data.define(:payload, :error_key)

      module_function

      def call(mail)
        from = addresses(mail, :from).first
        to = addresses(mail, :to)
        return Result.new(payload: nil, error_key: :MISSING_FROM) if from.nil?
        return Result.new(payload: nil, error_key: :MISSING_TO) if to.empty?

        Result.new(payload: payload(mail, from, to), error_key: nil)
      end

      def payload(mail, from, to)
        {
          from: from, to: to, cc: non_empty(addresses(mail, :cc)), bcc: non_empty(addresses(mail, :bcc)),
          reply_to: addresses(mail, :reply_to).first, subject: mail.subject, **bodies(mail),
          attachments: non_empty(attachments(mail)), headers: non_empty(custom_headers(mail)),
          **controls(mail)
        }.compact
      end

      def addresses(mail, field)
        header = mail[field]
        return [] if header.nil?

        Array(header.addrs).map { |addr| address(addr) }
      end

      def address(addr)
        name = addr.display_name.to_s.strip
        name.empty? ? { email: addr.address } : { email: addr.address, name: name }
      end

      def bodies(mail)
        parts = { html: mail.html_part&.decoded, text: mail.text_part&.decoded }
        return parts.compact if mail.multipart?

        key = mail.mime_type == HTML_MIME ? :html : :text
        { key => mail.body.decoded }
      end

      def attachments(mail)
        mail.attachments.map do |part|
          {
            filename: part.filename, content: Base64.strict_encode64(part.decoded), content_type: part.mime_type,
            disposition: part.inline? ? INLINE : ATTACHMENT, cid: part.inline? ? content_id(part) : nil
          }.compact
        end
      end

      def content_id(part)
        part.content_id.to_s.delete(CID_DELIMITERS).then { |cid| cid.empty? ? nil : cid }
      end

      def custom_headers(mail)
        mail.header.fields.each_with_object({}) do |field, headers|
          name = field.name.to_s
          next if (IGNORED_HEADERS + CONTROL_HEADERS).include?(name.downcase)

          headers[name] = field.value.to_s
        end
      end

      def controls(mail)
        {
          idempotency_key: IDEMPOTENCY_HEADERS.filter_map { |name| header_value(mail, name) }.first,
          sandbox: TRUTHY.include?(header_value(mail, SANDBOX_HEADER).to_s.strip.downcase) || nil,
          scheduled_at: header_value(mail, SCHEDULED_AT_HEADER),
        }.compact
      end

      def header_value(mail, name)
        field = mail.header[name]
        value = field&.value.to_s.strip
        value.nil? || value.empty? ? nil : value
      end

      def non_empty(collection)
        collection.empty? ? nil : collection
      end
    end
  end
end
