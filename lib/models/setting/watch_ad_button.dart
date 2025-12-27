import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../service/subscription/subscription_aware_unity_reward_manager.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../widget/custom_snack_bar.dart';

class WatchAdButton extends StatefulWidget {
  const WatchAdButton({super.key});

  @override
  State<WatchAdButton> createState() => _WatchAdButtonState();
}

class _WatchAdButtonState extends State<WatchAdButton> {
  static const String _cooldownEndKey = 'reward_ad_cooldown_end';

  SubscriptionAwareUnityRewardManager? _rewardManager;
  bool _isInitialized = false;

  bool _isOnCooldown = false;
  bool _isShowingAd = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final subscriptionProvider = context.read<SubscriptionProvider>();

      setState(() {
        _rewardManager = SubscriptionAwareUnityRewardManager(
          subscriptionProvider: subscriptionProvider,
          unityPrimaryRewardIdHigh: 'Rewarded_Android_Sec_Unity_High',
          unityPrimaryRewardIdMed: 'Rewarded_Android_Sec_Unity_Med',
          unityPrimaryRewardIdLow: 'Rewarded_Android_Sec_Unity_Low',
          unitySecondaryRewardId: 'Rewarded_Android',
          admobInterstitialId: 'ca-app-pub-7237142331361857/2288769251',
          maxRetry: 5,
        );
        _isInitialized = true;
      });

      debugPrint('[WatchAdButton] Reward manager initialized');
    });

    _restoreCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _rewardManager?.dispose();
    super.dispose();
  }

  Future<void> _onWatchAdPressed() async {
    if (_isShowingAd || _isOnCooldown || !_isInitialized || _rewardManager == null) {
      return;
    }
    if (!_rewardManager!.isReady) {
      CustomSnackBar.show(
        context,
        message: 'No ads available right now',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() => _isShowingAd = true);

    try {
      await _rewardManager!.showRewardAd(
        onComplete: (completed, itemId, amount) async {
          if (!mounted) return;

          setState(() => _isShowingAd = false);

          if (completed) {
            CustomSnackBar.show(
              context,
              message: 'Thank you for supporting the developer!',
              type: SnackBarType.success,
            );

            await _startCooldown(minutes: 10);

          } else {
            CustomSnackBar.show(
              context,
              message: 'Ad skipped - please watch to support',
              type: SnackBarType.warning,
            );
          }
        },
        onFailed: () {
          if (!mounted) return;

          setState(() => _isShowingAd = false);

          CustomSnackBar.show(
            context,
            message: 'Failed to show ad',
            type: SnackBarType.error,
          );
        },
      );
    } catch (e) {
      debugPrint('[WatchAdButton] Ad error: $e');

      if (!mounted) return;

      setState(() => _isShowingAd = false);

      CustomSnackBar.show(
        context,
        message: 'Failed to show ad',
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _startCooldown({required int minutes}) async {
    final prefs = await SharedPreferences.getInstance();

    final endTime = DateTime.now()
        .add(Duration(minutes: minutes))
        .millisecondsSinceEpoch;

    await prefs.setInt(_cooldownEndKey, endTime);

    setState(() {
      _isOnCooldown = true;
      _cooldownSeconds = minutes * 60;
    });

    _startTimer();
  }

  Future<void> _restoreCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEndTime = prefs.getInt(_cooldownEndKey);

    if (savedEndTime == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = savedEndTime - now;

    if (remaining > 0) {
      setState(() {
        _isOnCooldown = true;
        _cooldownSeconds = (remaining / 1000).ceil();
      });
      _startTimer();
    } else {
      await prefs.remove(_cooldownEndKey);
    }
  }

  void _startTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() => _cooldownSeconds--);

      if (_cooldownSeconds <= 0) {
        timer.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cooldownEndKey);

        if (mounted) {
          setState(() => _isOnCooldown = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final minutesLeft = (_cooldownSeconds / 60).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Support Development', style: textTheme.bodyLarge),

        GestureDetector(
          onTap: (_isOnCooldown || _isShowingAd || !_isInitialized)
              ? null
              : _onWatchAdPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _isOnCooldown || !_isInitialized
                  ? colorScheme.primaryContainer.withOpacity(0.3)
                  : colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.outline),
            ),
            child: Row(
              children: [
                if (_isShowingAd)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (!_isInitialized)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.play_circle_outline,
                    size: 18,
                    color: _isOnCooldown ? Colors.grey : colorScheme.primary,
                  ),
                const SizedBox(width: 8),
                Text(
                  !_isInitialized
                      ? 'Loading...'
                      : _isOnCooldown
                      ? '$minutesLeft min'
                      : _isShowingAd
                      ? 'Loading...'
                      : 'Watch Ad',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}