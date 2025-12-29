import 'package:flutter/material.dart';

import '../../widget/custom_container.dart';

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // drag handle
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Privacy Policy',
                        style: textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: CustomContainer(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.6),
                        outlineColor: Colors.transparent,
                        circularRadius: 30,
                        padding: EdgeInsets.all(5),
                        child: const Icon(Icons.close),
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: const _PrivacyContent(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget section(String title, String body, {String? gmailID}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(body, style: textTheme.bodyMedium),
        if (gmailID != null) ...[
          const SizedBox(height: 2),
          Text(
            gmailID,
            style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 10),
        Divider(),
        const SizedBox(height: 10),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        section('Introduction', _intro),
        section('Information We Collect', _collect),
        section('How We Use Your Information', _usage),
        section('Local Storage & Sync', _localSync),
        section('Data Security', _security),
        section('Third‑Party Services', _thirdParty),
        section('Ads & Subscriptions', _adsSubscription),
        section('Your Choices & Controls', _choices),
        section('Children’s Privacy', _children),
        section('Changes to This Policy', _changes),
        section('Contact Us', _contact, gmailID: 'info.thardstudio@gmail.com.'),

        Center(
          child: Text(
            'Last updated: December 29, 2025',
            style: textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ----------------------- PRIVACY POLICY TEXT -----------------------

const String _intro =
    'This Privacy Policy explains how our Task Tracker application collects, uses, and protects your information. By using the App and its premium features, you agree to the practices described here.';

const String _collect =
    'We collect minimal data required for the App to function. This includes:\n\n'
    '• Basic account information (Email used for Google Sign-In)\n'
    '• Subscription status (To verify your premium features)\n'
    '• App usage analytics (crash logs, performance data)\n\n'
    'We do NOT collect or sell personal data unrelated to app functionality.';

const String _usage =
    'We use collected data to:\n\n'
    '• Provide and manage your Ads-Free experience\n'
    '• Restore your purchases across different devices\n'
    '• Improve app performance and stability\n\n'
    'We never sell your private data to third parties.';

const String _localSync =
    'Your tasks are primarily stored on your device. However, your subscription status and basic profile are synced with our secure database to ensure you keep your premium features if you switch devices.';

const String _security =
    'We take data security seriously. While your tasks are local, your account info is secured via Google Sign-In and Firebase. We recommend using device-level protection like PIN or Biometrics.';

const String _thirdParty =
    'We use Google Firebase for authentication and crash analytics. Payment processing for subscriptions is handled exclusively by the Apple App Store or Google Play Store. We never see or store your credit card information.';

const String _adsSubscription =
    'The app may display third-party advertisements to support development. '
    'If you choose to purchase an ad-removal or premium subscription, all ads '
    'will be permanently disabled for your account.\n\n'
    'Subscription purchases are handled securely by Google Play or Apple App Store. '
    'We do not collect, store, or process your payment information directly.\n\n'
    'Your subscription status is used only to unlock premium features and remove ads.';

const String _choices =
    'You have full control:\n\n'
    '• Manage/Cancel Subscriptions: This must be done via your App Store/Play Store settings.\n'
    '• Data Deletion: You can delete your tasks or account at any time.\n'
    '• Ad Preferences: Upgrading to Premium removes all third-party advertisements.';

const String _children =
    'This app is suitable for all ages. We do not knowingly collect personal information from children under 13.';

const String _changes =
    'We may update this policy to reflect changes in our subscription models or app features. Continued use of the app signifies your acceptance.';

const String _contact =
    'For any questions regarding your subscription or this policy, email us at ';