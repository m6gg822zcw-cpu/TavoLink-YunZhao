import 'package:flutter_test/flutter_test.dart';
import 'package:tavolink/core/network/url_policy.dart';

void main() {
  group('endpoint policy', () {
    test('allows HTTPS and private-network HTTP', () {
      expect(
        isAllowedEndpoint(Uri.parse('https://api.example.com/v1')),
        isTrue,
      );
      expect(isAllowedEndpoint(Uri.parse('http://127.0.0.1:5177/mcp')), isTrue);
      expect(isAllowedEndpoint(Uri.parse('http://10.0.2.2:5177/mcp')), isTrue);
      expect(
        isAllowedEndpoint(Uri.parse('http://172.31.4.8:5177/mcp')),
        isTrue,
      );
      expect(
        isAllowedEndpoint(Uri.parse('http://192.168.1.8:5177/mcp')),
        isTrue,
      );
      expect(
        isAllowedEndpoint(Uri.parse('http://yunzhao.local:5177/mcp')),
        isTrue,
      );
      expect(isAllowedEndpoint(Uri.parse('http://[fd00::1]:5177/mcp')), isTrue);
    });

    test('rejects public or deceptive HTTP endpoints', () {
      expect(isAllowedEndpoint(Uri.parse('http://example.com/v1')), isFalse);
      expect(isAllowedEndpoint(Uri.parse('http://10.example.com/v1')), isFalse);
      expect(
        isAllowedEndpoint(Uri.parse('http://192.168.example.com/v1')),
        isFalse,
      );
      expect(isAllowedEndpoint(Uri.parse('ftp://192.168.1.2/file')), isFalse);
      expect(
        isAllowedEndpoint(Uri.parse('http://user:pass@192.168.1.2/mcp')),
        isFalse,
      );
    });
  });
}
