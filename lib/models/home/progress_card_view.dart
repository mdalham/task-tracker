import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../service/note/provider/notes_provider.dart';
import '../../service/task/provider/task_provider.dart';
import '../../service/todo/provider/todo_provider.dart'; // ✅ Add TodoProvider

class ProgressCardView extends StatefulWidget {
  final VoidCallback onOpen;
  const ProgressCardView({super.key, required this.onOpen});

  @override
  State<ProgressCardView> createState() => _ProgressCardViewState();
}

class _ProgressCardViewState extends State<ProgressCardView> {

  late TaskProvider taskProvider;
  late NoteProvider noteProvider;
  late TodoProvider todoProvider; // ✅ Add TodoProvider
  Timer? _updateTimer;
  Timer? _debounceTimer;
  StreamSubscription? _firestoreSubscription;
  final bool enableFirestoreSync = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? get currentUser => _auth.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int taskCount = 0;
  int completedCount = 0;
  int pendingCount = 0;
  int notesCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      taskProvider = Provider.of<TaskProvider>(context, listen: false);
      noteProvider = Provider.of<NoteProvider>(context, listen: false);
      todoProvider = Provider.of<TodoProvider>(context, listen: false); // ✅ Initialize

      // Listen to any change in tasks/notes/todos
      taskProvider.addListener(refreshStats);
      noteProvider.addListener(refreshStats);
      todoProvider.addListener(refreshStats); // ✅ Add listener

      if (currentUser != null) {
        refreshStats();           // First load
        _schedulePeriodicUpdate();
        if (enableFirestoreSync) {
          _listenToFirestoreChanges();
        }
      }
      widget.onOpen.call();
    });
  }

  @override
  void dispose() {
    taskProvider.removeListener(refreshStats);
    noteProvider.removeListener(refreshStats);
    todoProvider.removeListener(refreshStats); // ✅ Remove listener
    _updateTimer?.cancel();
    _firestoreSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  static double _scale(BuildContext context) {
    final width = MediaQuery.of(context).size.shortestSide;
    if (width < 360) return 0.85;
    if (width < 400) return 1.0;
    if (width < 600) return 1.1;
    return 1.4;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Consumer3<TaskProvider, NoteProvider, TodoProvider>( // ✅ Add TodoProvider
      builder: (context, taskProvider, noteProvider, todoProvider, _) {
        //DATA FROM PROVIDERS
        final completed = taskProvider.completedTasks.length;
        final inProcess = taskProvider.inProgressTasks.length;
        final toDaysTask = taskProvider.todayTasks.length;
        final totalTasks = completed + inProcess + toDaysTask;

        final totalNotes = noteProvider.notes.length;
        final totalTodos = todoProvider.todos.length; // ✅ Get total todos

        // Avoid division by zero
        final total = totalTasks > 0 ? totalTasks : 1;
        debugPrint('Total task: $total');

        final donePercent = completed / total;
        final inProcessPercent = inProcess / total;
        final upcomingPercent = toDaysTask / total;

        final taskCompletionPercent = (completed + inProcess) / total;

        final media = MediaQuery.of(context).size;
        final scale = _scale(context);
        double cardHeight = (media.height * 0.22 * scale)
            .clamp(210, 280);

        double progressBarHeight = (media.shortestSide * 0.02 * scale)
            .clamp(14, 15);

        return Container(
          height: cardHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // LEFT SIDE: STATS
              Positioned(
                left: 15,
                top: 15,
                bottom: 15,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      "Overview",
                      style: textTheme.titleMedium!.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _miniStatBox(
                          "Completed",
                          completed.toString(),
                          Colors.deepPurpleAccent,
                          textTheme,
                        ),
                        const SizedBox(width: 8),
                        _miniStatBox(
                          "In Process",
                          inProcess.toString(),
                          Colors.amber,
                          textTheme,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _miniStatBox(
                          "Todo",
                          totalTodos.toString(), // ✅ Show total todos count
                          Colors.orange,
                          textTheme,
                        ),
                        const SizedBox(width: 8),
                        _miniStatBox(
                          "Notes",
                          totalNotes.toString(),
                          Colors.greenAccent,
                          textTheme,
                        ),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(width: 6),
                    Text(
                      "${_getTrendText(taskCompletionPercent)} from last week",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // RIGHT SIDE: Circular Progress + Legend
              Positioned(
                right: 15,
                top: 15,
                bottom: 15,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.width * 0.35,
                      width: MediaQuery.of(context).size.width * 0.35,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return CustomPaint(
                            painter: MultiColorProgressPainter(
                              donePercent: donePercent * value,
                              todoPercent: inProcessPercent * value,
                              pendingPercent: upcomingPercent * value,
                              strokeWid: progressBarHeight,
                            ),
                            child: child,
                          );
                        },
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                totalTasks.toString(),
                                style: textTheme.titleLarge!.copyWith(
                                  color: Colors.white,
                                  fontSize: 28,
                                ),
                              ),
                              Text(
                                "Total tasks",
                                style: textTheme.labelMedium!.copyWith(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        LegendItem(
                          color: Colors.orange,
                          percent: (upcomingPercent * 100).toInt(),
                          label: "Today Tasks",
                          textTheme: textTheme,
                        ),
                        const SizedBox(width: 8),
                        LegendItem(
                          color: Colors.amber,
                          percent: (inProcessPercent * 100).toInt(),
                          label: "In Process",
                          textTheme: textTheme,
                        ),
                        const SizedBox(width: 8),
                        LegendItem(
                          color: Colors.deepPurpleAccent,
                          percent: (donePercent * 100).toInt(),
                          label: "Completed",
                          textTheme: textTheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStatBox(
      String title,
      String value,
      Color color,
      TextTheme textTheme,
      ) {
    return Container(
      width: MediaQuery.of(context).size.width *0.18,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: textTheme.bodyLarge!.copyWith(color: color)),
          Text(
            title,
            style: textTheme.labelSmall!.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getTrendText(double completion) {
    if (completion >= 0.7) return "Increase";
    if (completion >= 0.4) return "Increase";
    return "Decrease";
  }


  // Public method to manually trigger stats update
  void refreshStats() {
    if (!mounted) return;
    _fetchStatsFromProviders();
    _updateStatsToFirebase();
  }

  void _listenToFirestoreChanges() {
    if (!enableFirestoreSync || currentUser == null) return;

    try {
      _firestoreSubscription = _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots()
          .handleError((error) {
        print('❌ Firestore stream error: $error');
        return null;
      })
          .listen(
            (snapshot) {
          if (snapshot != null && snapshot.exists && mounted) {
            try {
              final data = snapshot.data()!;
              setState(() {
                taskCount = data['taskCount'] ?? taskCount;
                completedCount = data['completedCount'] ?? completedCount;
                pendingCount = data['pendingCount'] ?? pendingCount;
                notesCount = data['notesCount'] ?? notesCount;
              });
              print('🔄 Stats synced from Firebase');
            } catch (e) {
              print('⚠️ Error reading Firestore data: $e');
            }
          }
        },
        onError: (error) {
          print('❌ Firestore listener error (ignored): $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('⚠️ Could not initialize Firestore listener: $e');
    }
  }

  Future<void> _updateStatsToFirebase() async {
    if (!enableFirestoreSync || currentUser == null) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 90), () async {
      try {
        final total = taskProvider.allTasks.length;
        final completed = taskProvider.completedTasks.length;
        final pending = taskProvider.inProgressTasks.length + taskProvider.todayTasks.length;
        final notes = noteProvider.notes.length;
        final todos = todoProvider.todos.length; // ✅ Add todos count

        await _firestore.collection('users').doc(currentUser!.uid).set({
          'taskCount': total,
          'completedCount': completed,
          'pendingCount': pending,
          'notesCount': notes,
          'todoCount': todos, // ✅ Save todo count to Firebase
          'lastUpdated': FieldValue.serverTimestamp(),
          'displayName': currentUser!.displayName ?? 'User',
          'email': currentUser!.email,
          'photoURL': currentUser!.photoURL,
        }, SetOptions(merge: true));

        print('✅ Stats synced to Firebase (debounced)');
      } catch (e) {
        print('❌ Firebase sync failed: $e');
      }
    });
  }


  void _schedulePeriodicUpdate() {
    // Update every hour instead of 24 hours for better accuracy
    _updateTimer = Timer.periodic(const Duration(hours: 1), (_) async {
      await _updateStatsToFirebase();
    });
  }

  void _fetchStatsFromProviders() {
    if (!mounted || taskProvider == null || noteProvider == null) return;

    final completed = taskProvider.completedTasks.length;
    final inProcess = taskProvider.inProgressTasks.length;
    final todayTasks = taskProvider.todayTasks.length;
    final totalTasks = taskProvider.allTasks.length;
    final todos = todoProvider.todos.length; // ✅ Get todos count

    if (mounted) {
      setState(() {
        taskCount = totalTasks;
        completedCount = completed;
        pendingCount = inProcess + todayTasks;
        notesCount = noteProvider.notes.length;
      });

      print('📊 Stats Updated: Tasks=$taskCount, Completed=$completedCount, Pending=$pendingCount, Notes=$notesCount, Todos=$todos');
    }
  }
}

class LegendItem extends StatelessWidget {
  final Color color;
  final int percent;
  final String label;
  final TextTheme textTheme;

  const LegendItem({
    super.key,
    required this.color,
    required this.percent,
    required this.label,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              "$percent%",
              style: textTheme.labelMedium!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: textTheme.labelMedium!.copyWith(
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class MultiColorProgressPainter extends CustomPainter {
  final double donePercent;
  final double todoPercent;
  final double pendingPercent;
  final double strokeWid;


  MultiColorProgressPainter({
    required this.donePercent,
    required this.todoPercent,
    required this.pendingPercent,
    required this.strokeWid,

  });

  @override
  void paint(Canvas canvas, Size size,) {
    final double strokeWidth = strokeWid;
    final radius = min(size.width / 2, size.height / 2) - strokeWidth / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -pi / 2;

    // COMPLETED
    paint.color = Colors.deepPurpleAccent;
    canvas.drawArc(rect, startAngle, 2 * pi * donePercent, false, paint);

    // IN PROCESS (AFTER 24H)
    paint.color = Colors.amber;
    canvas.drawArc(
      rect,
      startAngle + 2 * pi * donePercent,
      2 * pi * todoPercent,
      false,
      paint,
    );

    // UPCOMING (TODAY)
    paint.color = Colors.orange;
    canvas.drawArc(
      rect,
      startAngle + 2 * pi * (donePercent + todoPercent),
      2 * pi * pendingPercent,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}