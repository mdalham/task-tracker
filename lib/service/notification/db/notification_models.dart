class NotificationHistory {
  int? id;
  final int taskId;
  final String taskTitle;
  final String notificationType;
  final DateTime sentAt;
  final String taskDescription;
  final String taskCategory;
  final String taskPriority;
  final DateTime? taskDate;

  // ADD THIS
  bool isRead; // ← NEW

  NotificationHistory({
    this.id,
    required this.taskId,
    required this.taskTitle,
    required this.notificationType,
    required this.sentAt,
    required this.taskDescription,
    required this.taskCategory,
    required this.taskPriority,
    this.taskDate,
    this.isRead = false, // default unread
  });

  // UPDATE toMap & fromMap
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'notificationType': notificationType,
      'sentAt': sentAt.millisecondsSinceEpoch,
      'taskDescription': taskDescription,
      'taskCategory': taskCategory,
      'taskPriority': taskPriority,
      'taskDate': taskDate?.millisecondsSinceEpoch,
      'isRead': isRead ? 1 : 0, // ← NEW
    };
  }

  factory NotificationHistory.fromMap(Map<String, dynamic> map) {
    return NotificationHistory(
      id: map['id'],
      taskId: map['taskId'],
      taskTitle: map['taskTitle'],
      notificationType: map['notificationType'],
      sentAt: DateTime.fromMillisecondsSinceEpoch(map['sentAt']),
      taskDescription: map['taskDescription'],
      taskCategory: map['taskCategory'],
      taskPriority: map['taskPriority'],
      taskDate: map['taskDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['taskDate'])
          : null,
      isRead: map['isRead'] == 1, // ← NEW
    );
  }
}