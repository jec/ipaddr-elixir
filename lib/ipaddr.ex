defmodule IPAddr do

  @moduledoc """
  IP address and range manipulation, including CIDR syntax support
  
  This module was inspired by the Ruby IPAddr class.
  """

  use Bitwise

  @ip4bits 32
  @ip6bits 128

  @doc """
  Parses an IP address string, either IPv4 or IPv6, optionally with a
  CIDR-formatted bitmask (e.g. "/24"), and returns a map of the form:
  %{ip: {iii, ...}, mask: nnn}
  
  If the CIDR mask is omitted, the identity mask is assumed (32 for IPv4; 128
  for IPv6).
  """
  def parse(string) do
    [ip_str, mask_str] = case String.split(string, "/", parts: 2) do
      [a]    -> [a, :nil]
      [a, b] -> [a, b]
    end
    {:ok, ip} = :inet.parse_address(String.to_char_list(ip_str))
    max_bits = identity(ip)
    family = if max_bits == @ip4bits, do: :ipv4, else: :ipv6
    bitmask = if mask_str == nil, do: max_bits, else: String.to_integer(mask_str)
    # mask any bits beyond the bitmask
    mask = (trunc(:math.pow(2, max_bits)) - 1) <<< (max_bits - bitmask)
    ip_int = to_integer(ip) &&& mask
    %{ip: from_integer(ip_int, family), mask: bitmask}
  end

  @doc """
  Receives an integer and returns an IP address tuple (with either 4 or 8
  elements)
  """
  def from_integer(int, family) when family == :ipv4 or family == :ipv6 do
    bytes = :binary.bin_to_list(:binary.encode_unsigned(int))
    if length(bytes) == 16 do
      bytes = squeeze_v6(bytes, [])
    end
    # pad if necessary
    max_bytes = if family == :ipv4, do: 4, else: 8
    pad_elems = max_bytes - length(bytes)
    if pad_elems > 0 do
      bytes = lpad_list(bytes, pad_elems)
    end
    List.to_tuple(bytes)
  end

  @doc """
  Receives either an IP address tuple or an IP address map (as created by parse())
  and returns true or false to indicate whether it is IPv4
  """
  def ipv4?({a,b,c,d}) when a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255, do: true
  def ipv4?(%{ip: {a,b,c,d}, mask: m}) when a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255 and m in 0..@ip4bits, do: true
  def ipv4?(_), do: false

  @doc """
  Receives either an IP address tuple or an IP address map (as created by parse())
  and returns true or false to indicate whether it is IPv6
  """
  def ipv6?({a,b,c,d,e,f,g,h}) when a in 0..65535 and b in 0..65535 and c in 0..65535 and d in 0..65535 and e in 0..65535 and f in 0..65535 and g in 0..65535 and h in 0..65535, do: true
  def ipv6?(%{ip: {a,b,c,d,e,f,g,h}, mask: m}) when a in 0..65535 and b in 0..65535 and c in 0..65535 and d in 0..65535 and e in 0..65535 and f in 0..65535 and g in 0..65535 and h in 0..65535 and m in 0..@ip6bits, do: true
  def ipv6?(_), do: false

  @doc """
  Receives an IP address tuple or map and returns 32 for an IPv4 address or 128 for
  an IPv6 address
  """
  def identity({_,_,_,_}), do: @ip4bits
  def identity({_,_,_,_,_,_,_,_}), do: @ip6bits
  def identity(%{ip: {_,_,_,_}, mask: _}), do: @ip4bits
  def identity(%{ip: {_,_,_,_,_,_,_,_}, mask: _}), do: @ip6bits

  @doc """
  Receives an IP address map and returns true if the mask equals the identity
  mask for that address class (32 for IPv4 or 128 for IPv6); else returns false
  """
  def identity?(%{ip: {_,_,_,_}, mask: m}), do: m == @ip4bits
  def identity?(%{ip: {_,_,_,_,_,_,_,_}, mask: m}), do: m == @ip6bits

  @doc """
  Receives an IP address map (as returned by parse()) and returns an integer for the
  maximum IP within that range
  """
  def max_int(%{ip: {a,b,c,d}, mask: m}) when a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255 and m in 0..@ip4bits do
    max_int(to_integer({a,b,c,d}), m, @ip4bits)
  end
  def max_int(%{ip: {a,b,c,d,e,f,g,h}, mask: m}) when a in 0..65535 and b in 0..65535 and c in 0..65535 and d in 0..65535 and e in 0..65535 and f in 0..65535 and g in 0..65535 and h in 0..65535 and m in 0..@ip6bits do
    max_int(to_integer({a,b,c,d,e,f,g,h}), m, @ip6bits)
  end
  defp max_int(ip_int, mask, max_bits) do
    max_mask = trunc(:math.pow(2, (max_bits - mask))) - 1
    ip_int ||| max_mask
  end

  @doc """
  Receives an IP address map (as returned by parse()) and returns a tuple for the
  maximum IP within that range
  """
  def max(%{ip: {a,b,c,d}, mask: m}) when a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255 and m in 0..@ip4bits do
    max(to_integer({a,b,c,d}), m, @ip4bits, :ipv4)
  end
  def max(%{ip: {a,b,c,d,e,f,g,h}, mask: m}) when a in 0..65535 and b in 0..65535 and c in 0..65535 and d in 0..65535 and e in 0..65535 and f in 0..65535 and g in 0..65535 and h in 0..65535 and m in 0..@ip6bits do
    max(to_integer({a,b,c,d,e,f,g,h}), m, @ip6bits, :ipv6)
  end
  defp max(ip_int, mask, max_bits, family) do
    from_integer(max_int(ip_int, mask, max_bits), family)
  end

  @doc """
  Receives two IP address maps (as returned by parse()) and returns true if the
  2nd is a subset of the 1st; else returns false
  """
  def include?(%{ip: {a,b,c,d}, mask: m1}, %{ip: {e,f,g,h}, mask: m2}) do
    include?({a,b,c,d}, m1, {e,f,g,h}, m2, @ip4bits)
  end
  def include?(%{ip: {a,b,c,d,e,f,g,h}, mask: m1}, %{ip: {i,j,k,l,m,n,o,p}, mask: m2}) do
    include?({a,b,c,d,e,f,g,h}, m1, {i,j,k,l,m,n,o,p}, m2, @ip6bits)
  end
  defp include?(left_tuple, left_mask, right_tuple, right_mask, max_bits) do
    min_left = to_integer(left_tuple)
    max_left = max_int(min_left, left_mask, max_bits)
    min_right = to_integer(right_tuple)
    max_right = max_int(min_right, right_mask, max_bits)
    min_left <= min_right and min_right <= max_left and min_left <= max_right and max_right <= max_left
  end

  @doc """
  Receives an IP address tuple or map and returns a string
  
  If passed a tuple, the CIDR mask will not be included in the string.
  """
  def to_string(%{ip: ip_tuple, mask: mask}), do: "#{String.downcase(:binary.list_to_bin(:inet.ntoa(ip_tuple)))}/#{mask}"
  def to_string(ip_tuple), do: String.downcase(:binary.list_to_bin(:inet.ntoa(ip_tuple)))

  @doc """
  Receives an IP address tuple (either 4 or 8 elements) and returns an integer
  """
  def to_integer({a,b,c,d}) do
    Enum.reduce([a,b,c,d], fn(n, sum) -> (sum <<< 8) + n end)
  end
  def to_integer({a,b,c,d,e,f,g,h}) do
    Enum.reduce([a,b,c,d,e,f,g,h], fn(n, sum) -> (sum <<< 16) + n end)
  end

  # TODO: This isn't used by any other functions in the module; delete it?
  @doc """
  Receives an IP address tuple (either 4 or 8 elements) and returns a binary
  (either 4 or 16 elements)
  """
  def to_binary({a,b,c,d}), do: to_binary([a,b,c,d], <<>>, 8)
  def to_binary({a,b,c,d,e,f,g,h}), do: to_binary([a,b,c,d,e,f,g,h], <<>>, 16)
  defp to_binary([], bin, _), do: bin
  defp to_binary([head | tail], bin, bits), do: to_binary(tail, bin <> <<head::size(bits)>>, bits)

  #
  # Receives a list of bytes and combines every 2 bytes into a single 2-byte
  # value
  #
  defp squeeze_v6([], ary) do
    :lists.reverse(ary)
  end
  defp squeeze_v6([head|tail], ary) do
    first_elem = if length(ary) == 0, do: :nil, else: List.first(ary)
    elem = if is_list(first_elem) do
      [_ | ary] = ary
      first_byte = List.first(first_elem)
      (first_byte <<< 8) + head
    else
      [head]
    end
    squeeze_v6(tail, [elem | ary])
  end

  #
  # Adds _count_ zeroes at the head of _list_
  #
  defp lpad_list(list, count) when count == 0 do
    list
  end
  defp lpad_list(list, count) do
    lpad_list([0 | list], count - 1)
  end

end