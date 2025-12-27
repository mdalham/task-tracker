// lib/widget/custom_app_bar.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../screen/login/profile_card.dart';
import '../../screen/main/notification_screen.dart';
import '../../service/notification/provider/notification_provider.dart';
import '../../widget/custom_container.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(90);
}

class _CustomAppBarState extends State<CustomAppBar>
    with WidgetsBindingObserver {
  // Add this getter at the top of _CustomAppBarState
  User? get currentUser => FirebaseAuth.instance.currentUser;
  String? _cachedFullName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Load on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().loadNotifications();
      }
    });
    loadFullName();
  }

  Future<void> loadFullName() async {
    if (currentUser == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();

    if (snapshot.exists && snapshot.data()?['fullName'] != null) {
      _cachedFullName = snapshot.data()!['fullName'];
      setState(() {}); // refresh UI
    }
  }

  String get userName {
    // Google name
    if (currentUser?.displayName != null &&
        currentUser!.displayName!.isNotEmpty) {
      return currentUser!.displayName!;
    }

    // Cached Firestore fullName
    if (_cachedFullName != null && _cachedFullName!.isNotEmpty) {
      return _cachedFullName!;
    }

    return 'Guest';
  }

  String get userEmail => currentUser?.email ?? 'guest@example.com';

  String? get userPhotoUrl => currentUser?.photoURL;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Refresh on resume (safety net)
      context.read<NotificationProvider>().loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: CustomContainer(
        circularRadius: 18,
        color: colorScheme.primaryContainer,
        outlineColor: colorScheme.outline,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Profile
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) =>
                          ProfileCard(onOpen: () {}, fromScreen: 'HomeScreen'),
                    );
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade300,
                    child:
                        currentUser?.photoURL != null &&
                            currentUser!.photoURL!.isNotEmpty
                        ? ClipOval(
                            child: SizedBox(
                              height: 60,
                              width: 60,
                              child: Image.network(
                                currentUser!.photoURL!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: Colors.white70,
                                ),
                                loadingBuilder: (_, child, loadingProgress) {
                                  return loadingProgress == null
                                      ? child
                                      : const CircularProgressIndicator(
                                          color: Colors.white70,
                                          strokeWidth: 2,
                                        );
                                },
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 28,
                            color: Colors.white70,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, How are you?',
                      style: textTheme.titleSmall!.copyWith(
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    Text(userName, style: textTheme.titleLarge),
                  ],
                ),
              ],
            ),

            // Right: Notification Icon + LIVE Badge
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                );

                if (mounted) {
                  context.read<NotificationProvider>().loadNotifications();
                }
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Icon Container
                  CustomContainer(
                    height: 40,
                    width: 40,
                    color: colorScheme.primaryContainer,
                    outlineColor: colorScheme.outline,
                    circularRadius: 10,
                    child: Center(
                      child: Icon(
                        Icons.notifications_none,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),

                  Selector<NotificationProvider, int>(
                    selector: (_, p) => p.unreadCount,
                    builder: (context, count, child) {
                      if (count <= 0) return const SizedBox.shrink();

                      return Positioned(
                        right: -4,
                        top: -4,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Center(
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                style: Theme.of(context).textTheme.labelMedium!
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
