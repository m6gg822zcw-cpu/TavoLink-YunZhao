import 'package:flutter_test/flutter_test.dart';
import 'package:tavolink/features/learning/learning_repository.dart';

void main() {
  test('Chinese memory similarity favors related content', () {
    final related = LearningRepository.similarity('我喜欢二次元狐妖界面', '用户偏好二次元狐妖风格 UI');
    final unrelated = LearningRepository.similarity('我喜欢二次元狐妖界面', 'MCP 服务器连接失败需要检查 Token');
    expect(related, greaterThan(unrelated));
  });

  test('duplicate memory similarity is high', () {
    final score = LearningRepository.similarity('用户希望回答直接一些', '用户希望回答直接一些');
    expect(score, greaterThan(.9));
  });
}
