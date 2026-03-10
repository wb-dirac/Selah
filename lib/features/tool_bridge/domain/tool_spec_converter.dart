import 'package:personal_ai_assistant/features/llm_gateway/data/models/tool_spec.dart';

/// Provides [ToolSpec] definitions for all built-in tools.
///
/// Each spec maps the tool's string ID to a JSON-Schema style parameter
/// description that LLMs use to understand how to invoke the tool.
const Map<String, ToolSpec> builtInToolSpecs = {
  'contacts.read': ToolSpec(
    name: 'contacts.read',
    description: '读取通讯录中的所有联系人，返回姓名、电话、邮件等信息',
  ),
  'contacts.search': ToolSpec(
    name: 'contacts.search',
    description: '按姓名或关键词搜索联系人',
    parameters: ToolParameterSchema(
      properties: {
        'query': ToolParamProperty(
          type: ToolParamType.string,
          description: '搜索关键词（姓名、公司、邮件等）',
        ),
      },
      required: ['query'],
    ),
  ),
  'contacts.create': ToolSpec(
    name: 'contacts.create',
    description: '在通讯录中创建新联系人',
    parameters: ToolParameterSchema(
      properties: {
        'name': ToolParamProperty(
          type: ToolParamType.string,
          description: '联系人姓名（必填）',
        ),
        'phone': ToolParamProperty(
          type: ToolParamType.string,
          description: '电话号码',
        ),
        'email': ToolParamProperty(
          type: ToolParamType.string,
          description: '电子邮件地址',
        ),
        'organization': ToolParamProperty(
          type: ToolParamType.string,
          description: '所属组织或公司',
        ),
      },
      required: ['name'],
    ),
  ),
  'mail.compose': ToolSpec(
    name: 'mail.compose',
    description: '打开邮件撰写界面，预填收件人、主题和正文',
    parameters: ToolParameterSchema(
      properties: {
        'to': ToolParamProperty(
          type: ToolParamType.string,
          description: '收件人邮件地址',
        ),
        'subject': ToolParamProperty(
          type: ToolParamType.string,
          description: '邮件主题',
        ),
        'body': ToolParamProperty(
          type: ToolParamType.string,
          description: '邮件正文内容',
        ),
      },
    ),
  ),
  'sms.send': ToolSpec(
    name: 'sms.send',
    description: '打开短信发送界面',
    parameters: ToolParameterSchema(
      properties: {
        'to': ToolParamProperty(
          type: ToolParamType.string,
          description: '收件人电话号码',
        ),
        'body': ToolParamProperty(
          type: ToolParamType.string,
          description: '短信内容',
        ),
      },
    ),
  ),
  'phone.call': ToolSpec(
    name: 'phone.call',
    description: '拨打指定电话号码',
    parameters: ToolParameterSchema(
      properties: {
        'number': ToolParamProperty(
          type: ToolParamType.string,
          description: '要拨打的电话号码',
        ),
      },
      required: ['number'],
    ),
  ),
  'calendar.read': ToolSpec(
    name: 'calendar.read',
    description: '读取日历事件列表',
    parameters: ToolParameterSchema(
      properties: {
        'start_date': ToolParamProperty(
          type: ToolParamType.string,
          description: '查询开始日期（ISO 8601 格式，如 2025-01-01）',
        ),
        'end_date': ToolParamProperty(
          type: ToolParamType.string,
          description: '查询结束日期（ISO 8601 格式）',
        ),
      },
    ),
  ),
  'calendar.create': ToolSpec(
    name: 'calendar.create',
    description: '创建新的日历事件',
    parameters: ToolParameterSchema(
      properties: {
        'title': ToolParamProperty(
          type: ToolParamType.string,
          description: '事件标题',
        ),
        'start_time': ToolParamProperty(
          type: ToolParamType.string,
          description: '开始时间（ISO 8601 格式）',
        ),
        'end_time': ToolParamProperty(
          type: ToolParamType.string,
          description: '结束时间（ISO 8601 格式）',
        ),
        'description': ToolParamProperty(
          type: ToolParamType.string,
          description: '事件描述',
        ),
        'location': ToolParamProperty(
          type: ToolParamType.string,
          description: '事件地点',
        ),
      },
      required: ['title', 'start_time'],
    ),
  ),
  'calendar.update_delete': ToolSpec(
    name: 'calendar.update_delete',
    description: '更新或删除已有的日历事件',
    parameters: ToolParameterSchema(
      properties: {
        'event_id': ToolParamProperty(
          type: ToolParamType.string,
          description: '要操作的事件 ID',
        ),
        'action': ToolParamProperty(
          type: ToolParamType.string,
          description: '操作类型',
          enumValues: ['update', 'delete'],
        ),
        'title': ToolParamProperty(
          type: ToolParamType.string,
          description: '更新后的标题（仅 update 时有效）',
        ),
        'start_time': ToolParamProperty(
          type: ToolParamType.string,
          description: '更新后的开始时间（仅 update 时有效）',
        ),
        'end_time': ToolParamProperty(
          type: ToolParamType.string,
          description: '更新后的结束时间（仅 update 时有效）',
        ),
      },
      required: ['event_id', 'action'],
    ),
  ),
  'location.current': ToolSpec(
    name: 'location.current',
    description: '获取设备当前 GPS 位置（经纬度）',
  ),
  'location.search': ToolSpec(
    name: 'location.search',
    description: '搜索附近地点或按关键词查找地点',
    parameters: ToolParameterSchema(
      properties: {
        'query': ToolParamProperty(
          type: ToolParamType.string,
          description: '地点名称或关键词',
        ),
      },
      required: ['query'],
    ),
  ),
  'clipboard.read': ToolSpec(
    name: 'clipboard.read',
    description: '读取剪贴板中的文字内容',
  ),
  'clipboard.write': ToolSpec(
    name: 'clipboard.write',
    description: '将文字写入剪贴板',
    parameters: ToolParameterSchema(
      properties: {
        'text': ToolParamProperty(
          type: ToolParamType.string,
          description: '要写入剪贴板的文字',
        ),
      },
      required: ['text'],
    ),
  ),
  'system.share': ToolSpec(
    name: 'system.share',
    description: '调用系统分享菜单分享文字内容',
    parameters: ToolParameterSchema(
      properties: {
        'text': ToolParamProperty(
          type: ToolParamType.string,
          description: '要分享的文字内容',
        ),
        'subject': ToolParamProperty(
          type: ToolParamType.string,
          description: '分享主题（可选）',
        ),
      },
      required: ['text'],
    ),
  ),
};

/// Returns [ToolSpec] list for all built-in tools.
/// These are passed to LLM providers to enable function calling.
List<ToolSpec> getBuiltInToolSpecs() =>
    builtInToolSpecs.values.toList(growable: false);
