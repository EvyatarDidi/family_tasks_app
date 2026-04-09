import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://olkxkbzgiizzuuiwromm.supabase.co',
    anonKey: 'sb_publishable_qMmV00FTXvpecYlmYESC1Q_0Yc4Jzjo',
  );
  runApp(const FamilyTaskManager());
}

enum TaskType { text, shopping }
enum TaskVisibility { private, family }

class TaskDescription {
  final TaskType type;
  final String? content;
  final List<Map<String, dynamic>>? items;

  const TaskDescription._({
    required this.type,
    this.content,
    this.items,
  });

  factory TaskDescription.text(String content) {
    return TaskDescription._(type: TaskType.text, content: content);
  }

  factory TaskDescription.shopping(List<Map<String, dynamic>> items) {
    return TaskDescription._(type: TaskType.shopping, items: items);
  }

  Map<String, dynamic> toJson() {
    return switch (type) {
      TaskType.text => {
          'type': 'text',
          'content': content ?? '',
        },
      TaskType.shopping => {
          'type': 'shopping',
          'items': items ?? <Map<String, dynamic>>[],
        },
    };
  }

  static TaskDescription? fromJson(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final type = (map['type'] ?? '').toString();
    if (type == 'shopping') {
      final rawItems = map['items'];
      final items = <Map<String, dynamic>>[];
      if (rawItems is List) {
        for (final it in rawItems) {
          if (it is Map) items.add(Map<String, dynamic>.from(it));
        }
      }
      return TaskDescription.shopping(items);
    }
    if (type == 'text') {
      return TaskDescription.text((map['content'] ?? '').toString());
    }
    return null;
  }
}

class Task {
  final String id;
  final String title;
  final String assignee;
  final TaskVisibility visibility;
  final TaskDescription? description;
  final bool isCompleted;
  final DateTime? completedAt;

  const Task({
    required this.id,
    required this.title,
    required this.assignee,
    required this.visibility,
    required this.description,
    required this.isCompleted,
    required this.completedAt,
  });

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == 't' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == 'f' || v == '0' || v == 'no') return false;
    }
    return false;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  static TaskVisibility _asVisibility(dynamic value) {
    final v = (value ?? 'private').toString().toLowerCase().trim();
    return v == 'family' ? TaskVisibility.family : TaskVisibility.private;
  }

  factory Task.fromRow(Map<String, dynamic> row) {
    return Task(
      id: row['id'].toString(),
      title: (row['title'] ?? '').toString(),
      assignee: (row['assignee'] ?? '').toString(),
      visibility: _asVisibility(row['visibility']),
      description: TaskDescription.fromJson(row['description']),
      isCompleted: _asBool(row['is_completed']),
      completedAt: _asDateTime(row['completed_at']),
    );
  }
}

class BankTask {
  final String id;
  final String title;
  final TaskVisibility visibility;
  final TaskDescription? description;

  const BankTask({
    required this.id,
    required this.title,
    required this.visibility,
    required this.description,
  });

  factory BankTask.fromRow(Map<String, dynamic> row) {
    final v = (row['visibility'] ?? 'private').toString().toLowerCase().trim();
    return BankTask(
      id: row['id'].toString(),
      title: (row['title'] ?? '').toString(),
      visibility: v == 'family' ? TaskVisibility.family : TaskVisibility.private,
      description: TaskDescription.fromJson(row['description']),
    );
  }
}

class FamilyTaskManager extends StatelessWidget {
  const FamilyTaskManager({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ניהול משימות משפחתי',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('he', 'IL')],
      locale: const Locale('he', 'IL'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.teal.shade50,
          foregroundColor: Colors.teal.shade900,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
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
  static const String _prefsCurrentUserKey = 'current_user';

  static const List<String> _identityMembers = <String>[
    'אביתר',
    'צופיה',
    'שרה',
    'בנימין',
  ];

  static const List<String> _members = <String>[
    'אביתר',
    'צופיה',
    'שרה',
    'בנימין',
  ];

  final _supabase = Supabase.instance.client;
  final Map<String, bool> _showCompletedTab = <String, bool>{};
  final Map<String, Set<String>> _sessionCompletedIds = <String, Set<String>>{};

  String? currentUser;

  @override
  void initState() {
    super.initState();
    _initCurrentUser();
  }

  Future<void> _initCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsCurrentUserKey);

    if (!mounted) return;
    setState(() => currentUser = saved);

    if (saved == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _promptForUser(mandatory: true);
      });
    }
  }

  Future<void> _setCurrentUser(String user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCurrentUserKey, user);
    if (!mounted) return;
    setState(() => currentUser = user);
  }

  Future<void> _promptForUser({required bool mandatory}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !mandatory,
      builder: (dialogContext) {
        return PopScope(
          canPop: !mandatory,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('מי משתמש באפליקציה עכשיו?'),
              content: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _identityMembers
                    .map(
                      (m) => FilledButton.tonal(
                        onPressed: () async {
                          await _setCurrentUser(m);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                        child: Text(m),
                      ),
                    )
                    .toList(),
              ),
              actions: mandatory
                  ? null
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('ביטול'),
                      ),
                    ],
            ),
          ),
        );
      },
    );
  }

  Stream<List<Task>> _tasksStream() {
    return _supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map((r) => Task.fromRow(r)).toList());
  }

  Stream<List<BankTask>> _taskBankStream() {
    return _supabase
        .from('task_bank')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map((r) => BankTask.fromRow(r)).toList());
  }

  DateTime _mostRecentSaturdayAt2359(DateTime now) {
    final daysSinceSaturday = (now.weekday - DateTime.saturday) % 7;
    final saturday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysSinceSaturday));
    return DateTime(saturday.year, saturday.month, saturday.day, 23, 59);
  }

  Map<String, int> _weeklyFamilyCompletedCounts(List<Task> allTasks) {
    final cutoff = _mostRecentSaturdayAt2359(DateTime.now());
    final counts = <String, int>{for (final m in _members) m: 0};

    for (final t in allTasks) {
      if (t.visibility != TaskVisibility.family) continue;
      final completedAt = t.completedAt;
      if (completedAt == null) continue;
      if (!completedAt.isAfter(cutoff)) continue;
      if (!counts.containsKey(t.assignee)) continue;
      counts[t.assignee] = (counts[t.assignee] ?? 0) + 1;
    }

    return counts;
  }

  String? _trophyWinner(Map<String, int> counts) {
    String? winner;
    var best = 0;
    for (final e in counts.entries) {
      if (e.value > best) {
        best = e.value;
        winner = e.key;
      }
    }
    return best > 0 ? winner : null;
  }

  Future<void> _openAddTaskSheet() async {
    if (currentUser == null) {
      await _promptForUser(mandatory: true);
      if (!mounted) return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        final titleController = TextEditingController();
        final textDescriptionController = TextEditingController();
        String selectedMember = currentUser ?? _members.first;
        TaskVisibility visibility = TaskVisibility.private;
        TaskType type = TaskType.text;
        final shoppingControllers = <TextEditingController>[TextEditingController()];

        String? titleError;
        String? descError;

        Map<String, dynamic> buildDescriptionJson() {
          return switch (type) {
            TaskType.text => TaskDescription.text(
                textDescriptionController.text.trim(),
              ).toJson(),
            TaskType.shopping => TaskDescription.shopping(
                shoppingControllers
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .map((name) => <String, dynamic>{'name': name, 'done': false})
                    .toList(),
              ).toJson(),
          };
        }

        bool validate(StateSetter setModalState) {
          final title = titleController.text.trim();
          final descText = textDescriptionController.text.trim();
          final shoppingItems = shoppingControllers
              .map((c) => c.text.trim())
              .where((t) => t.isNotEmpty)
              .toList();

          String? newTitleError;
          String? newDescError;

          if (title.isEmpty) newTitleError = 'נא להזין כותרת למשימה';

          if (type == TaskType.text) {
            if (descText.isEmpty) newDescError = 'נא להזין תיאור';
          } else {
            if (shoppingItems.isEmpty) newDescError = 'נא להוסיף לפחות פריט אחד';
          }

          setModalState(() {
            titleError = newTitleError;
            descError = newDescError;
          });

          return newTitleError == null && newDescError == null;
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'הוספת משימה חדשה',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        textAlign: TextAlign.start,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          labelText: 'כותרת משימה',
                          hintText: 'לדוגמה: להוציא את הזבל',
                          prefixIcon: const Icon(Icons.task_alt_outlined),
                          border: const OutlineInputBorder(),
                          errorText: titleError,
                        ),
                        autofocus: true,
                        onChanged: (_) {
                          if (titleError == null) return;
                          setModalState(() => titleError = null);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedMember,
                        decoration: const InputDecoration(
                          labelText: 'למי לשייך?',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        items: (visibility == TaskVisibility.private
                                ? <String>[currentUser!]
                                : _members)
                            .map(
                              (m) => DropdownMenuItem<String>(
                                value: m,
                                child: Text(m, textDirection: TextDirection.rtl),
                              ),
                            )
                            .toList(),
                        onChanged: visibility == TaskVisibility.private
                            ? null
                            : (value) {
                                if (value == null) return;
                                setModalState(() => selectedMember = value);
                              },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<TaskVisibility>(
                        initialValue: visibility,
                        decoration: const InputDecoration(
                          labelText: 'חשיפה',
                          prefixIcon: Icon(Icons.visibility_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: TaskVisibility.family,
                            child: Text('משפחתי'),
                          ),
                          DropdownMenuItem(
                            value: TaskVisibility.private,
                            child: Text('אישי'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() {
                            visibility = value;
                            if (visibility == TaskVisibility.private) {
                              selectedMember = currentUser!;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<TaskType>(
                        segments: const [
                          ButtonSegment(
                            value: TaskType.text,
                            label: Text('טקסט חופשי'),
                            icon: Icon(Icons.text_snippet_outlined),
                          ),
                          ButtonSegment(
                            value: TaskType.shopping,
                            label: Text('רשימת קניות'),
                            icon: Icon(Icons.shopping_cart_outlined),
                          ),
                        ],
                        selected: {type},
                        onSelectionChanged: (s) {
                          setModalState(() {
                            type = s.first;
                            descError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (type == TaskType.text)
                        TextField(
                          controller: textDescriptionController,
                          textDirection: TextDirection.rtl,
                          minLines: 3,
                          maxLines: 6,
                          decoration: InputDecoration(
                            labelText: 'תיאור',
                            hintText: 'מה צריך לעשות?',
                            prefixIcon: const Icon(Icons.description_outlined),
                            border: const OutlineInputBorder(),
                            errorText: descError,
                          ),
                          onChanged: (_) {
                            if (descError == null) return;
                            setModalState(() => descError = null);
                          },
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'פריטים',
                                border: const OutlineInputBorder(),
                                errorText: descError,
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0; i < shoppingControllers.length; i++)
                                    Padding(
                                      padding: EdgeInsets.only(bottom: i == shoppingControllers.length - 1 ? 0 : 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: shoppingControllers[i],
                                              textDirection: TextDirection.rtl,
                                              decoration: InputDecoration(
                                                hintText: 'פריט #${i + 1}',
                                                isDense: true,
                                                border: const OutlineInputBorder(),
                                              ),
                                              onChanged: (_) {
                                                if (descError == null) return;
                                                setModalState(() => descError = null);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: shoppingControllers.length <= 1
                                                ? null
                                                : () {
                                                    setModalState(() {
                                                      shoppingControllers.removeAt(i);
                                                    });
                                                  },
                                            icon: const Icon(Icons.remove_circle_outline),
                                            color: Theme.of(context).colorScheme.error,
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        setModalState(() {
                                          shoppingControllers.add(TextEditingController());
                                        });
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('הוסף פריט'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('ביטול'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                if (!validate(setModalState)) return;

                                final title = titleController.text.trim();
                                final description = buildDescriptionJson();

                                try {
                                  await _supabase.from('tasks').insert({
                                    'title': title,
                                    'assignee': selectedMember,
                                    'visibility': visibility == TaskVisibility.family
                                        ? 'family'
                                        : 'private',
                                    'description': description,
                                    'is_completed': false,
                                    'completed_at': null,
                                  });
                                } catch (e) {
                                  if (!sheetContext.mounted) return;
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                                    SnackBar(
                                      content: Text('שגיאה בהוספת משימה: $e'),
                                    ),
                                  );
                                  return;
                                }

                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext);
                              },
                              child: const Text('הוסף משימה'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openTaskBankSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'בנק משימות',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await _openAddBankTaskDialog(sheetContext);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('הוסף'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<BankTask>>(
                    stream: _taskBankStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('שגיאה בטעינת בנק משימות: ${snapshot.error}'),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final items = snapshot.data ?? const <BankTask>[];
                      if (items.isEmpty) {
                        return const ListTile(
                          leading: Icon(Icons.account_balance_outlined),
                          title: Text('אין משימות בבנק עדיין'),
                        );
                      }

                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final t = items[i];
                            final visLabel = t.visibility == TaskVisibility.family
                                ? 'משפחתי'
                                : 'אישי';
                            return ListTile(
                              leading: const Icon(Icons.inventory_2_outlined),
                              title: Text(t.title),
                              subtitle: Text('חשיפה: $visLabel'),
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () async {
                                await _assignBankTaskToMember(
                                  sheetContext,
                                  bankTask: t,
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddBankTaskDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final textDescriptionController = TextEditingController();
    TaskVisibility visibility = TaskVisibility.family;
    TaskType type = TaskType.text;
    final shoppingControllers = <TextEditingController>[TextEditingController()];
    String? titleError;
    String? descError;

    Map<String, dynamic> buildDescriptionJson() {
      return switch (type) {
        TaskType.text => TaskDescription.text(
            textDescriptionController.text.trim(),
          ).toJson(),
        TaskType.shopping => TaskDescription.shopping(
            shoppingControllers
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .map((name) => <String, dynamic>{'name': name, 'done': false})
                .toList(),
          ).toJson(),
      };
    }

    bool validate(StateSetter setModalState) {
      final title = titleController.text.trim();
      final descText = textDescriptionController.text.trim();
      final shoppingItems = shoppingControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      String? newTitleError;
      String? newDescError;

      if (title.isEmpty) newTitleError = 'נא להזין כותרת למשימה';

      if (type == TaskType.text) {
        if (descText.isEmpty) newDescError = 'נא להזין תיאור';
      } else {
        if (shoppingItems.isEmpty) newDescError = 'נא להוסיף לפחות פריט אחד';
      }

      setModalState(() {
        titleError = newTitleError;
        descError = newDescError;
      });

      return newTitleError == null && newDescError == null;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('הוספת משימה לבנק'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          labelText: 'כותרת משימה',
                          border: const OutlineInputBorder(),
                          errorText: titleError,
                        ),
                        onChanged: (_) {
                          if (titleError == null) return;
                          setModalState(() => titleError = null);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<TaskVisibility>(
                        initialValue: visibility,
                        decoration: const InputDecoration(
                          labelText: 'חשיפה',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: TaskVisibility.family,
                            child: Text('משפחתי'),
                          ),
                          DropdownMenuItem(
                            value: TaskVisibility.private,
                            child: Text('אישי'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() => visibility = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<TaskType>(
                        segments: const [
                          ButtonSegment(
                            value: TaskType.text,
                            label: Text('טקסט חופשי'),
                          ),
                          ButtonSegment(
                            value: TaskType.shopping,
                            label: Text('רשימת קניות'),
                          ),
                        ],
                        selected: {type},
                        onSelectionChanged: (s) {
                          setModalState(() {
                            type = s.first;
                            descError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (type == TaskType.text)
                        TextField(
                          controller: textDescriptionController,
                          textDirection: TextDirection.rtl,
                          minLines: 3,
                          maxLines: 6,
                          decoration: InputDecoration(
                            labelText: 'תיאור',
                            border: const OutlineInputBorder(),
                            errorText: descError,
                          ),
                          onChanged: (_) {
                            if (descError == null) return;
                            setModalState(() => descError = null);
                          },
                        )
                      else
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'פריטים',
                            border: const OutlineInputBorder(),
                            errorText: descError,
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < shoppingControllers.length; i++)
                                Padding(
                                  padding: EdgeInsets.only(bottom: i == shoppingControllers.length - 1 ? 0 : 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: shoppingControllers[i],
                                          textDirection: TextDirection.rtl,
                                          decoration: InputDecoration(
                                            hintText: 'פריט #${i + 1}',
                                            isDense: true,
                                            border: const OutlineInputBorder(),
                                          ),
                                          onChanged: (_) {
                                            if (descError == null) return;
                                            setModalState(() => descError = null);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: shoppingControllers.length <= 1
                                            ? null
                                            : () {
                                                setModalState(() {
                                                  shoppingControllers.removeAt(i);
                                                });
                                              },
                                        icon: const Icon(Icons.remove_circle_outline),
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    setModalState(() {
                                      shoppingControllers
                                          .add(TextEditingController());
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('הוסף פריט'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('ביטול'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (!validate(setModalState)) return;
                      try {
                        await _supabase.from('task_bank').insert({
                          'title': titleController.text.trim(),
                          'visibility':
                              visibility == TaskVisibility.family ? 'family' : 'private',
                          'description': buildDescriptionJson(),
                        });
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('שגיאה בהוספה לבנק: $e')),
                        );
                        return;
                      }
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('הוסף'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _assignBankTaskToMember(
    BuildContext context, {
    required BankTask bankTask,
  }) async {
    String selectedMember = currentUser ?? _members.first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('שייך משימה לבן משפחה'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('משימה: ${bankTask.title}'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedMember,
                      decoration: const InputDecoration(
                        labelText: 'למי לשייך?',
                        border: OutlineInputBorder(),
                      ),
                      items: (bankTask.visibility == TaskVisibility.private
                              ? <String>[currentUser!]
                              : _members)
                          .map(
                            (m) => DropdownMenuItem<String>(
                              value: m,
                              child: Text(m),
                            ),
                          )
                          .toList(),
                      onChanged: bankTask.visibility == TaskVisibility.private
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => selectedMember = v);
                            },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('ביטול'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await _supabase.from('tasks').insert({
                          'title': bankTask.title,
                          'assignee': selectedMember,
                          'visibility': bankTask.visibility == TaskVisibility.family
                              ? 'family'
                              : 'private',
                          'description': bankTask.description?.toJson(),
                          'is_completed': false,
                          'completed_at': null,
                        });
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('שגיאה בשיוך משימה: $e')),
                        );
                        return;
                      }
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('שייך'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Task Manager'),
        actions: [
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: ActionChip(
                  avatar: const Icon(Icons.person, size: 18),
                  label: Text(currentUser!),
                  onPressed: () => _promptForUser(mandatory: false),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'בחר משתמש',
              onPressed: () => _promptForUser(mandatory: true),
              icon: const Icon(Icons.person),
            ),
          IconButton(
            tooltip: 'בנק משימות',
            onPressed: _openTaskBankSheet,
            icon: const Icon(Icons.account_balance),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTaskSheet,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Task>>(
        stream: _tasksStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'שגיאה בטעינת משימות: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (currentUser == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTasks = snapshot.data ?? const <Task>[];
          final visibleTasks = allTasks.where((t) {
            if (t.visibility == TaskVisibility.family) return true;
            // Private tasks are only visible to the assignee (current user).
            return t.assignee == currentUser;
          }).toList();

          final weeklyCounts = _weeklyFamilyCompletedCounts(visibleTasks);
          final trophyWinner = _trophyWinner(weeklyCounts);

          // === לוגיקת לוח הבקרה האישי ===
          final cutoff = _mostRecentSaturdayAt2359(DateTime.now());
          int personalTotalThisWeek = 0;
          int personalCompletedThisWeek = 0;

          for (final t in visibleTasks) {
            if (t.assignee == currentUser && t.visibility == TaskVisibility.private) {
              if (t.isCompleted) {
                if (t.completedAt != null && t.completedAt!.isAfter(cutoff)) {
                  personalTotalThisWeek++;
                  personalCompletedThisWeek++;
                }
              } else {
                personalTotalThisWeek++;
              }
            }
          }

          double personalProgress = personalTotalThisWeek == 0 
              ? 0 
              : personalCompletedThisWeek / personalTotalThisWeek;
          // ================================

          final byAssignee = <String, List<Task>>{
            for (final m in _members) m: <Task>[],
          };

          for (final t in visibleTasks) {
            if (!byAssignee.containsKey(t.assignee)) continue;
            byAssignee[t.assignee]!.add(t);
          }

          return Column(
            children: [
              // === כרטיסיית מאזן אישי שבועי ===
              Card(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'מאזן אישי שבועי',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (personalTotalThisWeek == 0)
                        const Text('אין לך משימות אישיות השבוע. זמן לנוח! 🌴')
                      else ...[
                        Text('$personalCompletedThisWeek מתוך $personalTotalThisWeek הושלמו'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: personalProgress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              // ==================================

              // רשימת בני המשפחה
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final tasks = (byAssignee[member] ?? const <Task>[]).toList()
                      ..sort((a, b) => a.title.compareTo(b.title));

                    final showCompleted = _showCompletedTab[member] ?? false;
                    final sessionCompleted =
                        _sessionCompletedIds.putIfAbsent(member, () => <String>{});

                    final activeTasks = tasks.where((t) {
                      if (!t.isCompleted) return true;
                      return sessionCompleted.contains(t.id);
                    }).toList()
                      ..sort((a, b) {
                        if (a.isCompleted != b.isCompleted) {
                          return a.isCompleted ? 1 : -1;
                        }
                        return a.title.compareTo(b.title);
                      });

                    final completedTasks = tasks.where((t) {
                      if (!t.isCompleted) return false;
                      return !sessionCompleted.contains(t.id);
                    }).toList()
                      ..sort((a, b) {
                        final ad = a.completedAt;
                        final bd = b.completedAt;
                        if (ad == null && bd == null) return a.title.compareTo(b.title);
                        if (ad == null) return 1;
                        if (bd == null) return -1;
                        return bd.compareTo(ad);
                      });

                    return Card(
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          child: const Icon(Icons.person),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                member,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (trophyWinner == member) ...[
                              const SizedBox(width: 8),
                              const Text('🏆'),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          'משימות פתוחות: ${(byAssignee[member] ?? const <Task>[]).length} | הושלמו השבוע (משפחתי): ${weeklyCounts[member] ?? 0}',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('לביצוע'),
                                  selected: !showCompleted,
                                  onSelected: (v) {
                                    setState(() {
                                      _showCompletedTab[member] = false;
                                    });
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('הושלמו'),
                                  selected: showCompleted,
                                  onSelected: (v) {
                                    setState(() {
                                      _showCompletedTab[member] = true;
                                      _sessionCompletedIds[member]?.clear();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (!showCompleted)
                            _TaskListSection(
                              member: member,
                              tasks: activeTasks,
                              sessionCompletedIds: sessionCompleted,
                              onMarkCompletedThisSession: (taskId) {
                                setState(() => sessionCompleted.add(taskId));
                              },
                              onUnmarkThisSession: (taskId) {
                                setState(() => sessionCompleted.remove(taskId));
                              },
                            )
                          else
                            _TaskListSection(
                              member: member,
                              tasks: completedTasks,
                              sessionCompletedIds: sessionCompleted,
                              onMarkCompletedThisSession: (taskId) {
                                setState(() => sessionCompleted.add(taskId));
                              },
                              onUnmarkThisSession: (taskId) {
                                setState(() => sessionCompleted.remove(taskId));
                              },
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TaskListSection extends StatelessWidget {
  final String member;
  final List<Task> tasks;
  final Set<String> sessionCompletedIds;
  final void Function(String taskId) onMarkCompletedThisSession;
  final void Function(String taskId) onUnmarkThisSession;

  const _TaskListSection({
    required this.member,
    required this.tasks,
    required this.sessionCompletedIds,
    required this.onMarkCompletedThisSession,
    required this.onUnmarkThisSession,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.inbox_outlined),
        title: Text('אין משימות כרגע'),
      );
    }

    return Column(
      children: tasks.map((t) => _TaskTile(
            member: member,
            task: t,
            isSessionCompleted: sessionCompletedIds.contains(t.id),
            onMarkCompletedThisSession: onMarkCompletedThisSession,
            onUnmarkThisSession: onUnmarkThisSession,
          )).toList(),
    );
  }
}

class _TaskTile extends StatefulWidget {
  final String member;
  final Task task;
  final bool isSessionCompleted;
  final void Function(String taskId) onMarkCompletedThisSession;
  final void Function(String taskId) onUnmarkThisSession;

  const _TaskTile({
    required this.member,
    required this.task,
    required this.isSessionCompleted,
    required this.onMarkCompletedThisSession,
    required this.onUnmarkThisSession,
  });

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _expanded = false;
  bool _saving = false;
  bool? _optimisticCompleted;

  @override
  void didUpdateWidget(covariant _TaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_optimisticCompleted != null &&
        widget.task.isCompleted == _optimisticCompleted) {
      _optimisticCompleted = null;
    }
  }

  Future<void> _setCompletion(bool newValue) async {
    setState(() {
      _saving = true;
      _optimisticCompleted = newValue;
    });
    try {
      final payload = <String, dynamic>{
        'is_completed': newValue,
        'completed_at': newValue ? DateTime.now().toUtc().toIso8601String() : null,
      };

      await Supabase.instance.client
          .from('tasks')
          .update(payload)
          .eq('id', widget.task.id);

      if (newValue) {
        widget.onMarkCompletedThisSession(widget.task.id);
      } else {
        widget.onUnmarkThisSession(widget.task.id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה בעדכון משימה: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleShoppingItem(int index, bool newValue) async {
    final desc = widget.task.description;
    if (desc == null || desc.type != TaskType.shopping) return;
    final items = (desc.items ?? const <Map<String, dynamic>>[])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (index < 0 || index >= items.length) return;

    items[index]['done'] = newValue;
    final allDone = items.isNotEmpty && items.every((it) => it['done'] == true);
    setState(() {
      _saving = true;
      _optimisticCompleted = allDone;
    });
    try {
      final json = TaskDescription.shopping(items).toJson();
      await Supabase.instance.client
          .from('tasks')
          .update({
            'description': json,
            'is_completed': allDone,
            'completed_at': allDone ? DateTime.now().toUtc().toIso8601String() : null,
          })
          .eq('id', widget.task.id);

      if (allDone) {
        widget.onMarkCompletedThisSession(widget.task.id);
      } else {
        widget.onUnmarkThisSession(widget.task.id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה בעדכון פריט: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final isCompletedVisual = _optimisticCompleted ?? t.isCompleted;

    return ExpansionTile(
      key: PageStorageKey('task-${t.id}'),
      onExpansionChanged: (v) => setState(() => _expanded = v),
      leading: _saving
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Checkbox(
              value: isCompletedVisual,
              onChanged: (v) => _setCompletion(v ?? false),
            ),
      title: Text(
        t.title,
        style: TextStyle(
          decoration: isCompletedVisual
              ? TextDecoration.lineThrough
              : TextDecoration.none,
          color: isCompletedVisual ? Colors.grey : Colors.black,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(
            t.visibility == TaskVisibility.family
                ? Icons.group_outlined
                : Icons.lock_outline,
            size: 14,
            color: Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            t.visibility == TaskVisibility.family ? 'משפחתי' : 'אישי',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
      children: [
        if (!_expanded) const SizedBox.shrink(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _TaskDescriptionView(
            description: t.description,
            onToggleShoppingItem: _toggleShoppingItem,
          ),
        ),
      ],
    );
  }
}

class _TaskDescriptionView extends StatelessWidget {
  final TaskDescription? description;
  final Future<void> Function(int index, bool newValue) onToggleShoppingItem;

  const _TaskDescriptionView({
    required this.description,
    required this.onToggleShoppingItem,
  });

  @override
  Widget build(BuildContext context) {
    final desc = description;
    if (desc == null) {
      return const Text('אין תיאור');
    }

    return switch (desc.type) {
      TaskType.text => Align(
          alignment: Alignment.centerRight,
          child: Text(
            (desc.content ?? '').isEmpty ? 'אין תיאור' : desc.content!,
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      TaskType.shopping => Column(
          children: [
            if ((desc.items ?? const []).isEmpty)
              const ListTile(
                leading: Icon(Icons.shopping_cart_outlined),
                title: Text('אין פריטים'),
              )
            else
              for (var i = 0; i < (desc.items ?? const []).length; i++)
                Builder(
                  builder: (context) {
                    final item = (desc.items ?? const [])[i];
                    final name = (item['name'] ?? '').toString();
                    final done = (item['done'] == true);
                    return CheckboxListTile(
                      value: done,
                      onChanged: (v) => onToggleShoppingItem(i, v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        name,
                        style: TextStyle(
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? Colors.grey : Colors.black,
                        ),
                      ),
                      dense: true,
                    );
                  },
                ),
          ],
        ),
    };
  }
}