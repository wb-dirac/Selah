enum ToolPermissionLevel {
  l0,
  l1,
  l2,
  l3,
}

extension ToolPermissionLevelX on ToolPermissionLevel {
  String get value {
    switch (this) {
      case ToolPermissionLevel.l0:
        return 'l0';
      case ToolPermissionLevel.l1:
        return 'l1';
      case ToolPermissionLevel.l2:
        return 'l2';
      case ToolPermissionLevel.l3:
        return 'l3';
    }
  }

  String get label {
    switch (this) {
      case ToolPermissionLevel.l0:
        return '无需授权';
      case ToolPermissionLevel.l1:
        return '首次授权';
      case ToolPermissionLevel.l2:
        return '每次确认';
      case ToolPermissionLevel.l3:
        return '完整预览';
    }
  }
}

enum ToolCategory {
  communication,
  calendar,
  location,
  system,
}

extension ToolCategoryX on ToolCategory {
  String get label {
    switch (this) {
      case ToolCategory.communication:
        return '通信';
      case ToolCategory.calendar:
        return '日历';
      case ToolCategory.location:
        return '位置';
      case ToolCategory.system:
        return '系统';
    }
  }
}

enum ToolPermissionStatus {
  notDetermined,
  granted,
  askEveryTime,
  denied,
}

extension ToolPermissionStatusX on ToolPermissionStatus {
  String get value {
    switch (this) {
      case ToolPermissionStatus.notDetermined:
        return 'not_determined';
      case ToolPermissionStatus.granted:
        return 'granted';
      case ToolPermissionStatus.askEveryTime:
        return 'ask_every_time';
      case ToolPermissionStatus.denied:
        return 'denied';
    }
  }

  String get label {
    switch (this) {
      case ToolPermissionStatus.notDetermined:
        return '未设置';
      case ToolPermissionStatus.granted:
        return '已授权';
      case ToolPermissionStatus.askEveryTime:
        return '每次确认';
      case ToolPermissionStatus.denied:
        return '已拒绝';
    }
  }

  static ToolPermissionStatus fromValue(String? value) {
    for (final status in ToolPermissionStatus.values) {
      if (status.value == value) {
        return status;
      }
    }
    return ToolPermissionStatus.notDetermined;
  }
}

class ToolDefinition {
  const ToolDefinition({
    required this.id,
    required this.displayName,
    required this.category,
    required this.permissionLevel,
    required this.description,
  });

  final String id;
  final String displayName;
  final ToolCategory category;
  final ToolPermissionLevel permissionLevel;
  final String description;
}

abstract class ToolBridgeTool {
  ToolDefinition get definition;
}

class ToolPermissionRecord {
  const ToolPermissionRecord({
    required this.toolId,
    required this.status,
    required this.updatedAt,
  });

  final String toolId;
  final ToolPermissionStatus status;
  final DateTime updatedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'tool_id': toolId,
      'status': status.value,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ToolPermissionRecord.fromJson(Map<String, dynamic> json) {
    return ToolPermissionRecord(
      toolId: json['tool_id'] as String,
      status: ToolPermissionStatusX.fromValue(json['status'] as String?),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ToolInvocationRecord {
  const ToolInvocationRecord({
    required this.toolId,
    required this.allowed,
    required this.timestamp,
    this.summary,
  });

  final String toolId;
  final bool allowed;
  final DateTime timestamp;
  final String? summary;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'tool_id': toolId,
      'allowed': allowed,
      'timestamp': timestamp.toIso8601String(),
      'summary': summary,
    };
  }

  factory ToolInvocationRecord.fromJson(Map<String, dynamic> json) {
    return ToolInvocationRecord(
      toolId: json['tool_id'] as String,
      allowed: json['allowed'] as bool? ?? false,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      summary: json['summary'] as String?,
    );
  }
}

const List<ToolDefinition> builtInToolDefinitions = <ToolDefinition>[
  ToolDefinition(
    id: 'contacts.read',
    displayName: '读取联系人',
    category: ToolCategory.communication,
    permissionLevel: ToolPermissionLevel.l1,
    description: '读取通讯录中的联系人信息',
  ),
  ToolDefinition(
    id: 'contacts.search',
    displayName: '搜索联系人',
    category: ToolCategory.communication,
    permissionLevel: ToolPermissionLevel.l1,
    description: '按姓名或联系方式搜索联系人',
  ),
  ToolDefinition(
    id: 'contacts.create',
    displayName: '创建联系人',
    category: ToolCategory.communication,
    permissionLevel: ToolPermissionLevel.l2,
    description: '向系统通讯录写入新联系人',
  ),
  ToolDefinition(
    id: 'mail.compose',
    displayName: '发送邮件草稿',
    category: ToolCategory.communication,
    permissionLevel: ToolPermissionLevel.l2,
    description: '创建待发送的邮件草稿',
  ),
  ToolDefinition(
    id: 'sms.send',
    displayName: '发送短信',
    category: ToolCategory.communication,
    permissionLevel: ToolPermissionLevel.l2,
    description: '发起短信发送',
  ),
  ToolDefinition(
    id: 'phone.call',
    displayName: '拨打电话',
    category: ToolCategory.communication,
    permissionLevel: ToolPermissionLevel.l3,
    description: '发起电话拨号',
  ),
  ToolDefinition(
    id: 'calendar.read',
    displayName: '读取日历事件',
    category: ToolCategory.calendar,
    permissionLevel: ToolPermissionLevel.l1,
    description: '读取指定时间范围内的日历事件',
  ),
  ToolDefinition(
    id: 'calendar.create',
    displayName: '创建日历事件',
    category: ToolCategory.calendar,
    permissionLevel: ToolPermissionLevel.l2,
    description: '创建新的日历事件和提醒',
  ),
  ToolDefinition(
    id: 'calendar.update_delete',
    displayName: '修改/删除日历事件',
    category: ToolCategory.calendar,
    permissionLevel: ToolPermissionLevel.l2,
    description: '修改或删除已存在的日历事件',
  ),
  ToolDefinition(
    id: 'location.current',
    displayName: '获取当前位置',
    category: ToolCategory.location,
    permissionLevel: ToolPermissionLevel.l1,
    description: '读取当前设备位置，仅用于当前会话',
  ),
  ToolDefinition(
    id: 'location.search',
    displayName: '地点搜索',
    category: ToolCategory.location,
    permissionLevel: ToolPermissionLevel.l0,
    description: '在地图应用中搜索指定地点或关键词',
  ),
  ToolDefinition(
    id: 'clipboard.read',
    displayName: '读取剪贴板',
    category: ToolCategory.system,
    permissionLevel: ToolPermissionLevel.l1,
    description: '读取系统剪贴板内容',
  ),
  ToolDefinition(
    id: 'clipboard.write',
    displayName: '写入剪贴板',
    category: ToolCategory.system,
    permissionLevel: ToolPermissionLevel.l0,
    description: '写入文本到系统剪贴板',
  ),
  ToolDefinition(
    id: 'system.share',
    displayName: '系统分享菜单',
    category: ToolCategory.system,
    permissionLevel: ToolPermissionLevel.l0,
    description: '调起系统原生分享菜单',
  ),
];
