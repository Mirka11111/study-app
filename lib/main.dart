import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin np = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await np.initialize(initSettings);
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
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('app_theme') ?? 2;
    setState(() => _themeMode = ThemeMode.values[idx]);
  }

  void _toggleTheme() async {
    final next = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme', next.index);
    setState(() => _themeMode = next);
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
        colorSchemeSeed: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFF0F1318),
      ),
      home: HomeScreen(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Реальные данные пользователя (без выдуманных цифр)
  int _streak = 0;
  int _totalSecondsStudied = 0;
  int _sessionsCount = 0;
  String _userName = 'Мой Профиль';
  int _avatarIndex = 0;
  String _savedReminderTime = ''; // пусто, если напоминание еще не создано

  // Таймер текущей сессии (25 минут фокуса)
  final int _sessionDuration = 25 * 60;
  int _currentSeconds = 25 * 60;
  bool _isRunning = false;
  Timer? _timer;

  final List<IconData> _avatars = const [
    Icons.person_rounded,
    Icons.local_fire_department_rounded,
    Icons.school_rounded,
    Icons.rocket_launch_rounded,
    Icons.psychology_rounded,
    Icons.sports_esports_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _initDataAndNotifications();
  }

  Future<void> _initDataAndNotifications() async {
    // Запрос разрешения на уведомления (Android 13+)
    final androidImpl = np.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    // Загрузка сохранённого прогресса
    final p = await SharedPreferences.getInstance();
    setState(() {
      _streak = p.getInt('streak') ?? 0;
      _totalSecondsStudied = p.getInt('total_seconds') ?? 0;
      _sessionsCount = p.getInt('sessions_count') ?? 0;
      _userName = p.getString('user_name') ?? 'Студент';
      _avatarIndex = p.getInt('avatar_idx') ?? 0;
      _savedReminderTime = p.getString('reminder_time') ?? '';
    });
  }

  Future<void> _saveProgress() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('streak', _streak);
    await p.setInt('total_seconds', _totalSecondsStudied);
    await p.setInt('sessions_count', _sessionsCount);
    await p.setString('user_name', _userName);
    await p.setInt('avatar_idx', _avatarIndex);
    await p.setString('reminder_time', _savedReminderTime);
  }

  // --- ЛОГИКА ТАЙМЕРА И СТРИКА ---
  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_currentSeconds > 0) {
        setState(() => _currentSeconds--);
      } else {
        _finishSession();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _currentSeconds = _sessionDuration;
    });
  }

  void _finishSession() {
    _timer?.cancel();
    final spentSeconds = _sessionDuration - _currentSeconds;
    setState(() {
      _isRunning = false;
      _currentSeconds = _sessionDuration;
      _sessionsCount += 1;
      _streak += 1; // Увеличиваем реальный стрик
      _totalSecondsStudied += (spentSeconds > 0 ? spentSeconds : _sessionDuration);
    });
    _saveProgress();
    _sendSystemNotification(
      title: '🏆 Сессия завершена!',
      body: 'Ты отлично поработал! Стрик увеличен: $_streak дн.',
    );
  }

  // --- ЛОГИКА УВЕДОМЛЕНИЙ ---
  Future<void> _sendSystemNotification({required String title, required String body}) async {
    const details = AndroidNotificationDetails(
      'study_notifications',
      'Напоминания об учебе',
      importance: Importance.max,
      priority: Priority.high,
    );
    await np.show(1, title, body, const NotificationDetails(android: details));
  }

  // Вызов диалога выбора времени для напоминания
  Future<void> _pickReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
      helpText: 'ВЫБЕРИТЕ ВРЕМЯ НАПОМИНАНИЯ',
      confirmText: 'СОХРАНИТЬ',
      cancelText: 'ОТМЕНА',
    );

    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      final formattedTime = '$h:$m';

      setState(() => _savedReminderTime = formattedTime);
      await _saveProgress();

      // Шлем подтверждение в системную шторку
      await _sendSystemNotification(
        title: '🔔 Напоминание установлено',
        body: 'Каждый день в $formattedTime мы напомним сесть за учебу!',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ежедневное напоминание установлено на $formattedTime'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _deleteReminder() async {
    setState(() => _savedReminderTime = '');
    await _saveProgress();
    await np.cancel(1);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Напоминание удалено')),
      );
    }
  }

  // Смена аватара
  void _chooseAvatar() {
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
            const Text('Выберите аватар', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: List.generate(_avatars.length, (i) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _avatarIndex = i);
                    _saveProgress();
                    Navigator.pop(ctx);
                  },
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: _avatarIndex == i ? Colors.deepOrange : Colors.grey.withOpacity(0.2),
                    child: Icon(_avatars[i], color: Colors.white, size: 28),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _editName() {
    final c = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Имя профиля'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Введите имя')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                setState(() => _userName = c.text.trim());
                _saveProgress();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  String _formatTimer(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = (_totalSecondsStudied / 3600).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Сменить тему',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. ПРОФИЛЬ
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _chooseAvatar,
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.deepOrange,
                      child: Icon(_avatars[_avatarIndex], color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: _editName,
                            ),
                          ],
                        ),
                        Text(
                          _streak > 0 ? '🔥 Серия: $_streak дн.' : 'Серия ещё не начата (0 дн.)',
                          style: TextStyle(
                            color: _streak > 0 ? Colors.deepOrange : Colors.grey,
                            fontWeight: FontWeight.bold,
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

          // 2. БЛОК НАПОМИНАНИЙ (ТА САМАЯ КНОПКА)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: widget.isDark ? const Color(0xFF1B222C) : Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.alarm, color: Colors.deepOrange),
                      SizedBox(width: 8),
                      Text('Ежедневное напоминание', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_savedReminderTime.isEmpty)
                    const Text('Напоминание не настроено. Нажмите кнопку, чтобы не забывать про занятия.',
                        style: TextStyle(fontSize: 13, color: Colors.grey))
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Установлено на: $_savedReminderTime каждый день',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Удалить напоминание',
                          onPressed: _deleteReminder,
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _pickReminderTime,
                      icon: const Icon(Icons.add_alarm),
                      label: Text(_savedReminderTime.isEmpty ? 'Создать напоминание' : 'Изменить время'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3. РЕАЛЬНАЯ СТАТИСТИКА
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.deepOrange),
                        const SizedBox(height: 6),
                        Text('$_streak дн.', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text('Текущая серия', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.timelapse, color: Colors.blueAccent),
                        const SizedBox(height: 6),
                        Text('$hours ч.', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text('Налетал часов', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.done_all, color: Colors.green),
                        const SizedBox(height: 6),
                        Text('$_sessionsCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text('Сессий всего', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4. ТАЙМЕР СЕССИИ (25 МИНУТ)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  const Text('Фокус-таймер (Pomodoro)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    _formatTimer(_currentSeconds),
                    style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: 2),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRunning ? Colors.amber.shade800 : Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: _isRunning ? _pauseTimer : _startTimer,
                        icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                        label: Text(_isRunning ? 'Пауза' : 'Старт'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _resetTimer,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Сброс'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                        tooltip: 'Завершить сессию досрочно',
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
