bool isPrivateOrLoopbackHost(String host) {
  final value = host.toLowerCase().trim();
  if (value == 'localhost' || value == '::1' || value.endsWith('.local')) return true;
  if (value.startsWith('127.') || value.startsWith('10.') || value.startsWith('192.168.')) return true;
  final parts = value.split('.');
  if (parts.length == 4 && parts[0] == '172') {
    final second = int.tryParse(parts[1]);
    if (second != null && second >= 16 && second <= 31) return true;
  }
  return false;
}

bool isAllowedEndpoint(Uri uri, {bool allowPrivateHttp = true}) {
  if (!uri.hasScheme || !uri.hasAuthority) return false;
  if (uri.scheme.toLowerCase() == 'https') return true;
  return allowPrivateHttp && uri.scheme.toLowerCase() == 'http' && isPrivateOrLoopbackHost(uri.host);
}
