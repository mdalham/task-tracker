import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tasktracker/service/note/provider/notes_provider.dart';
import 'package:tasktracker/service/task/provider/task_provider.dart';

import '../../widget/custom_snack_bar.dart';
import '../main/nav_bar_screen.dart';

class LoginNotice extends StatefulWidget {
  const LoginNotice({super.key});

  @override
  State<LoginNotice> createState() => _LoginNoticeState();
}

class _LoginNoticeState extends State<LoginNotice>
    with SingleTickerProviderStateMixin {
  String? profileImagePath;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  TaskProvider? taskProvider;
  NoteProvider? noteProvider;
  Timer? _updateTimer;
  StreamSubscription? _firestoreSubscription;
  final bool enableFirestoreSync = true;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _updateTimer?.cancel();
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  static double _scale(BuildContext context) {
    final width = MediaQuery.of(context).size.shortestSide;
    if (width < 360) return 0.85;
    if (width < 400) return 1.0;
    if (width < 600) return 1.1;
    return 1.4;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final media = MediaQuery.of(context).size;
    final scale = _scale(context);

    final double popupHeight = (media.height * 0.48 * scale)
        .clamp(60, 310);
    final double popupWidth = (media.width * 0.315 * scale)
        .clamp(180, 350);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: popupHeight,
          width: popupWidth,
          constraints: BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Welcome!', style: textTheme.titleLarge),
                        SizedBox(height: 10),
                        Text(
                          'Login with Google and be among the first to experience our upcoming features!',
                          style: textTheme.bodyMedium,
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Stay informed: Read our Terms of Service and Privacy Policy.',
                          style: textTheme.bodyMedium,
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Send feedback and get ready for exciting new features!',
                          style: textTheme.bodyMedium,
                        ),
                        SizedBox(height: popupHeight / 14),
                        // Action button - Login or Logout based on auth state
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                isLoggedIn
                                    ? 'Logout'
                                    : _isGoogleLoading
                                    ? 'Please wait...'
                                    : 'Login with Google',
                                isLoggedIn
                                    ? Icons.logout
                                    : _isGoogleLoading
                                    ? Icons.hourglass_top
                                    : Icons.g_mobiledata,
                                const Color(0xFF5B7FFF),
                                Colors.white,
                                () async {
                                  await _handleGoogleLogin();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: colorScheme.primary.withOpacity(0.15),
                        ),
                        child: Icon(
                          Icons.close,
                          color: colorScheme.onPrimaryContainer,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color bgColor,
    Color textColor,
    VoidCallback onTap,
  ) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isGoogleLoading && label == "Please wait..."
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textColor,
                      ),
                    )
                  : Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleLogin() async {
    try {
      setState(() => _isGoogleLoading = true);

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      Navigator.of(context).pop(); // close dialog

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const NavBarScreen()),
            (route) => false,
      );
      CustomSnackBar.show(
        context,
        message: 'Welcome back, ${currentUser?.displayName ?? 'Guest'}!',
        type: SnackBarType.success,
      );
    } catch (e) {
      CustomSnackBar.show(
        context,
        message: 'Login failed',
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }
}
