import 'package:flutter/material.dart';

import '../library_store.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.library});

  final LibraryStore library;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _token = TextEditingController();
  final _chat = TextEditingController();
  bool _checking = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await widget.library.connect(_token.text, _chat.text);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _token.dispose();
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ChatTunes')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            children: [
              Text('Подключение', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                '1. Создай бота у @BotFather и скопируй токен.\n'
                '2. Создай канал и добавь бота админом '
                '(публикация, закрепление и удаление сообщений).\n'
                '3. Укажи @username канала или его числовой id.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _token,
                decoration: const InputDecoration(
                  labelText: 'Токен бота',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _chat,
                decoration: const InputDecoration(
                  labelText: 'Канал (@name или -100…)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _checking ? null : _connect,
                child: _checking
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Подключить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
