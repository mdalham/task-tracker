import 'package:flutter/material.dart';
import 'package:tasktracker/widget/custom_container.dart';


class TermsOfService extends StatefulWidget {
  const TermsOfService({super.key});

  @override
  State<TermsOfService> createState() => _TermsOfServiceState();
}

class _TermsOfServiceState extends State<TermsOfService> {
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
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Terms of Service', style: textTheme.titleLarge),
                    ),
                    IconButton(
                      icon: CustomContainer(
                          color: colorScheme.onPrimaryContainer.withOpacity(0.6),
                          outlineColor: Colors.transparent,
                          circularRadius: 30,
                          padding: EdgeInsets.all(5),
                          child: const Icon(Icons.close)),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _TermsContent(),
                        const SizedBox(height: 20),

                        // Small note
                        Center(
                          child: Text(
                            'Last updated: December 29, 2025',
                            style: textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
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

class _TermsContent extends StatelessWidget {
  const _TermsContent({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme
        .of(context)
        .textTheme;
    final colorScheme = Theme
        .of(context)
        .colorScheme;

    // Helper to keep the UI clean
    Widget termSection(String title, String body, {bool isBoldBody = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: textTheme.bodyMedium?.copyWith(
                height: 1.5,
                fontWeight: isBoldBody ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        termSection('1. Welcome & Acceptance', _welcomeText),
        termSection('2. Using the App', _usingAppText),
        termSection('3. Your Content & Ownership', _yourContentText),
        termSection('4. Security & Responsibility', _securityText),
        termSection('5. Ads & Subscriptions', _subscriptionText),
        termSection('6. Limitations of Liability', _liabilityText),
        termSection('7. Termination', _changesText),
        termSection('8. Contact Us', _contactText, isBoldBody: true),
      ],
    );
  }
}



// --------------------------- Updated Terms Text ---------------------------

const String _welcomeText =
    'Thank you for choosing Task Tracker. These Terms govern your use of our application. By accessing the App, you agree to be bound by these Terms.';

const String _subscriptionText =
    'The App may display third-party advertisements to support development. '
    'Users may choose to upgrade to a Premium Subscription to remove all ads '
    'and unlock advanced features.\n\n'
    '• Billing: Subscription payments are securely processed via the Apple App Store or Google Play. '
    'We do not collect or store payment information.\n'
    '• Trials: If a free trial is offered, charges will apply after the trial ends unless canceled at least '
    '24 hours before the end of the trial period.\n'
    '• Renewals & Cancellations: Subscriptions automatically renew unless canceled. '
    'You can manage or cancel your subscription at any time through your device’s Store Settings.\n\n'
    'Your subscription status is used solely to provide premium benefits and remove advertisements.';

const String _usingAppText =
    'The App provides tools for task management. You agree not to use the App for illegal purposes or to attempt to interfere with the App\'s security features.';

const String _yourContentText =
    'You retain full ownership of your data. While your tasks are primarily stored on your device, your subscription status and account profile are synced to allow for feature restoration across devices.';

const String _securityText =
    'You are responsible for safeguarding the device that holds your data. We recommend using device-level biometrics (FaceID/Fingerprint) to protect your tasks from unauthorized access.';

const String _liabilityText =
    'Task Tracker is provided "as-is." We are not liable for any data loss resulting from device failure or accidental deletion. Users are encouraged to utilize backup features where available.';

const String _changesText =
    'We reserve the right to modify these terms. Continued use of the App after updates constitutes acceptance of the new terms.';

const String _contactText =
    'Questions? Contact support at: info.thardstudio@gmail.com';