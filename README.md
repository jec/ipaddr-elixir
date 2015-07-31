# IPAddr for Elixir

The IPAddr module provides IP address manipulation, including CIDR-style range
calculations, for both IPv4 and IPv6 addresses. The functions provided were
loosely inspired by Ruby's IPAddr class, along with some others I've found
useful.

## Examples

```elixir
range = IPAddr.new("192.168.10.0/24")
ip = IPAddr.new("192.168.10.50")
IO.inspect(range)
IO.inspect(ip)
IO.inspect(IPAddr.include?(range, ip))
IO.inspect(IPAddr.include?(range, IPAddr.new("192.168.11.50")))
```

_produces:_

    %IPAddr{family: :ipv4, ip: {192, 168, 10, 0}, mask: 24}
    %IPAddr{family: :ipv4, ip: {192, 168, 10, 50}, mask: 32}
    true
    false

## License

IPAddr is licensed under the three-clause BSD license (see LICENSE.txt).
