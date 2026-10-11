import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit),
  );
  runApp(const StudyTrackerApp());
}

class StudyTrackerApp extends StatefulWidget {
  const StudyTrackerApp({super.key});

  @override
  State<StudyTrackerApp> createState() => _StudyTrackerAppState();
}

class _StudyTrackerAppState extends State<StudyTrackerApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    final androidImpl = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('theme_mode') ?? 2;
    setState(() => _themeMode = ThemeMode.values[index]);
  }

  Future<void> _changeTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFF111418),
      ),
      home: HomeScreen(
        currentThemeMode: _themeMode,
        onThemeChanged: _changeTheme,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _streakDays = 5;
  int _totalHours = 42;
  int _completedSessions = 18;
  String _userName = 'Студент';
  int _selectedAvatarIndex = 0;

  bool _isTimerRunning = false;
  int _timerSeconds = 20 * 60;
  Timer? _timer;

  final List<IconData> _avatars = const [
    Icons.local_fire_department,
    Icons.school,
    Icons.rocket_launch,
    Icons.sports_esports,
    Icons.bolt,
    Icons.psychology,
  ];

  final List<String> _weekDays = const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  final List<bool> _weekActive = [true, true, true, true, true, false, false];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _streakDays = prefs.getInt('streak_days') ?? 5;
      _userName = prefs.getString('user_name') ?? 'Студент';
      _selectedAvatarIndex = prefs.getInt('avatar_index') ?? 0;
      _completedSessions = prefs.getInt('completed_sessions') ?? 18;
    });
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('streak_days', _streakDays);
    await prefs.setString('user_name', _userName);
    await prefs.setInt('avatar_index', _selectedAvatarIndex);
    await prefs.setInt('completed_sessions', _completedSessions);
  }

  Future<void> _showSessionFinishedNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'study_channel',
      'Занятия и фокус',
      importance: Importance.max,
      priority: Priority.high,
    );
    await flutterLocalNotificationsPlugin.show(
      0,
      '🔥 Сессия завершена!',
      'Отличная работа! 20 минут фокуса засчитаны, стрик увеличен.',
      const NotificationDetails(android: androidDetails),
    );
  }

  void _startTimer() {
    setState(() => _isTimerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _finishSession();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isTimerRunning = false);
  }

  void _finishSession() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _timerSeconds = 20 * 60;
      _streakDays += 1;
      _completedSessions += 1;
      _totalHours += 1;
    });
    _saveUserData();
    _showSessionFinishedNotification();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Сессия окончена! Уведомление отправлено, стрик вырос!'),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  String _formatTimer(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _openAvatarPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Выбери аватар', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: List.generate(_avatars.length, (idx) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedAvatarIndex = idx);
                    _saveUserData();
                    Navigator.pop(ctx);
                  },
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: _selectedAvatarIndex == idx
                        ? Colors.deepOrange
                        : Colors.grey.withOpacity(0.2),
                    child: Icon(_avatars[idx], color: Colors.white),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _openNameDialog() {
    final c = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сменить имя'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Имя профиля')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                setState(() => _userName = c.text.trim());
                _saveUserData();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(widget.currentThemeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Сменить тему',
            onPressed: () {
              widget.onThemeChanged(
                widget.currentThemeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Тест уведомления',
            onPressed: _showSessionFinishedNotification,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ПРОФИЛЬ
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _openAvatarPicker,
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.deepOrange.withOpacity(0.2),
                      child: Icon(_avatars[_selectedAvatarIndex], size: 36, color: Colors.deepOrange),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              onPressed: _openNameDialog,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🔥 Стрик: $_streakDays дней',
                            style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // КАЛЕНДАРЬ СТРИКА ПО ДНЯМ НЕДЕЛИ
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Активность на неделе', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final done = _weekActive[i];
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: done ? Colors.deepOrange : Colors.grey.withOpacity(0.2),
                            child: Icon(
                              done ? Icons.local_fire_department : Icons.circle_outlined,
                              size: 18,
                              color: done ? Colors.white : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_weekDays[i], style: const TextStyle(fontSize: 12)),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // СТАТИСТИКА
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green),
                        const SizedBox(height: 6),
                        Text('$_completedSessions', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('Сессий', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.blueAccent),
                        const SizedBox(height: 6),
                        Text('$_totalHours ч.', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('Всего часов', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ТАЙМЕР ЗАНЯТИЙ
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Фокус-сессия', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    _formatTimer(_timerSeconds),
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 2),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: _startTimer,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Старт'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _pauseTimer,
                        icon: const Icon(Icons.pause),
                        label: const Text('Пауза'),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.done, color: Colors.green),
                        tooltip: 'Завершить досрочно',
                        onPressed: _finishSession,
                      ),
                    ],
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
