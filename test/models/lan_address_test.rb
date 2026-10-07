require "test_helper"

class LanAddressTest < ActiveSupport::TestCase
  test "is the first private IPv4 address" do
    addresses = [ Addrinfo.ip("127.0.0.1"), Addrinfo.ip("fe80::1"), Addrinfo.ip("192.168.1.5"), Addrinfo.ip("10.0.0.2") ]
    Socket.stub(:ip_address_list, addresses) { assert_equal "192.168.1.5", LanAddress.ip }
  end

  test "is nil off a local network" do
    Socket.stub(:ip_address_list, [ Addrinfo.ip("127.0.0.1") ]) { assert_nil LanAddress.ip }
  end
end
