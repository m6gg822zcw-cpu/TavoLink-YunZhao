bool isPrivateOrLoopbackHost(String host) {
  final value = host.toLowerCase().trim();
  if (value == 'localhost' || value.endsWith('.local')) return true;

  final ipv4 = _parseIpv4(value);
  if (ipv4 != null) {
    return ipv4[0] == 10 ||
        ipv4[0] == 127 ||
        (ipv4[0] == 169 && ipv4[1] == 254) ||
        (ipv4[0] == 172 && ipv4[1] >= 16 && ipv4[1] <= 31) ||
        (ipv4[0] == 192 && ipv4[1] == 168);
  }

  try {
    final ipv6 = Uri.parseIPv6Address(value);
    return ipv6.last == 1 &&
            ipv6.take(ipv6.length - 1).every((byte) => byte == 0) ||
        (ipv6.first & 0xfe) == 0xfc ||
        (ipv6.first == 0xfe && (ipv6[1] & 0xc0) == 0x80);
  } on FormatException {
    return false;
  }
}

bool isAllowedEndpoint(Uri uri, {bool allowPrivateHttp = true}) {
  if (!uri.hasScheme ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return false;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') return true;
  return allowPrivateHttp &&
      scheme == 'http' &&
      isPrivateOrLoopbackHost(uri.host);
}

List<int>? _parseIpv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return null;
  final bytes = <int>[];
  for (final part in parts) {
    if (part.isEmpty || !RegExp(r'^\d{1,3}$').hasMatch(part)) return null;
    final value = int.parse(part);
    if (value > 255) return null;
    bytes.add(value);
  }
  return bytes;
}
