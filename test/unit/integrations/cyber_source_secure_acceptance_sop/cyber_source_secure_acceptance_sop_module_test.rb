require 'test_helper'

class CyberSourceSecureAcceptanceSopTest < Test::Unit::TestCase
  include OffsitePayments::Integrations

  def test_notification_method
    assert_instance_of CyberSourceSecureAcceptanceSop::Notification, CyberSourceSecureAcceptanceSop.notification('name=cody')
  end
end
