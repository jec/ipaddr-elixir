defmodule IPAddr do
  @moduledoc """
  IP address and range manipulation, including CIDR syntax support

  This module was inspired by the Ruby IPAddr class.
  """

  defstruct ip: nil, mask: nil, family: nil

  use Bitwise

  @ip4mask 0xffffffff
  @ip4bits 32
  @ip4terms 4

  @ip6mask 0xffffffffffffffffffffffffffffffff
  @ip6bits 128
  @ip6terms 8

  @family_map %{ipv4: {@ip4mask, @ip4bits, @ip4terms}, ipv6: {@ip6mask, @ip6bits, @ip6terms}}

  @doc """
  Parses an IP address string, either IPv4 or IPv6, optionally with a
  CIDR-formatted bitmask (e.g. "/24"), and returns an %IPAddr struct

  If the CIDR mask is omitted, the identity mask is assumed (32 for IPv4; 128
  for IPv6).
  """
  def new(string) do
    [ip_str, mask_str] = case String.split(string, "/", parts: 2) do
      [a]    -> [a, nil]
      [a, b] -> [a, b]
    end
    {:ok, ip} = ip_str |> String.to_charlist |> :inet.parse_address
    max_bits = identity(ip)
    family = if max_bits == @ip4bits, do: :ipv4, else: :ipv6
    cidr_length = if mask_str == nil, do: max_bits, else: String.to_integer(mask_str)
    from_integer(to_integer(ip), family, cidr_length)
  end

  @doc """
  Receives an integer and family and (optionally) cidr_length and returns an
  IPAddr struct
  """
  def from_integer(int, family, cidr_length \\ nil) when family == :ipv4 or family == :ipv6 do
    {base_mask, max_bits, max_terms} = @family_map[family]
    cidr_length = cidr_length || max_bits
    # mask any bits beyond the bitmask
    mask = (base_mask <<< (max_bits - cidr_length)) &&& base_mask
    ip_int = int &&& mask
    # get list of terms
    terms = :binary.encode_unsigned(ip_int) |> :binary.bin_to_list
    terms = if length(terms) == 16 do
      Enum.chunk_every(terms, 2) |> Enum.map(fn([a, b]) -> (a <<< 8) + b end)
    else
      terms
    end
    # pad if necessary
    terms = lpad_list(terms, max_terms - length(terms))
    %IPAddr{family: family, ip: List.to_tuple(terms), mask: cidr_length}
  end

  @doc """
  Receives an IPAddr struct and returns true if it is IPv4; else returns false
  """
  def ipv4?(%IPAddr{family: f, ip: {a,b,c,d}, mask: m}) when f == :ipv4 and a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255 and m in 0..@ip4bits, do: true
  def ipv4?(_), do: false

  @doc """
  Receives an IPAddr struct and returns true if it is IPv6; else returns false
  """
  def ipv6?(%{family: fam, ip: {a,b,c,d,e,f,g,h}, mask: m}) when fam == :ipv6 and a in 0..65535 and b in 0..65535 and c in 0..65535 and d in 0..65535 and e in 0..65535 and f in 0..65535 and g in 0..65535 and h in 0..65535 and m in 0..@ip6bits, do: true
  def ipv6?(_), do: false

  @doc """
  Receives either an IPAddr struct or an IP address tuple and returns 32 for an
  IPv4 address or 128 for an IPv6 address
  """
  def identity({_,_,_,_}), do: @ip4bits
  def identity({_,_,_,_,_,_,_,_}), do: @ip6bits
  def identity(%IPAddr{family: f, ip: {_,_,_,_}, mask: _}) when f == :ipv4, do: @ip4bits
  def identity(%IPAddr{family: f, ip: {_,_,_,_,_,_,_,_}, mask: _}) when f == :ipv6, do: @ip6bits

  @doc """
  Receives an IPAddr struct and returns true if the mask equals the identity
  mask for that address class (32 for IPv4 or 128 for IPv6); else returns false
  """
  def identity?(%IPAddr{family: f, ip: {_,_,_,_}, mask: m}) when f == :ipv4, do: m == @ip4bits
  def identity?(%IPAddr{family: f, ip: {_,_,_,_,_,_,_,_}, mask: m}) when f == :ipv6, do: m == @ip6bits

  @doc """
  Receives an IPAddr struct and returns an integer for the maximum IP within that range
  """
  def max_int(%IPAddr{family: fam, ip: t={a,b,c,d}, mask: m}) when fam == :ipv4 and a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255 and m in 0..@ip4bits do
    to_integer(t) |> max_int(m, @ip4bits)
  end
  def max_int(%IPAddr{family: fam, ip: t={a,b,c,d,e,f,g,h}, mask: m}) when fam == :ipv6 and a in 0..65535 and b in 0..65535 and c in 0..65535 and d in 0..65535 and e in 0..65535 and f in 0..65535 and g in 0..65535 and h in 0..65535 and m in 0..@ip6bits do
    to_integer(t) |> max_int(m, @ip6bits)
  end
  defp max_int(ip_int, mask, max_bits) do
    max_mask = (:math.pow(2, max_bits - mask) |> trunc) - 1
    ip_int ||| max_mask
  end

  @doc """
  Receives an IPAddr struct and returns an IPAddr struct representing the maximum
  IP within that range
  """
  def max(%IPAddr{family: fam, ip: t={a,b,c,d}, mask: m}) when fam == :ipv4 and a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255 and m in 0..@ip4bits do
    to_integer(t) |> max(m, @ip4bits, fam)
  end
  def max(%IPAddr{family: fam, ip: t={a,b,c,d,e,f,g,h}, mask: m}) when fam == :ipv6 and a in 0..65535 and b in 0..65535 and c in 0..65535 and d in 0..65535 and e in 0..65535 and f in 0..65535 and g in 0..65535 and h in 0..65535 and m in 0..@ip6bits do
    to_integer(t) |> max(m, @ip6bits, fam)
  end
  defp max(ip_int, mask, max_bits, family) do
    max_int(ip_int, mask, max_bits) |> from_integer(family, max_bits)
  end

  @doc """
  Receives two IPAddr structs and returns true if the 2nd is a subset of the 1st;
  else returns false
  """
  def include?(%IPAddr{family: fam, ip: t1, mask: m1}, %{ip: t2, mask: m2}) when fam == :ipv4 do
    include?(t1, m1, t2, m2, @ip4bits)
  end
  def include?(%IPAddr{family: fam, ip: t1, mask: m1}, %{ip: t2, mask: m2}) when fam == :ipv6 do
    include?(t1, m1, t2, m2, @ip6bits)
  end
  defp include?(left_tuple, left_mask, right_tuple, right_mask, max_bits) do
    min_left = to_integer(left_tuple)
    max_left = max_int(min_left, left_mask, max_bits)
    min_right = to_integer(right_tuple)
    max_right = max_int(min_right, right_mask, max_bits)
    min_left <= min_right and min_right <= max_left and min_left <= max_right and max_right <= max_left
  end

  @doc """
  Receives an IPAddr struct and returns a string representation of the IP address
  including CIDR mask
  """
  def to_string(%IPAddr{family: _, ip: ip_tuple, mask: mask}), do: "#{ip_tuple |> :inet.ntoa |> :binary.list_to_bin |> String.downcase}/#{mask}"

  @doc """
  Receives an IP address tuple (either 4 or 8 elements) and returns an integer
  """
  def to_integer({a,b,c,d}) do
    Enum.reduce([a,b,c,d], fn(n, sum) -> (sum <<< 8) + n end)
  end
  def to_integer({a,b,c,d,e,f,g,h}) do
    Enum.reduce([a,b,c,d,e,f,g,h], fn(n, sum) -> (sum <<< 16) + n end)
  end

  @doc """
  Receives an IPAddr struct and returns a binary (either 4 or 16 bytes long)
  """
  def to_binary(%IPAddr{family: fam, ip: {a,b,c,d}, mask: _}) when fam == :ipv4, do: to_binary([a,b,c,d], <<>>, 8)
  def to_binary(%IPAddr{family: fam, ip: {a,b,c,d,e,f,g,h}, mask: _}) when fam == :ipv6, do: to_binary([a,b,c,d,e,f,g,h], <<>>, 16)
  defp to_binary([], bin, _), do: bin
  defp to_binary([head | tail], bin, bits), do: to_binary(tail, bin <> <<head::size(bits)>>, bits)

  #
  # Adds _count_ zeroes at the head of _list_
  #
  defp lpad_list(list, 0) do
    list
  end
  defp lpad_list(list, count) when count > 0 do
    lpad_list([0 | list], count - 1)
  end
end

defimpl String.Chars, for: IPAddr do
  def to_string(ipaddr), do: IPAddr.to_string(ipaddr)
end
