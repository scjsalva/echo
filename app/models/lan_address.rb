# The Mac's address on the local network, so a phone on the same Wi-Fi can
# open Echo from a QR code. Nil when there's no private IPv4 address.
module LanAddress
  def self.ip = Socket.ip_address_list.find { it.ipv4_private? }&.ip_address
end
