import 'package:flutter_test/flutter_test.dart';
import 'package:tavolink/features/learning/learning_guard.dart';

void main() {
  const guard = LearningGuard();

  test('accepts memory with exact user evidence', () {
    expect(
      guard.acceptExtracted(
        content: '用户偏好二次元狐妖 UI',
        evidence: '我喜欢二次元狐妖UI',
        userText: '以后界面就按这个来，我喜欢二次元狐妖UI。',
      ),
      isTrue,
    );
  });

  test('rejects hallucinated evidence', () {
    expect(
      guard.acceptExtracted(
        content: '用户住在东京',
        evidence: '我住在东京',
        userText: '帮我查东京天气',
      ),
      isFalse,
    );
  });

  test('rejects credentials', () {
    expect(guard.looksLikeSecret('API Key: sk-abcdefghijklmnop'), isTrue);
  });
}
