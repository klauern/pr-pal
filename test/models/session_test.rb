require "test_helper"

class SessionTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @valid_attributes = {
      user: @user,
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    }
    @session = Session.new(@valid_attributes)
  end

  # Association tests
  test "belongs to user" do
    assert_respond_to @session, :user
    assert_instance_of User, @session.user
  end

  # Basic validation tests
  test "should be valid with valid attributes" do
    assert @session.valid?
  end

  test "should require user" do
    @session.user = nil
    assert_not @session.valid?
    # User presence is enforced by belongs_to association
  end

  test "should be valid without ip_address" do
    @session.ip_address = nil
    assert @session.valid?
  end

  test "should be valid without user_agent" do
    @session.user_agent = nil
    assert @session.valid?
  end

  test "should be valid with empty ip_address" do
    @session.ip_address = ""
    assert @session.valid?
  end

  test "should be valid with empty user_agent" do
    @session.user_agent = ""
    assert @session.valid?
  end

  # IP Address edge cases
  test "handles various IP address formats" do
    valid_ips = [
      "192.168.1.1",           # Standard IPv4
      "10.0.0.1",              # Private IPv4
      "127.0.0.1",             # Localhost IPv4
      "255.255.255.255",       # Max IPv4
      "0.0.0.0",               # Min IPv4
      "2001:0db8:85a3:0000:0000:8a2e:0370:7334", # IPv6
      "::1",                   # IPv6 localhost
      "fe80::1",               # IPv6 link-local
      "invalid-ip"             # Invalid but stored as string
    ]

    valid_ips.each do |ip|
      @session.ip_address = ip
      assert @session.valid?, "IP address '#{ip}' should be valid (stored as string)"
    end
  end

  test "handles very long ip_address" do
    @session.ip_address = "a" * 1000
    assert @session.valid?
  end

  test "handles special characters in ip_address" do
    @session.ip_address = "192.168.1.1; DROP TABLE sessions; --"
    assert @session.valid?
  end

  # User Agent edge cases
  test "handles various user agent strings" do
    user_agents = [
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 14_4 like Mac OS X)",
      "curl/7.68.0",
      "PostmanRuntime/7.26.8",
      "", # Empty string
      nil, # Null value
      "a" * 5000 # Very long string
    ]

    user_agents.each do |ua|
      @session.user_agent = ua
      assert @session.valid?, "User agent should be valid: #{ua&.truncate(50)}"
    end
  end

  test "handles user agent with special characters" do
    @session.user_agent = "User-Agent: <script>alert('xss')</script>"
    assert @session.valid?
  end

  test "handles user agent with unicode characters" do
    @session.user_agent = "Mozilla/5.0 (测试浏览器) 🦄"
    assert @session.valid?
  end

  # Multiple sessions per user
  test "allows multiple sessions for same user" do
    session1 = Session.create!(@valid_attributes)
    session2 = Session.create!(@valid_attributes.merge(ip_address: "10.0.0.1"))

    assert_equal @user, session1.user
    assert_equal @user, session2.user
    assert_not_equal session1.id, session2.id
  end

  test "allows multiple sessions with same IP for different users" do
    other_user = users(:two)

    session1 = Session.create!(@valid_attributes)
    session2 = Session.create!(@valid_attributes.merge(user: other_user))

    assert_equal session1.ip_address, session2.ip_address
    assert_not_equal session1.user, session2.user
  end

  # Authentication security edge cases
  test "tracks session creation timestamps" do
    travel_to Time.current do
      @session.save!
      assert_in_delta Time.current, @session.created_at, 1.second
      assert_in_delta Time.current, @session.updated_at, 1.second
    end
  end

  test "updates timestamp on session update" do
    @session.save!
    original_updated_at = @session.updated_at

    travel 1.hour do
      @session.update!(ip_address: "10.0.0.1")
      assert @session.updated_at > original_updated_at
    end
  end

  # Session hijacking prevention scenarios
  test "can identify potential session hijacking by IP change" do
    @session.save!
    original_ip = @session.ip_address

    # Simulate IP address change (potential hijacking)
    @session.update!(ip_address: "completely.different.ip.address")

    assert_not_equal original_ip, @session.ip_address
    # In a real app, this would trigger security alerts
  end

  test "can identify potential session hijacking by user agent change" do
    @session.save!
    original_ua = @session.user_agent

    # Simulate user agent change (potential hijacking)
    @session.update!(user_agent: "Completely Different Browser/1.0")

    assert_not_equal original_ua, @session.user_agent
    # In a real app, this would trigger security alerts
  end

  # Concurrent session handling
  test "supports concurrent sessions for same user" do
    # Simulate user logging in from multiple devices
    desktop_session = Session.create!(@valid_attributes.merge(
      ip_address: "192.168.1.100",
      user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    ))

    mobile_session = Session.create!(@valid_attributes.merge(
      ip_address: "192.168.1.101",
      user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 14_4)"
    ))

    tablet_session = Session.create!(@valid_attributes.merge(
      ip_address: "192.168.1.102",
      user_agent: "Mozilla/5.0 (iPad; CPU OS 14_4 like Mac OS X)"
    ))

    user_sessions = Session.where(user: @user)
    assert user_sessions.count >= 3
    assert_includes user_sessions, desktop_session
    assert_includes user_sessions, mobile_session
    assert_includes user_sessions, tablet_session
  end

  # Data integrity and constraints
  test "requires valid user_id" do
    @session.user_id = 999999 # Non-existent user
    assert_not @session.valid?
  end

  test "cascades deletion when user is deleted" do
    @session.save!
    user_id = @user.id

    assert_difference "Session.count", -1 do
      @user.destroy
    end

    assert_nil Session.find_by(user_id: user_id)
  end

  # Performance and scaling considerations
  test "can handle large number of sessions per user" do
    # Test that we can create many sessions without performance issues
    sessions = []
    50.times do |i|
      sessions << Session.create!(@valid_attributes.merge(
        ip_address: "192.168.1.#{i}",
        user_agent: "TestAgent/#{i}"
      ))
    end

    user_sessions = Session.where(user: @user)
    assert user_sessions.count >= 50
  end

  # Security attack scenarios
  test "handles SQL injection attempts in ip_address" do
    malicious_ips = [
      "'; DROP TABLE sessions; --",
      "192.168.1.1'; UPDATE users SET email='hacker@evil.com'; --",
      "' OR '1'='1",
      "192.168.1.1' UNION SELECT * FROM users --"
    ]

    malicious_ips.each do |ip|
      @session.ip_address = ip
      assert @session.valid?, "Should handle malicious IP: #{ip}"

      # Ensure we can save without SQL injection
      @session.save!
      saved_session = Session.find(@session.id)
      assert_equal ip, saved_session.ip_address
    end
  end

  test "handles XSS attempts in user_agent" do
    malicious_uas = [
      "<script>alert('xss')</script>",
      "javascript:alert('xss')",
      "<img src=x onerror=alert('xss')>",
      "Mozilla/5.0 <script>document.location='http://evil.com'</script>"
    ]

    malicious_uas.each do |ua|
      @session.user_agent = ua
      assert @session.valid?, "Should handle malicious UA: #{ua.truncate(50)}"

      @session.save!
      saved_session = Session.find(@session.id)
      assert_equal ua, saved_session.user_agent
    end
  end

  # Rate limiting scenarios
  test "can track rapid session creation for rate limiting" do
    # Simulate rapid session creation (potential brute force)
    start_time = Time.current

    travel_to start_time do
      10.times do |i|
        Session.create!(@valid_attributes.merge(
          ip_address: "192.168.1.#{i}",
          user_agent: "RapidClient/#{i}"
        ))
      end
    end

    # Check that sessions were created for this user
    user_sessions = Session.where(user: @user)

    assert user_sessions.count >= 10
    # In a real app, this would trigger rate limiting
  end

  # Anonymous/guest session handling
  test "handles sessions with minimal information" do
    minimal_session = Session.new(user: @user)
    assert minimal_session.valid?

    minimal_session.save!
    assert_nil minimal_session.ip_address
    assert_nil minimal_session.user_agent
  end

  # Cross-browser compatibility
  test "handles various browser user agents" do
    browser_uas = {
      chrome: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      firefox: "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0",
      safari: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15",
      edge: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.59",
      mobile_chrome: "Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36",
      mobile_safari: "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Mobile/15E148 Safari/604.1"
    }

    browser_uas.each do |browser, ua|
      session = Session.create!(@valid_attributes.merge(
        user_agent: ua,
        ip_address: "192.168.1.#{browser.to_s.sum}" # Unique IP for each
      ))

      assert session.valid?
      assert_equal ua, session.user_agent
    end
  end

  # Debugging and logging scenarios
  test "provides useful information for debugging" do
    @session.save!

    # Should be able to identify session details for debugging
    assert_not_nil @session.id
    assert_not_nil @session.user_id
    assert_equal @user.id, @session.user_id
    assert_not_nil @session.created_at
    assert_not_nil @session.updated_at
  end

  test "maintains referential integrity" do
    @session.save!
    session_id = @session.id

    # Session should be findable
    found_session = Session.find(session_id)
    assert_equal @session.user_id, found_session.user_id
    assert_equal @session.ip_address, found_session.ip_address
    assert_equal @session.user_agent, found_session.user_agent
  end
end
