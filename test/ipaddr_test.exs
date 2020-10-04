defmodule IPAddrTest do
  use ExUnit.Case

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "can parse IPv4 addresses and ranges" do
    assert IPAddr.new("10.12.100.200") == %IPAddr{family: :ipv4, ip: {10, 12, 100, 200}, mask: 32}
    assert IPAddr.new("192.168.1.0/24") == %IPAddr{family: :ipv4, ip: {192, 168, 1, 0}, mask: 24}
    assert IPAddr.new("192.168.1.10/24") == %IPAddr{family: :ipv4, ip: {192, 168, 1, 0}, mask: 24}
    assert IPAddr.new("192.168.1.10/16") == %IPAddr{family: :ipv4, ip: {192, 168, 0, 0}, mask: 16}
    assert IPAddr.new("192.168.1.10/8") == %IPAddr{family: :ipv4, ip: {192, 0, 0, 0}, mask: 8}
    assert IPAddr.new("192.168.1.10/0") == %IPAddr{family: :ipv4, ip: {0, 0, 0, 0}, mask: 0}
  end

  test "can parse IPv6 addresses and ranges" do
    assert IPAddr.new("5678:abcd::123:456") == %IPAddr{family: :ipv6, ip: {22136, 43981, 0, 0, 0, 0, 291, 1110}, mask: 128}
    assert IPAddr.new("2001:abcd:1234::/48") == %IPAddr{family: :ipv6, ip: {8193, 43981, 4660, 0, 0, 0, 0, 0}, mask: 48}
    assert IPAddr.new("2001:abcd:1234::2/48") == %IPAddr{family: :ipv6, ip: {8193, 43981, 4660, 0, 0, 0, 0, 0}, mask: 48}
  end

  test "can convert an integer to an IP address tuple" do
    assert IPAddr.from_integer(3232238081, :ipv4) == %IPAddr{family: :ipv4, ip: {192, 168, 10, 1}, mask: 32}
    assert IPAddr.from_integer(3232238081, :ipv4, 24) == %IPAddr{family: :ipv4, ip: {192, 168, 10, 0}, mask: 24}
    assert IPAddr.from_integer(1, :ipv4) == %IPAddr{family: :ipv4, ip: {0, 0, 0, 1}, mask: 32}
    assert IPAddr.from_integer(42543972701425385287337697859424437607, :ipv6) == IPAddr.new("2001:abcd:1234:5678:90ab:cdef:123:4567")
    assert IPAddr.from_integer(42543972701425385287337697859424437607, :ipv6, 64) == IPAddr.new("2001:abcd:1234:5678::/64")
    assert IPAddr.from_integer(1, :ipv6) == %IPAddr{family: :ipv6, ip: {0, 0, 0, 0, 0, 0, 0, 1}, mask: 128}
  end

  test "can recognize an IPv4 address tuple or map" do
    assert IPAddr.ipv4?(%IPAddr{family: :ipv4, ip: {10, 100, 200, 5}, mask: 32}) == true
    assert IPAddr.ipv4?(%IPAddr{family: :ipv4, ip: {10, 100, 200, 5}, mask: 40}) == false
    assert IPAddr.ipv4?(%IPAddr{family: :ipv4, ip: {10, 100, 299, 5}, mask: 32}) == false
    assert IPAddr.ipv4?(%IPAddr{family: :ipv4, ip: {10, 100, 200, 5, 50}, mask: 32}) == false
  end

  test "can recognize an IPv6 address tuple or map" do
    assert IPAddr.ipv6?(%IPAddr{family: :ipv6, ip: {8193, 43981, 4321, 56789, 0, 0, 2}, mask: 128}) == false
    assert IPAddr.ipv6?(%IPAddr{family: :ipv6, ip: {8193, 43981, 4321, 56789, 0, 0, 2, 1234}, mask: 128}) == true
    assert IPAddr.ipv6?(%IPAddr{family: :ipv6, ip: {8193, 43981, 4321, 56789, 0, 0, 2, 1234}, mask: 130}) == false
    assert IPAddr.ipv6?(%IPAddr{family: :ipv6, ip: {8193, 43981, 4321, 56789, 0, 0, 2, 1234, 0}, mask: 128}) == false
  end

  test "can return the identity mask for an IP address tuple or map" do
    assert IPAddr.identity({192, 168, 10, 1}) == 32
    assert IPAddr.identity(%IPAddr{family: :ipv4, ip: {192, 168, 10, 0}, mask: 24}) == 32
    assert IPAddr.identity({8193, 43981, 1234, 5678, 0, 0, 0, 2}) == 128
    assert IPAddr.identity(%IPAddr{family: :ipv6, ip: {8193, 43981, 1234, 5678, 0, 0, 0, 0}, mask: 64}) == 128
  end

  test "can recognize identity mask for an IP address map" do
    assert IPAddr.identity?(%IPAddr{family: :ipv4, ip: {192, 168, 10, 1}, mask: 32}) == true
    assert IPAddr.identity?(%IPAddr{family: :ipv4, ip: {192, 168, 10, 0}, mask: 24}) == false
    assert IPAddr.identity?(%IPAddr{family: :ipv6, ip: {8193, 43981, 1234, 5678, 0, 0, 0, 2}, mask: 128}) == true
    assert IPAddr.identity?(%IPAddr{family: :ipv6, ip: {8193, 43981, 1234, 5678, 0, 0, 0, 0}, mask: 64}) == false
  end

  test "can calculate the max IP address in a range" do
    assert IPAddr.max(%IPAddr{family: :ipv4, ip: {192, 168, 10, 99}, mask: 32}) == %IPAddr{family: :ipv4, ip: {192, 168, 10, 99}, mask: 32}
    assert IPAddr.max(%IPAddr{family: :ipv4, ip: {192, 168, 10, 0}, mask: 24}) == %IPAddr{family: :ipv4, ip: {192, 168, 10, 255}, mask: 32}
    assert IPAddr.max(%IPAddr{family: :ipv4, ip: {192, 168, 192, 0}, mask: 20}) == %IPAddr{family: :ipv4, ip: {192, 168, 207, 255}, mask: 32}
    assert IPAddr.max(%IPAddr{family: :ipv4, ip: {192, 168, 0, 0}, mask: 16}) == %IPAddr{family: :ipv4, ip: {192, 168, 255, 255}, mask: 32}
    assert IPAddr.max(%IPAddr{family: :ipv4, ip: {192, 0, 0, 0}, mask: 9}) == %IPAddr{family: :ipv4, ip: {192, 127, 255, 255}, mask: 32}
    assert IPAddr.max(%IPAddr{family: :ipv4, ip: {192, 128, 0, 0}, mask: 9}) == %IPAddr{family: :ipv4, ip: {192, 255, 255, 255}, mask: 32}
    assert IPAddr.max(%IPAddr{family: :ipv4, ip: {192, 0, 0, 0}, mask: 8}) == %IPAddr{family: :ipv4, ip: {192, 255, 255, 255}, mask: 32}
    assert IPAddr.max(%IPAddr{family: :ipv6, ip: {8193, 43981, 4321, 56789, 0, 0, 2, 1234}, mask: 128}) == %IPAddr{family: :ipv6, ip: {8193, 43981, 4321, 56789, 0, 0, 2, 1234}, mask: 128}
  end

  test "can calculate intersection of two ranges" do
    assert IPAddr.include?(%IPAddr{family: :ipv4, ip: {192, 168, 10, 0}, mask: 24}, %IPAddr{family: :ipv4, ip: {192, 168, 10, 99}, mask: 32}) == true
    assert IPAddr.include?(%IPAddr{family: :ipv4, ip: {192, 168, 10, 0}, mask: 24}, %IPAddr{family: :ipv4, ip: {192, 168, 11, 99}, mask: 32}) == false
    assert IPAddr.include?(%IPAddr{family: :ipv4, ip: {192, 168, 0, 0}, mask: 16}, %IPAddr{family: :ipv4, ip: {192, 168, 10, 0}, mask: 24}) == true
    assert IPAddr.include?(%IPAddr{family: :ipv6, ip: {8193, 43981, 4321, 56789, 0, 0, 0, 0}, mask: 64}, %IPAddr{family: :ipv6, ip: {8193, 43981, 4321, 56789, 123, 4567, 8901, 23456}, mask: 128}) == true
    assert IPAddr.include?(%IPAddr{family: :ipv6, ip: {8193, 43981, 4321, 56789, 0, 0, 0, 0}, mask: 64}, %IPAddr{family: :ipv6, ip: {8193, 43981, 4321, 56790, 123, 4567, 8901, 23456}, mask: 128}) == false
    assert IPAddr.include?(%IPAddr{family: :ipv6, ip: {8193, 43981, 4321, 56789, 0, 0, 0, 0}, mask: 64}, %IPAddr{family: :ipv6, ip: {8193, 43981, 4321, 56789, 123, 0, 0, 0}, mask: 72}) == true
  end

  test "can convert an IP address map to a string" do
    assert IPAddr.to_string(IPAddr.new("192.168.0.0/16")) == "192.168.0.0/16"
    assert IPAddr.to_string(IPAddr.new("200.100.50.25")) == "200.100.50.25/32"
    assert to_string(IPAddr.new("200.100.50.25")) == "200.100.50.25/32"
    assert IPAddr.to_string(IPAddr.new("2001:abcd:1234:5678::/64")) == "2001:abcd:1234:5678::/64"
    assert IPAddr.to_string(IPAddr.new("2001:abcd:1234:5678:90ab:cdef:123:4567")) == "2001:abcd:1234:5678:90ab:cdef:123:4567/128"
    assert to_string(IPAddr.new("2001:abcd:1234:5678:90ab:cdef:123:4567")) == "2001:abcd:1234:5678:90ab:cdef:123:4567/128"
  end

  test "can convert an IP address tuple to an integer" do
    assert IPAddr.to_integer({192, 168, 10, 1}) == 3232238081
    assert IPAddr.to_integer(IPAddr.new("2001:abcd:1234:5678:90ab:cdef:123:4567").ip) == 42543972701425385287337697859424437607
  end

  test "can convert an IP address tuple to a binary" do
    assert IPAddr.to_binary(IPAddr.new("192.168.10.1")) == <<192, 168, 10, 1>>
    assert IPAddr.to_binary(IPAddr.new("2001:abcd:1234:5678:90ab:cdef:123:4567")) == <<32, 1, 171, 205, 18, 52, 86, 120, 144, 171, 205, 239, 1, 35, 69, 103>>
  end
end
