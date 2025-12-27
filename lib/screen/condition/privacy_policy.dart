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
        section('Your Choices & Controls', _choices),
        section('Children’s Privacy', _children),
        section('Changes to This Policy', _changes),
        section('Contact Us', _contact, gmailID: 'info.thardstudio@gmail.com.'),

        Center(
          child: Text(
            'Last updated: November 24, 2025',
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
    'This Privacy Policy explains how our Task Tracker application collects, uses, and protects your information. By using the App, you agree to the practices described here.';

const String _collect =
    'We collect minimal data required for the App to function. This may include:\n\n• Basic account information (if sign‑in is used)\n• App usage analytics (crash logs, performance data)\n\nWe do NOT collect or sell personal data unrelated to app functionality.';

const String _usage =
    'We use collected data to:\n\n• Improve app performance and stability\n• Provide customer support\n• Enhance features and user experience\n\nWe never use your private data for sell or advertising or tracking.';

const String _localSync =
    'Your notes and tasks are primarily stored locally on your device. Your content always remains yours.';

const String _security =
    'We don’t store your data in the cloud. While no digital system is fully secure, using device-level protection like PIN, fingerprint, or face unlock is recommended.';

const String _thirdParty =
    'The app may use Firebase Crashlytics for crash analytics. We do not share your note content with third parties.';

const String _choices =
    'You have control over your data, including:\n\n• Editing or deleting your notes and tasks\n• Clearing app data\n• Revoking storage permissions\n\nYou may uninstall the App at any time to stop data collection.';

const String _children =
    'This app is suitable for all ages. We do not knowingly collect personal information from children.';

const String _changes =
    'We may update this Privacy Policy. Continued use of the app means you accept any changes.';

const String _contact =
    'For any questions regarding this Privacy Policy, email us at ';
