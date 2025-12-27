import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../service/bottomnav/bottom_provider.dart';
import '../main/home_screen.dart';
import '../main/time_line_screen.dart';
import '../main/notes_screen.dart';
import '../main/setting_screen.dart';
import '../secondary/todo_add_and_edit_screen.dart';
import '../secondary/task_add_or_edit_screen.dart';
import '../secondary/note_add_or_edit_screen.dart';

class NavBarScreen extends StatefulWidget {
  const NavBarScreen({super.key});

  @override
  State<NavBarScreen> createState() => _NavBarScreenState();
}

class _NavBarScreenState extends State<NavBarScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  bool _fabOpen = false;

  late final AnimationController _fabController;
  late final Animation<double> _fabIconAnimation;


  final List<Widget> _screens = const [
    HomeScreen(),
    TimeLineScreen(),
    NotesScreen(),
    SettingScreen(),
  ];

  @override
  void initState() {
    super.initState();

    final provider = context.read<BottomNavProvider>();

    _pageController = PageController(initialPage: provider.index);

    provider.addListener(() {
      final newIndex = provider.index;
      if (_pageController.hasClients &&
          _pageController.page?.round() != newIndex) {
        _pageController.animateToPage(
          newIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fabIconAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeInOutCubic,
    );

  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,

      // ===================== PAGE VIEW =====================
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: _screens,
            ),


            // ===================== FAB BACKDROP =====================
            if (_fabOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeFab,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(color: Colors.black.withOpacity(0.25)),
                  ),
                ),
              ),

            // ===================== FAB OPTIONS =====================
            if (_fabOpen)
              Positioned(
                bottom: 90,
                right: 20,
                child: FadeTransition(
                  opacity: _fabIconAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _fabController,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _fabAction(
                          label: 'Todo',
                          onTap: () async {
                            _closeFab();
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const AddEditTodoScreen(),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _fabAction(
                          label: 'Task',
                          onTap: () {
                            _closeFab();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TaskAddOrEditScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _fabAction(
                          label: 'Note',
                          onTap: () {
                            _closeFab();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NoteAddOrEditScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

          ],
        ),
      ),

      // ===================== FAB =====================
      floatingActionButton: FloatingActionButton(
        elevation: 0,
        backgroundColor: Colors.blue,
        shape: const CircleBorder(),
        onPressed: _toggleFab,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220), // ⚡ very fast
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Icon(
            _fabOpen ? Icons.close : Icons.add,
            key: ValueKey(_fabOpen),
            size: 34,
            color: Colors.white,
          ),
        ),
      ),



      // ===================== DEFAULT BOTTOM NAV =====================
      bottomNavigationBar: Consumer<BottomNavProvider>(
        builder: (_, provider, __) {
          return BottomNavigationBar(
            currentIndex: provider.index,
            onTap: _onTab,
            type: BottomNavigationBarType.fixed,
            backgroundColor: cs.onPrimaryContainer,
            selectedItemColor: Colors.blue,
            unselectedItemColor: cs.onSurfaceVariant,
            selectedFontSize: 14,
            unselectedFontSize: 12,
            items: [
              BottomNavigationBarItem(
                icon: _buildSvgIcon(
                  index: 0,
                  currentIndex: provider.index,
                  asset: 'assets/icons/home.svg',
                  colorScheme: cs,
                ),
                activeIcon: _buildSvgIcon(
                  index: 0,
                  currentIndex: provider.index,
                  asset: 'assets/icons/home_filled.svg',
                  colorScheme: cs,
                ),
                label: 'Home',
              ),

              BottomNavigationBarItem(
                icon: _buildSvgIcon(
                  index: 1,
                  currentIndex: provider.index,
                  asset: 'assets/icons/timeline.svg',
                  colorScheme: cs,
                ),
                activeIcon: _buildSvgIcon(
                  index: 1,
                  currentIndex: provider.index,
                  asset: 'assets/icons/timeline_fill.svg',
                  colorScheme: cs,
                ),
                label: 'Timeline',
              ),

              BottomNavigationBarItem(
                icon: _buildSvgIcon(
                  index: 2,
                  currentIndex: provider.index,
                  asset: 'assets/icons/note.svg',
                  colorScheme: cs,
                ),
                activeIcon: _buildSvgIcon(
                  index: 2,
                  currentIndex: provider.index,
                  asset: 'assets/icons/note_fill.svg',
                  colorScheme: cs,
                ),
                label: 'Notes',
              ),

              BottomNavigationBarItem(
                icon: _buildSvgIcon(
                  index: 3,
                  currentIndex: provider.index,
                  asset: 'assets/icons/setting.svg',
                  colorScheme: cs,
                ),
                activeIcon: _buildSvgIcon(
                  index: 3,
                  currentIndex: provider.index,
                  asset: 'assets/icons/setting_fill.svg',
                  colorScheme: cs,
                ),
                label: 'Settings',
              ),
            ],
          );
        },
      ),

    );

  }

  Widget _fabAction({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1.5)
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,

          ),
        ),
      ),
    );
  }

  void _onTab(int index) {
    context.read<BottomNavProvider>().changeTab(index);
  }


  void _onPageChanged(int index) {
    context.read<BottomNavProvider>().changeTab(index);
    _closeFab();
  }


  void _toggleFab() {
    setState(() {
      _fabOpen = !_fabOpen;
      _fabOpen ? _fabController.forward() : _fabController.reverse();
    });
  }

  void _closeFab() {
    if (_fabOpen) {
      setState(() => _fabOpen = false);
      _fabController.reverse();
    }
  }
}

Widget _buildSvgIcon({
  required int index,
  required int currentIndex,
  required String asset,
  required ColorScheme colorScheme,
}) {
  final bool isSelected = index == currentIndex;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    child: SvgPicture.asset(
      asset,
      width: isSelected ? 26 : 20,
      height: isSelected ? 26 : 20,
      colorFilter: ColorFilter.mode(
        isSelected ? Colors.blue : colorScheme.onSurface,
        BlendMode.srcIn,
      ),
    ),
  );
}
