import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/helper%20class/icon_helper.dart';
import 'package:tasktracker/helper%20class/size_helper_class.dart';
import 'package:tasktracker/service/subscription/subscription_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/add task/custom_menu.dart';
import '../../models/setting/watch_ad_button.dart';
import '../../service/notification/service/notification_service.dart';
import '../../service/setting/setting_provider.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/task/provider/task_provider.dart';
import '../../theme/theme_provider.dart';
import '../../widget/custom_snack_bar.dart';
import '../condition/privacy_policy.dart';
import '../condition/terms_of_service.dart';
import '../login/profile_card.dart';
import '../secondary/category_bottom_sheet.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  SubscriptionAwareBannerManager? bannerManager;

  final List<String> fontFamilies = [
    'Roboto',
    'Nunito',
    'Lato',
    'Playfair Display',
    'Merriweather',
    'Comfortaa',
  ];

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final subscriptionProvider = context.read<SubscriptionProvider>();

      setState(() {
        bannerManager = SubscriptionAwareBannerManager(
          subscriptionProvider: subscriptionProvider,
          indices: [0, 1, 2],
          admobId: "ca-app-pub-7237142331361857/3092082679",
          metaId: "1916722012533263_1916773885861409",
          unityPlacementId: 'Banner_Android',
        );
      });
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    bannerManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final subscriptionProvider = context.read<SubscriptionProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Settings', style: textTheme.displaySmall),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Account", style: textTheme.titleLarge),
              _buildListTile(
                title: 'My profile',
                subtitle: '',
                icon: IconHelper.user,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) =>
                        ProfileCard(onOpen: () {}, fromScreen: 'SettingScreen'),
                  );
                },
                textTheme: textTheme,
              ),

              if (!subscriptionProvider.isSubscribed) WatchAdButton(),
              SizedBox(height: 6),

              _buildListTile(
                title: 'Sub DEMO',
                subtitle: '',
                icon: IconHelper.user,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubscriptionScreen(),
                    ),
                  );
                },
                textTheme: textTheme,
              ),

              SizedBox(height: 6),
              Divider(thickness: 1, color: colorScheme.outline),

              // Appearance Section
              Text("Appearance", style: textTheme.titleLarge),
              _buildThemeMode(
                title: 'Dark Mode',
                subtitle: 'Enable dark theme across the app',
                themeProvider: themeProvider,
                textTheme: textTheme,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: bannerManager!.bannerReady(0),
                builder: (_, isReady, __) {
                  if (!isReady) return const SizedBox.shrink();
                  return bannerManager!.getBannerWidget(0);
                },
              ),
              // Font Family Dropdown
              _buildDropdownTile(
                title: 'Font Family',
                subtitle: 'Choose your preferred font',
                value: settingsProvider.fontFamily,
                options: fontFamilies,
                onChanged: (val) async {
                  if (val != null) {
                    await settingsProvider.setFontFamily(val);
                    CustomSnackBar.show(
                      context,
                      message: 'Font family updated with $val',
                      type: SnackBarType.success,
                    );
                  }
                },
                textTheme: textTheme,
                colorScheme: colorScheme,
              ),

              Divider(thickness: 1, color: colorScheme.outline),

              // Notifications Section
              Text("Notifications", style: textTheme.titleLarge),

              _buildSwitchTile(
                title: 'Enable Notifications',
                subtitle: 'Receive notifications for task reminders',
                value: settingsProvider.notificationsEnabled,
                onChanged: (val) async {
                  // Update the provider state first
                  await settingsProvider.setNotificationsEnabled(val);
                  // Show snack after action completes
                  String message;
                  if (val) {
                    // Enable notifications: load tasks
                    await taskProvider.loadAllTasks();
                    message = 'Reminders enabled';
                  } else {
                    // Disable notifications: cancel all
                    unawaited(
                      NotificationService.instance.cancelAllNotifications(),
                    );
                    message = 'All notifications cancelled';
                  }
                  if (!mounted) return;
                  CustomSnackBar.show(
                    context,
                    message: message,
                    type: SnackBarType.success,
                  );
                },
                textTheme: textTheme,
              ),

              _buildSwitchTile(
                title: '5-Minute Before Reminders',
                subtitle: 'Get notified 5 minutes before task time',
                value: settingsProvider.fiveMinuteReminderEnabled,
                enabled: settingsProvider.notificationsEnabled,
                onChanged: settingsProvider.notificationsEnabled
                    ? (val) async {
                        await settingsProvider.setFiveMinuteReminderEnabled(
                          val,
                        );
                        NotificationService.instance
                            .setFiveMinuteReminderEnabled(val);
                        taskProvider.setFiveMinuteReminderEnabled(val);
                        if (mounted) {
                          CustomSnackBar.show(
                            context,
                            message: val
                                ? '5-minute reminders enabled'
                                : '5-minute reminders disabled',
                            type: SnackBarType.success,
                          );
                        }
                      }
                    : null,
                textTheme: textTheme,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: bannerManager!.bannerReady(1),
                builder: (_, isReady, __) {
                  if (!isReady) return const SizedBox.shrink();
                  return bannerManager!.getBannerWidget(1);
                },
              ),

              Divider(thickness: 1, color: colorScheme.outline),

              // Categories, Account, About sections remain the same...
              Text("Categories", style: textTheme.titleLarge),
              _buildListTile(
                title: 'Manage Categories',
                subtitle: 'Add, edit or delete categories',
                icon: IconHelper.category,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const CategoryBottomSheet(),
                  );
                },
                textTheme: textTheme,
              ),

              Divider(thickness: 1, color: colorScheme.outline),

              Text("Support", style: textTheme.titleLarge),
              _buildListTile(
                title: 'Send Feedback',
                subtitle: 'Report an issue or suggest a feature',
                icon: IconHelper.emailFeedback,
                onTap: () => _sendFeedbackEmail(context),
                textTheme: textTheme,
              ),

              Text("Legal", style: textTheme.titleLarge),
              _buildListTile(
                title: 'Terms of Service',
                subtitle: '',
                icon: IconHelper.privacyPolicy,
                onTap: () => _showTermsOfService(context),
                textTheme: textTheme,
              ),
              _buildListTile(
                title: 'Privacy Policy',
                subtitle: '',
                icon: IconHelper.privacyPolicy,
                onTap: () => _showPrivacyPolicyBottomSheet(context),
                textTheme: textTheme,
              ),

              const Divider(thickness: 1),
              Text("About", style: textTheme.titleLarge),
              _buildListTile(
                title: 'App Version',
                subtitle: 'v1.0.0',
                icon: IconHelper.aboutApp,
                onTap: () {},
                textTheme: textTheme,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: bannerManager!.bannerReady(2),
                builder: (_, isReady, __) {
                  if (!isReady) return const SizedBox.shrink();
                  return bannerManager!.getBannerWidget(2);
                },
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            ],
          ),
        ),
      ),
    );
  }

  // Your existing builder methods (only _buildSliderTile removed)
  Widget _buildThemeMode({
    required String title,
    required String subtitle,
    required themeProvider,
    required TextTheme textTheme,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: textTheme.bodyLarge),
      subtitle: Text(subtitle, style: textTheme.displayMedium),
      trailing: Transform.scale(
        scale: .8,
        child: Switch(
          value: themeProvider.isDarkMode(context),
          activeThumbColor: Colors.white,
          activeTrackColor: Colors.white24,
          inactiveThumbColor: Colors.black,
          inactiveTrackColor: Colors.black12,
          trackOutlineColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.outline,
          ),
          onChanged: (value) {
            themeProvider.toggleTheme(value);
            CustomSnackBar.show(
              context,
              message: value ? 'Dark mode enabled' : 'Dark mode disabled',
              type: SnackBarType.success,
            );
          },
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool)? onChanged,
    bool enabled = true,
    required TextTheme textTheme,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: textTheme.bodyLarge),
        subtitle: Text(subtitle, style: textTheme.displayMedium),
        trailing: Transform.scale(
          scale: .8,
          child: Switch(
            value: value,
            activeThumbColor: Colors.blue,
            activeTrackColor: Colors.blueAccent.withOpacity(0.3),
            inactiveThumbColor: Colors.black,
            inactiveTrackColor: Colors.black12,
            trackOutlineColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.outline,
            ),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: textTheme.bodyLarge),
      subtitle: Text(subtitle, style: textTheme.displayMedium),
      trailing: Builder(
        builder: (context) {
          return GestureDetector(
            onTap: () {
              // Rotate to 180°
              _iconController.forward();

              final RenderBox renderBox =
                  context.findRenderObject() as RenderBox;
              final position = renderBox.localToGlobal(Offset.zero);
              final size = renderBox.size;

              customMenu(
                context: context,
                position: Offset(
                  position.dx + size.width,
                  position.dy + size.height,
                ),
                left: MediaQuery.of(context).size.shortestSide * 0.5,
                top: 0,
                colorScheme: colorScheme,
                builder: (closePopup) {
                  return Container(
                    height: MediaQuery.of(context).size.height * 0.305,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colorScheme.outline, width: 1),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: options.map((option) {
                          final isSelected = option == value;
                          return InkWell(
                            onTap: () {
                              closePopup(option);
                              onChanged(option);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    Icon(
                                      Icons.check,
                                      size:
                                          SizeHelperClass.repeatTaskIconWidth(
                                            context,
                                          ) +
                                          4,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 2),
                                  ],
                                  if (!isSelected) const SizedBox(width: 26),
                                  Text(
                                    option,
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontFamily: option,
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.onSurface,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
                onDismiss: (result) {
                  // Reverse animation when menu closes
                  if (mounted) {
                    _iconController.reverse();
                  }
                },
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: textTheme.titleMedium),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _iconController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _iconController.value * 3.1416, // 180°
                      child: child,
                    );
                  },
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: colorScheme.onSurface,
                    size: SizeHelperClass.keyboardArrowDownIconSize(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required String icon,
    required Function()? onTap,
    bool enabled = true,
    required TextTheme textTheme,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: SvgPicture.asset(
          icon,
          height: SizeHelperClass.settingSLIconHeight(context),
          width: SizeHelperClass.settingSLIconWidth(context),
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        ),
        title: Text(title, style: textTheme.bodyLarge),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle, style: textTheme.displayMedium)
            : null,
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: SizeHelperClass.keyboardArrowDownIconSize(context) - 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onTap: enabled ? onTap : null,
      ),
    );
  }

  Future<void> _sendFeedbackEmail(BuildContext context) async {
    final email = 'info.thardstudio@gmail.com';

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        //use here sub or body text
      },
    );

    try {
      final bool launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        CustomSnackBar.show(
          context,
          message: 'Could not open email app',
          type: SnackBarType.error,
        );
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error opening email',
          type: SnackBarType.error,
        );
        debugPrint('Error opening email: $e');
      }
    }
  }

  Future<void> _showTermsOfService(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TermsOfService(),
    );
  }

  Future<void> _showPrivacyPolicyBottomSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PrivacyPolicy(),
    );
  }
}
