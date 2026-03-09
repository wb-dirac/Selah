import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/a2a/domain/a2a_task.dart';

void main() {
  const task = A2ATask(
    id: 'task-001',
    agentName: '铁路查询 Agent',
    agentUrl: 'https://rail-agent.local:8080/a2a',
    skillId: 'query-schedule',
    skillName: '查询班次列表',
    input: <String, dynamic>{'from': '北京', 'to': '上海', 'date': '2026-03-10'},
  );

  test('defaults userConfirmed to false', () {
    expect(task.userConfirmed, isFalse);
  });

  test('withConfirmation returns confirmed copy', () {
    final confirmed = task.withConfirmation();
    expect(confirmed.userConfirmed, isTrue);
    expect(confirmed.id, task.id);
    expect(confirmed.agentName, task.agentName);
    expect(confirmed.skillId, task.skillId);
    expect(confirmed.input, task.input);
  });

  test('original task is not mutated by withConfirmation', () {
    task.withConfirmation();
    expect(task.userConfirmed, isFalse);
  });

  test('agentUrl is HTTPS', () {
    expect(task.agentUrl.startsWith('https://'), isTrue);
  });
}
