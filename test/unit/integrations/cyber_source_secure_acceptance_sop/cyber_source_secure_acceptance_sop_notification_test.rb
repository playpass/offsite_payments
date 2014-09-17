require 'test_helper'

class CyberSourceSecureAcceptanceSopNotificationTest < Test::Unit::TestCase
  include OffsitePayments::Integrations

  def setup
    @cyber_source_secure_acceptance_sop = CyberSourceSecureAcceptanceSop::Notification.new(http_raw_data)
  end

  def test_accessors
    assert !@cyber_source_secure_acceptance_sop.complete?
    assert_equal 'REJECT', @cyber_source_secure_acceptance_sop.status
    assert_equal nil, @cyber_source_secure_acceptance_sop.transaction_id
    assert_equal '1000', @cyber_source_secure_acceptance_sop.item_id
    assert_equal '50.0', @cyber_source_secure_acceptance_sop.gross
    assert_equal 'aed', @cyber_source_secure_acceptance_sop.currency
    assert @cyber_source_secure_acceptance_sop.test?
  end

  def test_compositions
    assert_equal Money.new(5000, 'aed'), @cyber_source_secure_acceptance_sop.amount
  end

  def test_reason_code
    assert_equal '102', @cyber_source_secure_acceptance_sop.reason_code
  end

  def test_reason
    assert_equal 'One or more fields contains invalid data', @cyber_source_secure_acceptance_sop.reason
  end

  def test_missing_fields
    assert_equal 4, @cyber_source_secure_acceptance_sop.missing_fields.size
  end

  def test_invalid_fields
    assert_equal 1, @cyber_source_secure_acceptance_sop.invalid_fields.size
  end

  private

  def http_raw_data
    'InvalidField0=card_expirationYear&MissingField0=billTo_firstName&MissingField1=billTo_lastName&MissingField2=card_accountNumber&MissingField3=card_cvNumber&action=decline&authenticity_token=Arg5c5bL8t06pvfcQzVgD1B8jtKbLCXXOL2PcNlRORI%3D&billTo_city=na&billTo_country=na&billTo_street1=na&card_cardType=001&card_expirationMonth=1&card_expirationYear=2013&ccAuthReply_reasonCode=102&controller=payments&decision=REJECT&decision_publicSignature=WERCWEVhQ1YyiSJ9lqX7O5ujjeQ%3D&id=1000&merchantID=merchant_id&orderAmount=50.0&orderAmount_publicSignature=a1VZMu3PdP1jh6isxwgOceFaGTI%3D&orderCurrency=aed&orderCurrency_publicSignature=WiTgGFp3QCRA0AtyLZ6nrfQWzkM%3D&orderNumber=1000&orderNumber_publicSignature=XTk10QN1eQKeHU4kAT9otf6hm%2Bc%3D&orderPage_environment=TEST&orderPage_serialNumber=3624051261000176056165&orderPage_transactionType=sale&paymentOption=card&reasonCode=102&signedDataPublicSignature=GPh8YBU%2FXVguO9fAdOpzSmhbioo%3D&signedFields=utf8%2Cauthenticity_token%2CorderAmount%2CbillTo_street1%2CorderAmount_publicSignature%2CorderPage_serialNumber%2CorderCurrency%2Cdecision%2Ccard_expirationYear%2CbillTo_city%2CorderCurrency_publicSignature%2CtaxAmount%2CorderPage_transactionType%2Cdecision_publicSignature%2CpaymentOption%2CbillTo_country%2CreasonCode%2CccAuthReply_reasonCode%2CorderPage_environment%2Ccard_expirationMonth%2CmerchantID%2CorderNumber_publicSignature%2CorderNumber%2Ccard_cardType&taxAmount=0.00&transactionSignature=vAq57vjdo%2Fm9iUmdkAKWghl9Zdk%3D&utf8='
  end
end
