require 'hmac-sha2'
require 'base64'

module OffsitePayments #:nodoc:
  module Integrations #:nodoc:
    module CyberSourceSecureAcceptanceSop
      mattr_accessor :production_url, :test_url

      self.production_url = 'https://secureacceptance.cybersource.com/silent/pay'
      self.test_url = 'https://testsecureacceptance.cybersource.com/silent/pay'

      def self.service_url
        case OffsitePayments.mode
          when :production
            self.production_url
          when :test
            self.test_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{OffsitePayments.mode}"
        end
      end

      def self.notification(post)
        Notification.new(post)
      end

      class Helper < OffsitePayments::Helper
        mapping :account,  'profile_id'
        mapping :credential2, 'access_key'
        mapping :transaction_type, 'transaction_type'

        mapping :order,    'reference_number'
        mapping :currency, 'currency'
        mapping :amount,   'amount'
        mapping :ignore_avs, 'ignore_avs'
        mapping :version, 'version'


        mapping :customer,
            :first_name => 'bill_to_forename',
            :last_name  => 'bill_to_surname',
            :email      => 'bill_to_email',
            :phone      => 'bill_to_phone'

        mapping :billing_address,
            :city     => 'bill_to_address_city',
            :address1 => 'bill_to_address_line1',
            :address2 => 'bill_to_address_line2',
            :state    => 'bill_to_address_state',
            :country  => 'bill_to_address_country'

        mapping :shipping_address,
            :city     => 'ship_to_address_city',
            :address1 => 'ship_to_address_line1',
            :address2 => 'ship_to_address_line2',
            :state    => 'ship_to_address_state',
            :country  => 'ship_to_address_country'

        mapping :description, 'payment_token_comments'
        mapping :tax, 'tax_amount'

        mapping :credit_card,
            :number               => 'card_number',
            :expiry_date          => 'card_expiry_date',
            :verification_value   => 'card_cvn',
            :card_type            => 'card_type'

        mapping :notify_url, 'override_custom_receipt_page'

        # These are the options that need to be used with payment_service_for with the
        # :cyber_source_secure_acceptance_sop service
        #
        # * :profile_id => 'Your CyberSource Secure Acceptance Profile ID (UUID, caps, with dashes)'
        # * :access_key => 'Your CyberSource Secure Acceptance Profile security Access Key'
        # * :credential2 => 'Your CyberSource Secure Acceptance Profile security Secret Key'
        #
        # The following are optional data that you can specify but will be set to sensible
        # defaults if they're not specified
        #
        # * :transaction_type   default: 'sale', can be: 'sale', 'authorize'
        #                       Determines the type of transaction this will be.  There's no concept of
        #                       capture *after* an authorization so 'sale' will most likely work for you
        # * :ignore_avs         default: 'true', can be: 'true', 'false'
        #                       Whether or not to ignore the AVS code when processing this transaction
        def initialize(order, account, options = {})
          # TODO: require! is not raising exception as expected
          # requires!(options, :credential2)
          [:amount, :currency, :credential2, :secret_key].each do |key|
            unless options.has_key?(key)
              raise ArgumentError.new("Missing required parameter: #{key}")
            end
          end

          @secret_key = options.delete(:secret_key)
          @tax = options.delete(:tax)

          super

          unless options[:transaction_type].present?
            add_field('transaction_type', 'sale')
          end

          unless options[:version].present?
            add_field('version', '1')
          end

          if @tax.present?
            add_field('tax_amount', @tax.to_s)
          end

          insert_fixed_fields()
          insert_timestamp_field()
          insert_signature_public()
          insert_card_fields()
        end

        def valid_line_item?(item = {})
          item[:name].present? && item[:sku].present? && item[:unit_price].present?
        end

        def add_line_items(options = {})
          requires!(options, :line_items)

          valid_line_items = options[:line_items].select { |item| valid_line_item? item }
          add_field('line_item_count', valid_line_items.size)

          valid_line_items.each_with_index do |item, idx|
            tax_amount = (item[:tax_amount].present && item[:tax_amount] >= 0.0) ? item[:tax_amount] : '0.00'
            quantity = item[:quantity].present ? item[:quantity] : 1

            add_field("item_#{idx}_name", item[:name])
            add_field("item_#{idx}_sku", item[:sku])
            add_field("item_#{idx}_tax_amount", tax_amount)
            add_field("item_#{idx}_unit_price", item[:unit_price])
            add_field("item_#{idx}_quantity", quantity)
          end
        end

        def insert_timestamp_field
          add_field('signed_date_time', Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S%z').gsub(/\+\d{4}$/, 'Z'))
        end

        def insert_fixed_fields
          add_field('signed_field_names', 'access_key,amount,bill_to_email,currency,locale,payment_method,profile_id,reference_number,signed_date_time,signed_field_names,tax_amount,transaction_type,transaction_uuid,unsigned_field_names')
          add_field('unsigned_field_names', 'bill_to_address_city,bill_to_address_country,bill_to_address_line1,bill_to_forename,bill_to_surname,card_expiry_date,card_number,card_type,override_custom_receipt_page')
          add_field('payment_method', 'card')
          add_field('locale', 'en')
          add_field('transaction_uuid', SecureRandom.hex(16))
        end

        def insert_card_fields
          result = []
          result << "First Name: <input autocomplete=\"off\" type=\"text\" name=\"bill_to_forename\" />\n"
          result= result.join("\n")

          concat(result.respond_to?(:html_safe) ? result.html_safe : result)
        end

        def insert_signature_public
          add_field('signature', generate_signature)
        end

        private

        def generate_signature
          sign(signed_field_data)
        end

        def signed_field_data
          signed_field_names = @fields['signed_field_names'].split ','

          signed_field_names.map { |field| field + '=' + @fields[field].to_s }.join(',')
        end

        def sign(data)
          digest = OpenSSL::HMAC.digest('sha256', @secret_key, data)
          Base64.encode64(digest).gsub "\n", ''
        end
      end

      class Notification < OffsitePayments::Notification
        def complete?
          status == 'ACCEPT'
        end

        def item_id
          params['req_reference_number']
        end

        def transaction_id
          params['transaction_id']
        end

        def currency
          params['req_currency']
        end

        # When was this payment received by the client.
        def received_at
          Time.strptime(params['signed_date_time'], '%Y-%m-%dT%H%M%SZ')
        end

        def payer_email
          params['req_bill_to_email']
        end

        def receiver_email
          params['']
        end

        def security_key
          params['']
        end

        # the money amount we received in X.2 decimal.
        def gross
          params['req_amount']
        end

        # Was this a test transaction?
        def test?
          OffsitePayments.mode == :test
        end

        def status
          params['decision']
        end

        def missing_fields
          params.select{|key, value| key =~ /^MissingField/}.
              collect{|key, value| value}
        end

        def invalid_fields
          params.select{|key, value| key =~ /^InvalidField/}.
              collect{|key, value| value}
        end

        def reason
          @@response_codes[('r' + reason_code).to_sym]
        end

        def reason_code
          params['reason_code']
        end

        private

        def secret_key
          @options[:secret_key]
        end

        def valid?
          signature = generate_signature
          signature.strip.eql? params['signature'].strip
        end

        def generate_signature
          sign(signed_field_data, secret_key)
        end

        def signed_field_data
          signed_field_names = params['signed_field_names'].split ','

          signed_field_names.map { |field| field + '=' + params[field].to_s }.join(',')
        end

        def sign(data)
          mac = HMAC::SHA256.new secret_key
          mac.update data
          Base64.encode64(mac.digest).gsub "\n", ''
        end

        @@response_codes = {
            :r100 => "Successful transaction",
            :r101 => "Request is missing one or more required fields" ,
            :r102 => "One or more fields contains invalid data",
            :r150 => "General failure",
            :r151 => "The request was received but a server time-out occurred",
            :r152 => "The request was received, but a service timed out",
            :r200 => "The authorization request was approved by the issuing bank but declined by CyberSource because it did not pass the AVS check",
            :r201 => "The issuing bank has questions about the request",
            :r202 => "Expired card",
            :r203 => "General decline of the card",
            :r204 => "Insufficient funds in the account",
            :r205 => "Stolen or lost card",
            :r207 => "Issuing bank unavailable",
            :r208 => "Inactive card or card not authorized for card-not-present transactions",
            :r209 => "American Express Card Identifiction Digits (CID) did not match",
            :r210 => "The card has reached the credit limit",
            :r211 => "Invalid card verification number",
            :r221 => "The customer matched an entry on the processor's negative file",
            :r230 => "The authorization request was approved by the issuing bank but declined by CyberSource because it did not pass the card verification check",
            :r231 => "Invalid account number",
            :r232 => "The card type is not accepted by the payment processor",
            :r233 => "General decline by the processor",
            :r234 => "A problem exists with your CyberSource merchant configuration",
            :r235 => "The requested amount exceeds the originally authorized amount",
            :r236 => "Processor failure",
            :r237 => "The authorization has already been reversed",
            :r238 => "The authorization has already been captured",
            :r239 => "The requested transaction amount must match the previous transaction amount",
            :r240 => "The card type sent is invalid or does not correlate with the credit card number",
            :r241 => "The request ID is invalid",
            :r242 => "You requested a capture, but there is no corresponding, unused authorization record.",
            :r243 => "The transaction has already been settled or reversed",
            :r244 => "The bank account number failed the validation check",
            :r246 => "The capture or credit is not voidable because the capture or credit information has already been submitted to your processor",
            :r247 => "You requested a credit for a capture that was previously voided",
            :r250 => "The request was received, but a time-out occurred with the payment processor",
            :r254 => "Your CyberSource account is prohibited from processing stand-alone refunds",
            :r255 => "Your CyberSource account is not configured to process the service in the country you specified"
        }

        # Take the posted data and move the relevant data into a hash
        def old_parse(post)
          @raw = post
          for line in post.split('&')
            key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
            params[key] = value
          end
        end
      end
    end
  end
end
