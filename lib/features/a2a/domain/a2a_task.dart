class A2ATask {
  const A2ATask({
    required this.id,
    required this.agentName,
    required this.agentUrl,
    required this.skillId,
    required this.skillName,
    required this.input,
    this.userConfirmed = false,
  });

  final String id;
  final String agentName;
  final String agentUrl;
  final String skillId;
  final String skillName;
  final Map<String, dynamic> input;
  final bool userConfirmed;

  A2ATask withConfirmation() {
    return A2ATask(
      id: id,
      agentName: agentName,
      agentUrl: agentUrl,
      skillId: skillId,
      skillName: skillName,
      input: input,
      userConfirmed: true,
    );
  }
}
