import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/network/proxy_settings_service.dart';

class ProxySettingsScreen extends ConsumerStatefulWidget {
  const ProxySettingsScreen({super.key});

  @override
  ConsumerState<ProxySettingsScreen> createState() => _ProxySettingsScreenState();
}

class _ProxySettingsScreenState extends ConsumerState<ProxySettingsScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();

  ProxyMode _mode = ProxyMode.system;
  ProxyType _type = ProxyType.http;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await ref.read(proxySettingsServiceProvider).load();
    if (!mounted) return;
    setState(() {
      _mode = settings.mode;
      _type = settings.type;
      _hostController.text = settings.host ?? '';
      _portController.text = settings.port?.toString() ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (_mode == ProxyMode.custom) {
      if (host.isEmpty || port == null || port <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请填写有效的代理地址和端口')));
        return;
      }
    }

    setState(() {
      _saving = true;
    });
    try {
      await ref.read(proxySettingsServiceProvider).save(
        ProxySettings(
          mode: _mode,
          type: _type,
          host: _mode == ProxyMode.custom ? host : null,
          port: _mode == ProxyMode.custom ? port : null,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('代理设置已保存')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('网络代理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('远程网络调用优先按此策略走代理。'),
                const SizedBox(height: 12),
                RadioListTile<ProxyMode>(
                  value: ProxyMode.system,
                  groupValue: _mode,
                  title: const Text('系统代理（有则使用）'),
                  subtitle: const Text('遵循操作系统/运行环境代理设置'),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _mode = value);
                  },
                ),
                RadioListTile<ProxyMode>(
                  value: ProxyMode.custom,
                  groupValue: _mode,
                  title: const Text('自定义代理'),
                  subtitle: const Text('支持 HTTP、SOCKS5'),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _mode = value);
                  },
                ),
                if (_mode == ProxyMode.custom) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ProxyType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: '代理类型'),
                    items: const [
                      DropdownMenuItem(
                        value: ProxyType.http,
                        child: Text('HTTP'),
                      ),
                      DropdownMenuItem(
                        value: ProxyType.socks5,
                        child: Text('SOCKS5'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(labelText: '代理地址'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '端口'),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中...' : '保存'),
                ),
              ],
            ),
    );
  }
}
