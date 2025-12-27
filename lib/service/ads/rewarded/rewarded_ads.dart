import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path/path.dart';
import 'package:tasktracker/widget/custom_snack_bar.dart';

class RewardedAdsManager {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  final String adUnitId;

  RewardedAdsManager({required this.adUnitId});

  /// Load a rewarded ad
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          _setupFullScreenCallback();
          debugPrint("Rewarded Ad Loaded");
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isAdLoaded = false;
          debugPrint("Rewarded Ad failed to load: $error");
          // Retry loading after a delay
          Future.delayed(const Duration(seconds: 5), loadRewardedAd);
        },
      ),
    );
  }

  /// Set full screen content callbacks
  void _setupFullScreenCallback() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint("Rewarded Ad shown"),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint("Rewarded Ad dismissed");
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        loadRewardedAd(); // Load next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint("Failed to show Rewarded Ad: $error");
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        loadRewardedAd(); // Load next ad
      },
    );
  }

  /// Show the rewarded ad
  void showRewardedAd({
    required VoidCallback onUserEarnedReward,
    required BuildContext context,
  }) {
    if (_isAdLoaded && _rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint("User earned reward: ${reward.amount} ${reward.type}");
          onUserEarnedReward();
        },
      );
    } else {
      CustomSnackBar.show(
        context,
        message: 'Ads not ready yet',
        type: SnackBarType.warning,
      );
      debugPrint("Rewarded Ad not ready yet");
    }
  }

  /// Dispose the ad
  void dispose() {
    _rewardedAd?.dispose();
  }
}
