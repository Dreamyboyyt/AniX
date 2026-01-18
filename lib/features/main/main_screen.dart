import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/crash_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../home/home_screen.dart';
import '../downloads/downloads_screen.dart';
import '../download_manager/download_manager_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';

/// Main screen with bottom navigation
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    // Show crash dialog if there was a crash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CrashHandler.showCrashDialogIfNeeded(context);
    });
  }

  void _openSearch() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentNavIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [
          HomeScreen(),
          DownloadsScreen(),
          DownloadManagerScreen(),
          SettingsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSearch,
        icon: const Icon(Icons.search_rounded),
        label: const Text('Search'),
        backgroundColor: AppColors.draculaPink,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(currentNavIndexProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Downloads',
          ),
          NavigationDestination(
            icon: Icon(Icons.downloading_outlined),
            selectedIcon: Icon(Icons.downloading),
            label: 'Manager',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
