require 'test_helper'

class CyberSourceSecureAcceptanceSopHelperTest < Test::Unit::TestCase
  include OffsitePayments::Integrations

  def setup
    @helper = CyberSourceSecureAcceptanceSop::Helper.new('order-500','CyberSource_TestID',
        :amount => 500, :currency => 'AED', :credential2 => 'Test_serialNumber', :shared_secret => 'Test_sharedSecret')
  end

  def test_basic_helper_fields
    assert_field 'merchantID', 'CyberSource_TestID'
    assert_field 'orderPage_serialNumber', 'Test_serialNumber'
    assert_field 'currency', 'AED'
    assert_field 'amount', '500'
    assert_field 'orderNumber', 'order-500'
    assert_field 'orderPage_timestamp', @helper.get_microtime()
    assert_field 'orderPage_transactionType', 'sale'
    assert_field 'orderPage_ignoreAVS', 'true'
    assert_field 'orderPage_version', '7'
    assert_field 'orderPage_sendMerchantURLPost', 'true'
    assert_field 'billTo_country', 'na'
    assert_field 'billTo_city', 'na'
    assert_field 'billTo_street1', 'na'
    assert_field 'billTo_firstName', nil
  end

  def test_signature_public_field
    assert_field 'orderPage_signaturePublic', @helper.sop_hash()
  end

  def test_missing_credential2_mapping
    assert_raise ArgumentError do
      CyberSourceSecureAcceptanceSop::Helper.new('order-500', 'CyberSource_TestID',
          { :amount => 500, :currency => 'AED',
              :shared_secret => 'Test_sharedSecret'})
    end
  end

  def test_missing_shared_secret
    assert_raise ArgumentError do
      CyberSourceSecureAcceptanceSop::Helper.new('order-500', 'CyberSource_TestID',
          { :amount => 500, :currency => 'AED',
              :shared_secret => 'Test_sharedSecret'})
    end
  end

  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser',
        :email => 'cody@example.com', phone: '(555)555-5555'
    assert_field 'billTo_firstName', 'Cody'
    assert_field 'billTo_lastName', 'Fauser'
    assert_field 'billTo_email', 'cody@example.com'
    assert_field 'billTo_phoneNumber', '(555)555-5555'
  end

  def test_billing_address_mapping
    @helper.billing_address :address1 => '1 My Street',
        :address2 => '',
        :city => 'Leeds',
        :state => 'Yorkshire',
        :country  => 'CA'

    assert_field 'billTo_street1', '1 My Street'
    assert_field 'billTo_city', 'Leeds'
    assert_field 'billTo_state', 'Yorkshire'
    assert_field 'billTo_country', 'CA'
  end

  def test_shipping_address_mapping
    @helper.shipping_address :address1 => '1 My Street',
        :address2 => '',
        :city => 'Leeds',
        :state => 'Yorkshire',
        :country  => 'CA'

    assert_field 'shipTo_street1', '1 My Street'
    assert_field 'shipTo_city', 'Leeds'
    assert_field 'shipTo_state', 'Yorkshire'
    assert_field 'shipTo_country', 'CA'
  end

  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
  end

  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    @helper.billing_address :street => 'My Street'
    assert_equal fields, @helper.fields
  end
end
