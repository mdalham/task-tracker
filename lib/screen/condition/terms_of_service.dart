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
                            'Last updated: November 24, 2025',
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
  final EdgeInsets _sectionPadding = const EdgeInsets.symmetric(vertical: 8);

  const _TermsContent({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(_welcomeText, style: textTheme.bodyMedium),

        Padding(padding: _sectionPadding, child: Divider()),

        Text('App', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(_usingAppText, style: textTheme.bodyMedium),

        Padding(padding: _sectionPadding, child: Divider()),

        Text('Content', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(_yourContentText, style: textTheme.bodyMedium),

        Padding(padding: _sectionPadding, child: Divider()),

        Text('Privacy & Data', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(_privacyText, style: textTheme.bodyMedium),

        Padding(padding: _sectionPadding, child: Divider()),

        Text('Security', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(_securityText, style: textTheme.bodyMedium),

        Padding(padding: _sectionPadding, child: Divider()),

        Text('Limitations of Liability', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(_liabilityText, style: textTheme.bodyMedium),

        Padding(padding: _sectionPadding, child: Divider()),

        Text('Termination & Changes', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(_changesText, style: textTheme.bodyMedium),

        Padding(padding: _sectionPadding, child: Divider()),

        Text('Contact', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(_contactText, style: textTheme.bodyMedium),
        Text('info.thardstudio@gmail.com.', style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),

      ],
    );
  }
}

// --------------------------- Terms Text ---------------------------

const String _welcomeText =
    'Thank you for choosing Task Tracker. These Terms of Service ("Terms") govern your use of our note and task management application.';

const String _usingAppText =
    'The App provides tools to create, edit, organize, and synchronize notes and tasks. You may not misuse the App to store illegal content, infringe third-party rights, or attempt to access other users\' data.';

const String _yourContentText =
    'You retain full ownership of all notes, tasks, and other content you create in the app. All your data is stored locally on your device and is never uploaded to any server. We do not access, collect, or transmit your content.';

const String _privacyText =
    'We do not collect, store, or share any personal data. All notes, tasks, and user information—including login details—remain securely on your device and are never transmitted to us or any third party. Your data stays private and fully under your control. Since this app does not use any cloud services, none of your content is uploaded, synced, or shared.';

const String _securityText =
    'We use standard security measures, but no system is 100% secure. Avoid storing highly sensitive information in plain text. Use device security features such as passcode or biometrics for better protection.';

const String _liabilityText =
    'To the extent allowed by law, we are not liable for any indirect or incidental damages. We do not guarantee the app will be error-free or always available. You are responsible for backing up your important data.';

const String _changesText =
    'We may update these Terms at any time and will notify you in the App. Continued use means you accept the changes. We may suspend or terminate access if you violate these Terms.';

const String _contactText =
    'If you have questions about these Terms, contact us at';
