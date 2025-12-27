import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tasktracker/screen/login/login_notice.dart';
import 'package:tasktracker/widget/custom_snack_bar.dart';

class PermissionHandler {
  static const _firstTimeKey = 'seenFirstTimeDialog';
  static const _permissionAskedKey = 'permissions_asked';
  static const _lastRunKey = 'last_startup_check'; // ✅ NEW
  static bool _isRunning = false; // ✅ NEW: Prevent concurrent runs

  // Track if login dialog was shown THIS SESSION
  static bool _hasShownLoginThisSession = false;

  // Main Entry Point

  /// This will run every time the app starts
  static Future<void> checkAndShowDialogs(BuildContext context) async {
    if (!context.mounted) return;

    // ✅ Prevent multiple simultaneous runs
    if (_isRunning) {
      debugPrint('⏭️ Startup check already running, skipping...');
      return;
    }

    _isRunning = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ Debounce: Don't run if we just ran within last 3 seconds
      final lastRun = prefs.getString(_lastRunKey);
      if (lastRun != null) {
        final lastRunTime = DateTime.tryParse(lastRun);
        if (lastRunTime != null &&
            DateTime.now().difference(lastRunTime).inSeconds < 3) {
          debugPrint('⏭️ Startup check ran recently, skipping...');
          return;
        }
      }

      await prefs.setString(_lastRunKey, DateTime.now().toIso8601String());


      // 1. Show "Just a Heads-Up" only ONCE ever
      final seenFirstTime = prefs.getBool(_firstTimeKey) ?? false;
      if (!seenFirstTime) {
        await prefs.setBool(_firstTimeKey, true);
        await _showFirstTimeDialog(context);
        if (!context.mounted) return;

        await Future.delayed(const Duration(milliseconds: 600));
        if (!context.mounted) return;
      }

      // 2. Request Permissions (once per install)
      await checkAndRequestPermissions(context);
      if (!context.mounted) return;

      await Future.delayed(const Duration(milliseconds: 400));
      if (!context.mounted) return;

      // 3. Show Login dialog ONLY ONCE per app session
      final user = FirebaseAuth.instance.currentUser;
      if (user == null && !_hasShownLoginThisSession) {
        _hasShownLoginThisSession = true;
        await _showLoginDialog(context);
      }
    } finally {
      _isRunning = false; // ✅ Always reset flag
    }
  }

  // First Time Dialog (Data Warning)
  /// Private — only warning dialog (shown once)
  /// ✅ CHANGED: Returns Future<void> and waits for dialog to close
  static Future<void> _showFirstTimeDialog(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colorScheme.outline, width: 1.5),
        ),
        title: Text(
          "Just a Heads-Up",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: colorScheme.primary,
          ),
        ),
        content: const Text(
          "If you uninstall the app, your saved tasks and notes will be permanently deleted. "
          "Make sure to back up anything important before removing the app. "
          "Thanks for using Notes!",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Got it!", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  // Login Dialog
  /// Private — login dialog (shown once per session when not logged in)
  static Future<void> _showLoginDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => LoginNotice(),
    );
  }

  // Permission Handling

  /// Check and request necessary permissions when app opens
  static Future<void> checkAndRequestPermissions(BuildContext context) async {
    if (!context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasAskedBefore = prefs.getBool(_permissionAskedKey) ?? false;

    // Only show permission dialog once
    if (!hasAskedBefore) {
      await prefs.setBool(_permissionAskedKey, true);

      if (!context.mounted) return;
      await Future.delayed(const Duration(milliseconds: 400));
      final shouldRequest = await _showPermissionDialog(context);

      if (shouldRequest && context.mounted) {
        await _requestPermissions();

        // Show results after requesting
        if (context.mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _showPermissionResults(context);
        }
      }
    } else {
      // Still check silently if permissions are granted
      await _checkPermissionsSilently();
    }
  }

  /// Main permission request method
  static Future<void> _requestPermissions() async {
    // Notification Permission
    if (!await Permission.notification.isGranted) {
      await Permission.notification.request();
    }
    // Schedule Exact Alarm
    if (!await Permission.scheduleExactAlarm.isGranted) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  /// Show dialog explaining why we need permissions
  static Future<bool> _showPermissionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PermissionRequestDialog(),
    );

    return result ?? false;
  }

  /// Check permissions silently (no dialogs)
  static Future<void> _checkPermissionsSilently() async {
    final notificationGranted = await Permission.notification.isGranted;
    final alarmGranted = await Permission.scheduleExactAlarm.isGranted;

    debugPrint('📱 Permissions Status:');
    debugPrint('  • Notifications: ${notificationGranted ? "✅" : "❌"}');
    debugPrint('  • Exact Alarms: ${alarmGranted ? "✅" : "❌"}');
  }

  /// Show dialog with permission results
  static Future<void> _showPermissionResults(BuildContext context) async {
    final notificationGranted = await Permission.notification.isGranted;
    final alarmGranted = await Permission.scheduleExactAlarm.isGranted;

    if (!context.mounted) return;

    // Only show if something is missing
    if (!notificationGranted || !alarmGranted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permissions Needed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!notificationGranted) ...[
                const Text('Notifications - Required for reminders'),
                const SizedBox(height: 8),
              ],
              if (!alarmGranted) ...[
                const Text('Exact Alarms - Required for precise reminders'),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              const Text(
                'Without these permissions, your task and note reminders may not work properly.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    } else {
      // All permissions granted - show success briefly
      CustomSnackBar.show(
        context,
        message: 'Permissions granted! Reminders are ready.',
        type: SnackBarType.success
      );
    }
  }

  // Public Utility Methods

  /// Public method to request permissions from anywhere in the app
  static Future<void> requestPermissions() async {
    await _requestPermissions();
  }

  /// Check if all required permissions are granted
  static Future<bool> arePermissionsGranted() async {
    final notificationGranted = await Permission.notification.isGranted;
    final alarmGranted = await Permission.scheduleExactAlarm.isGranted;
    return notificationGranted && alarmGranted;
  }

  /// Reset permission check (for testing)
  static Future<void> resetPermissionCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_permissionAskedKey);
    debugPrint('🔄 Permission check reset - will ask again on next app start');
  }
}

// ============================================================================
// Permission Request Dialog Widget
// ============================================================================

class _PermissionRequestDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.notifications_active, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text('Enable Reminders',style: textTheme.titleLarge,),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            'Task Tracker needs permissions to send you reminders:',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _buildPermissionItem(
            Icons.notifications_outlined,
            'Notifications',
            'Get notified when tasks are due',
            colorScheme,
            textTheme,
          ),
          const SizedBox(height: 12),
          _buildPermissionItem(
            Icons.alarm,
            'Exact Alarms',
            'Receive reminders at precise times',
            colorScheme,
            textTheme,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                 Expanded(
                  child: Text(
                    'You can change this anytime in Settings',
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Not Now',
            style: textTheme.titleMedium,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check, size: 18),
          label: Text('Allow', style: textTheme.titleMedium!.copyWith(
            color: Colors.white
          )),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionItem(
    IconData icon,
    String title,
    String description,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(description, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
