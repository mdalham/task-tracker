import 'dart:developer';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:facebook_audience_network/facebook_audience_network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helper class/permission_handler.dart';
import '../../service/ads/notic/consent_ads_helper.dart';
import '../../service/notification/service/notification_service.dart';
import 'subscription_screen.dart';
import '../main/nav_bar_screen.dart';
import 'package:workmanager/workmanager.dart';
import '../../service/subscription/subscription_provider.dart';


class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer>
    with WidgetsBindingObserver {

  static const String _subscriptionPromptShownKey = 'subscription_prompt_shown';
  static const String _lastPromptDateKey = 'last_subscription_prompt_date';

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      if (!mounted) return;

      try {
        final subscriptionProvider = context.read<SubscriptionProvider>();

        await _initializeGoogleSignIn();

        if (!subscriptionProvider.isSubscribed) {
          debugPrint('User not subscribed - initializing ads');
          await _initializeAds();
        } else {
          debugPrint('User subscribed - skipping ad initialization');
        }

        await _initializeBackgroundServices();

      } catch (e) {
        debugPrint('Error in microtask initialization: $e');
      }
    });

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          await PermissionHandler.checkAndShowDialogs(context);
        }

        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          await _checkAndForceUpdate();
        }

        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          final subscriptionProvider = context.read<SubscriptionProvider>();

          if (!subscriptionProvider.isSubscribed) {
            final consentHelper = ConsentAdsHelper();
            await consentHelper.initializeConsent();
            debugPrint('Ad consent initialized');
          } else {
            debugPrint('User subscribed - skipping ad consent');
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          await requestIgnoreBatteryOptimizations();
        }

        debugPrint('App initialization completed successfully');

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          await _showSubscriptionPromptIfNeeded();
        }

      } catch (e) {
        debugPrint('Error in post-frame initialization: $e');
      }
    });
  }

  Future<void> _showSubscriptionPromptIfNeeded() async {
    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();

      if (subscriptionProvider.isSubscribed) {
        debugPrint('User already subscribed - skipping prompt');
        return;
      }

      final shouldShow = await _shouldShowSubscriptionPrompt();

      if (!shouldShow) {
        debugPrint('Subscription prompt already shown in last 24 hours');
        return;
      }

      debugPrint('Showing subscription screen to free user');

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SubscriptionScreen(),
          ),
        );

        await _markSubscriptionPromptShown();
      }

    } catch (e) {
      debugPrint('Error showing subscription prompt: $e');
    }
  }


  Future<bool> _shouldShowSubscriptionPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final lastPromptTimestamp = prefs.getInt(_lastPromptDateKey);

      if (lastPromptTimestamp == null) {
        debugPrint('Subscription prompt: Never shown - will show now');
        return true;
      }

      final lastPromptDate = DateTime.fromMillisecondsSinceEpoch(lastPromptTimestamp);
      final now = DateTime.now();
      final hoursSinceLastPrompt = now.difference(lastPromptDate).inHours;

      if (hoursSinceLastPrompt >= 24) {
        debugPrint('Subscription prompt: $hoursSinceLastPrompt hours passed - will show');
        return true;
      } else {
        final hoursRemaining = 24 - hoursSinceLastPrompt;
        debugPrint('Subscription prompt: Only $hoursSinceLastPrompt hours passed - skipping (will show in $hoursRemaining hours)');
        return false;
      }

    } catch (e) {
      debugPrint('Error checking subscription prompt status: $e');
      return false;
    }
  }


  Future<void> _markSubscriptionPromptShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_subscriptionPromptShownKey, true);
      await prefs.setInt(_lastPromptDateKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('Subscription prompt marked as shown at ${DateTime.now()}');
    } catch (e) {
      debugPrint('Error marking subscription prompt: $e');
    }
  }


  Future<void> _initializeGoogleSignIn() async {
    try {
      await GoogleSignIn().signInSilently();
      debugPrint('Google Sign-In silent success');
    } catch (e) {
      debugPrint('Google Sign-In skipped: $e');
    }
  }


  Future<void> _initializeAds() async {
    try {
      await FacebookAudienceNetwork.init();
      debugPrint('Facebook Audience Network initialized');
    } catch (e) {
      debugPrint('Facebook Ads init failed: $e');
    }

    try {
      UnityAds.init(
        gameId: '6009336',
        testMode: false,
        onComplete: () {
          debugPrint('Unity Ads initialized successfully');
        },
        onFailed: (error, message) {
          debugPrint('Unity Ads init failed: $error - $message');
        },
      );
    } catch (e) {
      debugPrint('Unity Ads exception: $e');
    }
  }


  Future<void> _initializeBackgroundServices() async {
    try {
      await Workmanager().initialize(
        universalCallbackDispatcher,
        isInDebugMode: false,
      );
      debugPrint('Workmanager initialized');

      await AndroidAlarmManager.initialize();
      debugPrint('Android Alarm Manager initialized');

    } catch (e) {
      debugPrint('Background service init failed: $e');
    }
  }

  Future<void> _checkAndForceUpdate() async {
    log('🔍 Checking for app update...');

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        log('Update available!');
        log('Version code: ${info.availableVersionCode}');
        log('Immediate allowed: ${info.immediateUpdateAllowed}');
        log('Flexible allowed: ${info.flexibleUpdateAllowed}');

        if (info.immediateUpdateAllowed) {
          log('Starting immediate update (Google Play default screen)');
          final result = await InAppUpdate.performImmediateUpdate();
          if (result == AppUpdateResult.success) {
            log('Update completed successfully');
          } else if (result == AppUpdateResult.userDeniedUpdate) {
            log('User denied update');
          } else {
            log('Update result: $result');
          }
        } else {
          log('Immediate update not allowed');
        }
      } else {
        log('No update available - app is up to date');
      }
    } catch (e) {
      log('Error checking for update: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const NavBarScreen();
  }
}


Future<void> requestIgnoreBatteryOptimizations() async {
  const intent = AndroidIntent(
    action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
    data: 'package:com.thardstudio.tasktracker',
  );

  try {
    final canLaunch = await intent.canResolveActivity();

    if (canLaunch == null || !canLaunch) {
      debugPrint("Device does NOT support battery optimization settings (possibly emulator)");
      return;
    }
    await intent.launch();
    debugPrint("Battery optimization settings opened");

  } catch (e) {
    debugPrint("Error launching battery optimization intent: $e");
  }
}
