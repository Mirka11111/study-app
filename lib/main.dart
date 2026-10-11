import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_channel',
          'Напоминания об учебе',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const StudyTrackerApp());
}

class StudyTrackerApp extends StatelessWidget {
  const StudyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Трекер подготовки к экзаменам',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6D00),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _streak = 0;
  DateTime? _sessionStartTime;
  final TextEditingController _taskController = TextEditingController();

  // Минимальное время подготовки (20 минут для реальной учебы)
  final int _minMinutes = 20;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _streak = prefs.getInt('streak') ?? 0;
    });
  }

  // Градация цветов пламени в зависимости от стрика (Duolingo Flame Tiers)
  Map<String, dynamic> _getFlameTheme(int days) {
    if (days >= 30) {
      return {
        'name': 'Изумрудный Огонь Мастера 🌿',
        'color': const Color(0xFF10B981),
        'bg': const Color(0xFFE8F8F0),
        'border': const Color(0xFF6EE7B7),
        'text': const Color(0xFF047857),
        'emoji': '✨🔥',
      };
    } else if (days >= 14) {
      return {
        'name': 'Алмазный Лазурный Огонь 💎',
        'color': const Color(0xFF06B6D4),
        'bg': const Color(0xFFE0F7FA),
        'border': const Color(0xFF67E8F9),
        'text': const Color(0xFF0E7490),
        'emoji': '💎🔥',
      };
    } else if (days >= 7) {
      return {
        'name': 'Аметистовый Огонь 🔮',
        'color': const Color(0xFFA855F7),
        'bg': const Color(0xFFF3E8FF),
        'border': const Color(0xFFD8B4FE),
        'text': const Color(0xFF7E22CE),
        'emoji': '🔮🔥',
      };
    } else if (days >= 3) {
      return {
        'name': 'Яркий Огненный Стрик 🔥',
        'color': const Color(0xFFFF5722),
        'bg': const Color(0xFFFFEDE6),
        'border': const Color(0xFFFFAB91),
        'text': const Color(0xFFD84315),
        'emoji': '🔥',
      };
    } else {
      return {
        'name': 'Начинающий Огонёк 🕯️',
        'color': const Color(0xFFFFA000),
        'bg': const Color(0xFFFFF8E1),
        'border': const Color(0xFFFFE082),
        'text': const Color(0xFFFF8F00),
        'emoji': '🕯️',
      };
    }
  }

  void _startStudySession() {
    setState(() {
      _sessionStartTime = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Сессия подготовки объявлена! Таймер запущен 🚀'),
      ),
    );
  }

  Future<void> _finishStudySession() async {
    if (_sessionStartTime == null) return;

    final duration = DateTime.now().difference(_sessionStartTime!);
    final prefs = await SharedPreferences.getInstance();

    if (duration.inMinutes < _minMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Сессия шла ${duration.inMinutes} мин. Стрик засчитывается от $_minMinutes минут!',
          ),
        ),
      );
      setState(() => _sessionStartTime = null);
      return;
    }

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString('last_study_date');

    if (lastDate != today) {
      setState(() {
        _streak += 1;
      });
      await prefs.setInt('streak', _streak);
      await prefs.setString('last_study_date', today);

      if (mounted) {
        final theme = _getFlameTheme(_streak);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${theme['emoji']} Стрик вырос: $_streak дн.! Ранг: ${theme['name']}'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сессия засчитана! Сегодняшний стрик уже закрыт 👏')),
        );
      }
    }

    setState(() => _sessionStartTime = null);
  }

  Future<void> _scheduleReminder() async {
    if (_taskController.text.trim().isEmpty) return;

    final text = _taskController.text.trim();
    final now = DateTime.now();
    final notifyTime = now.add(const Duration(hours: 1));

    await NotificationService.scheduleNotification(
      id: now.millisecondsSinceEpoch ~/ 1000,
      title: 'Пора готовиться к экзаменам! ⏰',
      body: text,
      scheduledDate: notifyTime,
    );

    _taskController.clear();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Напоминание запланировано на 1 час вперед')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getFlameTheme(_streak);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Экзамены и репетиторы',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Карточка со стриком и динамическим цветом
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme['bg'] as Color,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme['border'] as Color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: (theme['color'] as Color).withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        theme['emoji'] as String,
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_streak дн.',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: theme['text'] as Color,
                            ),
                          ),
                          const Text(
                            'Серия занятий подряд',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme['border'] as Color),
                    ),
                    child: Text(
                      theme['name'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme['text'] as Color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Кнопки управления подготовкой
            if (_sessionStartTime == null)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: const Color(0xFFFF6D00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text(
                  'Объявить начало подготовки',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _startStudySession,
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 26),
                label: const Text(
                  'Завершить и сохранить стрик',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _finishStudySession,
              ),

            const Spacer(),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.notification_add_rounded),
              label: const Text(
                'Добавить занятие / репетитора',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Новое напоминание'),
                    content: TextField(
                      controller: _taskController,
                      decoration: const InputDecoration(
                        hintText: 'Напр.: Профиль математика / Репетитор',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: _scheduleReminder,
                        child: const Text('Сохранить'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
