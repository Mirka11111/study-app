import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  ThemeMode _mode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() => _mode = ThemeMode.values[p.getInt('tm') ?? 2]);
    });
  }

  void _toggleTheme() async {
    final next = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final p = await SharedPreferences.getInstance();
    await p.setInt('tm', next.index);
    setState(() => _mode = next);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: HomeScreen(onToggleTheme: _toggleTheme, isDark: _mode == ThemeMode.dark),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  const HomeScreen({super.key, required this.onToggleTheme, required this.isDark});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _streak = 5;
  int _avatar = 0;
  String _name = 'Студент';
  int _sec = 1200;
  bool _run = false;
  Timer? _timer;

  final _icons = const [
    Icons.person,
    Icons.school,
    Icons.local_fire_department,
    Icons.rocket_launch,
    Icons.sports_esports,
  ];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() {
        _streak = p.getInt('st') ?? 5;
        _avatar = p.getInt('av') ?? 0;
        _name = p.getString('nm') ?? 'Студент';
      });
    });
  }

  void _save() async {
    final p = await SharedPreferences.getInstance();
    p.setInt('st', _streak);
    p.setInt('av', _avatar);
    p.setString('nm', _name);
  }

  void _tick() {
    if (_run) {
      _timer?.cancel();
      setState(() => _run = false);
    } else {
      setState(() => _run = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_sec > 0) {
          setState(() => _sec--);
        } else {
          t.cancel();
          setState(() {
            _run = false;
            _sec = 1200;
            _streak++;
          });
          _save();
        }
      });
    }
  }

  void _changeName() {
    final c = TextEditingController(text: _name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Имя профиля'),
        content: TextField(controller: c),
        actions: [
          TextButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                setState(() => _name = c.text.trim());
                _save();
              }
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = (_sec ~/ 60).toString().padLeft(2, '0');
    final s = (_sec % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Tracker'),
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: IconButton(
                  icon: Icon(_icons[_avatar]),
                  onPressed: () {
                    setState(() => _avatar = (_avatar + 1) % _icons.length);
                    _save();
                  },
                ),
              ),
              title: Text(_name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('🔥 Стрик: $_streak дн. (нажми на аватар для смены)'),
              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _changeName),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('Таймер фокуса', style: TextStyle(fontSize: 16)),
                  Text('$m:$s', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _tick,
                    icon: Icon(_run ? Icons.pause : Icons.play_arrow),
                    label: Text(_run ? 'Пауза' : 'Старт'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
