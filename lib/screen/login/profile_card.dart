import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/service/note/provider/notes_provider.dart';
import 'package:tasktracker/service/task/provider/task_provider.dart';
import 'package:http/http.dart' as http;

import '../../widget/custom_snack_bar.dart';
import '../main/nav_bar_screen.dart';

class ProfileCard extends StatefulWidget {
  final Function()? onOpen;
  final String fromScreen;

  const ProfileCard({super.key, this.onOpen, required this.fromScreen});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard>
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
  bool _isUploadingImage = false;

  // Cloudinary configuration - Replace with your own credentials
  static const String cloudName = 'dgf2gpkwm';
  static const String uploadPreset = 'task_tracker';

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

  String? get userPhotoUrl => currentUser?.photoURL;

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

    final double popupHeight = (media.height * 0.44 * scale)
        .clamp(385, 400);
    final double popupWidth = (media.width * 0.82 * scale)
        .clamp(180, 350);

    final avatarWidth = (popupWidth / 3.5);
    final avatarHeight = (popupHeight / 4);
    double avatarPadding = (popupHeight - avatarHeight) / 4.5;



    return Consumer2<TaskProvider, NoteProvider>(
      builder: (context, taskProv, noteProv, child) {
        final totalTask = taskProv.allTasks.length;
        final completedCount = taskProv.completedTasks.length;
        final pendingCount =
            taskProv.inProgressTasks.length + taskProv.todayTasks.length;
        final notesCount = noteProv.notes.length;

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
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: popupHeight / 3.2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF5B7FFF),
                                  const Color(0xFF7B9FFF),
                                  const Color(0xFF9BBFFF),
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: popupHeight / 8.5),
                      // Profile content
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // User info
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                Text(
                                  userName,
                                  style: textTheme.titleSmall!.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userEmail,
                                  style: textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: popupHeight / 30),

                                // Stats row
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: colorScheme.outline,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildStatItem(
                                        totalTask.toString(),
                                        'Tasks',
                                        colorScheme,
                                      ),
                                      _divider(colorScheme),
                                      _buildStatItem(
                                        completedCount.toString(),
                                        'Completed',
                                        colorScheme,
                                      ),
                                      _divider(colorScheme),
                                      _buildStatItem(
                                        pendingCount.toString(),
                                        'Pending',
                                        colorScheme,
                                      ),
                                      _divider(colorScheme),
                                      _buildStatItem(
                                        notesCount.toString(),
                                        'Notes',
                                        colorScheme,
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: popupHeight / 26),

                                // Action button
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
                                          if (isLoggedIn) {
                                            await _handleLogout();
                                          } else {
                                            await _handleGoogleLogin();
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: avatarPadding,
                    left: (popupWidth - avatarWidth - 12) / 2,
                    child: SizedBox(
                      height: avatarHeight,
                      width: avatarWidth,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: avatarHeight,
                            width: avatarWidth,
                            constraints: BoxConstraints(maxWidth: popupWidth),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surface,
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _getProfileImage(),
                              child: _getProfileImage() == null
                                  ? Icon(
                                Icons.person_outline,
                                size: 50,
                                color: Colors.grey[600],
                              )
                                  : null,
                            ),
                          ),
                          if (isLoggedIn)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5B7FFF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: media.shortestSide * 0.04,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _divider(ColorScheme colorScheme) {
    return Container(height: 40, width: 1, color: colorScheme.outline);
  }

  ImageProvider? _getProfileImage() {
    // 1. Local selected image (temporary preview)
    if (profileImagePath != null) {
      return FileImage(File(profileImagePath!));
    }
    // 2. Cloudinary uploaded image or Google photo
    final String? photoUrl = currentUser?.photoURL;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    // 3. Default icon
    return null;
  }

  Widget _buildStatItem(String value, String label, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ],
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

  Future<void> _uploadToCloudinaryAndUpdateProfile(String imagePath) async {
    if (!isLoggedIn) return;

    setState(() => _isUploadingImage = true);

    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', url);

      // Add upload preset
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'profile_pictures';

      // Add the image file
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));

      // Send request
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);

        // Get the secure URL from Cloudinary
        final String cloudinaryUrl = jsonMap['secure_url'];

        // Update Firebase Auth profile with Cloudinary URL
        await currentUser?.updatePhotoURL(cloudinaryUrl);
        await currentUser?.reload();

        if (mounted) {
          setState(() {
            profileImagePath = null; // Clear local path
          });

          CustomSnackBar.show(
            context,
            message: 'Profile picture updated successfully!',
            type: SnackBarType.success,
          );
        }
      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to upload image!',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _pickImage() async {
    if (!isLoggedIn) {
      CustomSnackBar.show(
        context,
        message: 'Please login to change profile picture!',
        type: SnackBarType.warning,
      );
      return;
    }

    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Change Profile Photo',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildImageOption(
                Icons.camera_alt,
                const Color(0xFF5B7FFF),
                'Take Photo',
                'Use your camera',
                ImageSource.camera,
                picker,
              ),
              _buildImageOption(
                Icons.photo_library,
                Colors.purple,
                'Choose from Gallery',
                'Select from your photos',
                ImageSource.gallery,
                picker,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageOption(
      IconData icon,
      Color color,
      String title,
      String subtitle,
      ImageSource? source,
      ImagePicker picker, {
        VoidCallback? onTap,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ??
                  () async {
                Navigator.pop(context);
                if (source != null) {
                  final XFile? image = await picker.pickImage(
                    source: source,
                    maxWidth: 1024,
                    maxHeight: 1024,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    // Show local preview first
                    setState(() => profileImagePath = image.path);

                    // Upload to Cloudinary and update Firebase
                    await _uploadToCloudinaryAndUpdateProfile(image.path);
                  }
                }
              },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _refreshCallingScreen() {
    switch (widget.fromScreen) {
      case 'HomeScreen':
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const NavBarScreen()),
              (route) => false,
        );
        break;
      case 'SettingScreen':
        break;
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);

    try {
      // Initialize GoogleSignIn with scopes
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Start the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the login
        setState(() => _isGoogleLoading = false);
        CustomSnackBar.show(
          context,
          message: 'Google login canceled!',
          type: SnackBarType.warning,
        );
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final User? user = userCredential.user;

      if (user != null) {
        // Refresh UI
        setState(() {});
        _refreshCallingScreen();

        CustomSnackBar.show(
          context,
          message: 'Welcome back, ${user.displayName ?? user.email}!',
          type: SnackBarType.success,
          duration: const Duration(seconds: 2),
        );
      } else {
        CustomSnackBar.show(
          context,
          message: 'Google login failed!',
          type: SnackBarType.error,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      print("Google Login Error: $e");
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Google login failed!',
          type: SnackBarType.error,
          duration: const Duration(seconds: 2),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();

      if (!mounted) return;

      Navigator.of(context).pop();
      _refreshCallingScreen();

      CustomSnackBar.show(
        context,
        message: 'Logged out successfully!',
        type: SnackBarType.success,
      );

      setState(() {}); // Update UI
    } catch (e) {
      print("Logout Error: $e");
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Logout failed!',
          type: SnackBarType.error,
        );
      }
    }
  }

  String get displayName {
    if (!isLoggedIn) return 'Guest User';
    return currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!
        : 'User';
  }

  String get userEmail {
    if (!isLoggedIn) return 'Please login to continue';
    return currentUser?.email ?? 'No email';
  }

  String get userName {
    if (!isLoggedIn) return '@guest';
    String email = currentUser?.email ?? '';
    return '@${email.split('@').first}';
  }
}