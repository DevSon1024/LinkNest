import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/models/link_model.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/input/input_page.dart';
import 'presentation/folders/links_folders_page.dart';
import 'presentation/links/links_page.dart';
import 'presentation/settings/menu_page.dart';
import 'presentation/favorites/favorites_page.dart';
import 'core/theme/theme_notifier.dart';
import 'core/services/database_helper.dart';
import 'core/services/metadata_service.dart';
import 'core/services/background_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const LinkNestApp());
}

class LinkNestApp extends StatelessWidget {
  const LinkNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeNotifier(),
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, child) {
          return MaterialApp(
            title: 'LinkNest',
            theme: themeNotifier.getThemeData(),
            darkTheme: themeNotifier.getThemeData(isDark: true),
            themeMode: themeNotifier.themeMode,
            home: const MainScreen(),
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,
          );
        },
      ),
    );
  }
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int _selectedIndex = 0;
  int _previousIndex = 0;
  late PageController _pageController;
  late AnimationController _fabAnimationController;
  late AnimationController _navAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _navSlideAnimation;

  final GlobalKey<LinksPageState> _linksPageKey = GlobalKey<LinksPageState>();
  final GlobalKey<LinksFoldersPageState> _foldersPageKey =
  GlobalKey<LinksFoldersPageState>();
  final GlobalKey<FavoritesPageState> _favoritesPageKey =
  GlobalKey<FavoritesPageState>();

  static const _platformChannel =
  MethodChannel('com.devson.link_nest/share');

  // Navigation items data
  final List<NavigationItem> _navItems = [
    NavigationItem(
      icon: Icons.home_rounded,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    NavigationItem(
      icon: Icons.link,
      activeIcon: Icons.link_rounded,
      label: 'Links',
    ),
    NavigationItem(
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder,
      label: 'Folders',
    ),
    NavigationItem(
      icon: Icons.more_horiz_rounded,
      activeIcon: Icons.more_horiz,
      label: 'More',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    WidgetsBinding.instance.addObserver(this);
    _platformChannel.setMethodCallHandler(_handleMethodCall);

    final service = FlutterBackgroundService();
    service.startService();
    service.invoke('startFetching');

    _processQuickSavedLinks();
  }

  void _initializeControllers() {
    _pageController = PageController();

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _navAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));

    _navSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _navAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Start navigation animation
    _navAnimationController.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _processQuickSavedLinks();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _fabAnimationController.dispose();
    _navAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case "handleSharedLink":
        final String? url = call.arguments;
        if (url != null && url.isNotEmpty) {
          await _processSharedUrl(url, navigateToLinks: true);
        }
        break;
      case "navigateToLinksPage":
        await _processQuickSavedLinks();
        _onNavItemTapped(1);
        break;
    }
  }

  Future<void> _processQuickSavedLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final urlsToSave = prefs.getStringList('flutter.quick_save_urls');

      if (urlsToSave == null || urlsToSave.isEmpty) {
        return;
      }

      final dbHelper = DatabaseHelper();
      int savedCount = 0;

      // Process in batches to avoid blocking UI
      for (int i = 0; i < urlsToSave.length; i += 5) {
        final batch = urlsToSave.skip(i).take(5);

        for (final url in batch) {
          if (!await dbHelper.linkExists(url)) {
            final domain = Uri.tryParse(url)?.host ?? '';
            final newLink = LinkModel(
              url: url,
              createdAt: DateTime.now(),
              domain: domain,
              status: MetadataStatus.pending,
            );
            await dbHelper.insertLink(newLink);
            savedCount++;
          }
        }

        // Yield control back to UI
        await Future.delayed(const Duration(microseconds: 1));
      }

      await prefs.remove('flutter.quick_save_urls');

      if (savedCount > 0 && mounted) {
        _showSnackBar('$savedCount link(s) saved in background!');
        refreshLinks();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error processing saved links');
      }
    }
  }

  Future<bool> _processSharedUrl(String url, {bool navigateToLinks = false}) async {
    try {
      final dbHelper = DatabaseHelper();
      int savedCount = 0;

      final urlsInText = MetadataService.extractUrlsFromText(url);
      if (urlsInText.isEmpty) {
        _showSnackBar('No valid URL found.');
        return false;
      }

      for (final extractedUrl in urlsInText) {
        if (!await dbHelper.linkExists(extractedUrl)) {
          final domain = Uri.tryParse(extractedUrl)?.host ?? '';
          final newLink = LinkModel(
            url: extractedUrl,
            createdAt: DateTime.now(),
            domain: domain,
            status: MetadataStatus.pending,
          );
          await dbHelper.insertLink(newLink);
          savedCount++;
        }
      }

      if (savedCount > 0) {
        _showSnackBar('$savedCount link(s) saved!');
        refreshLinks();
        if (navigateToLinks) _onNavItemTapped(1);
        return true;
      } else {
        _showSnackBar('Link already exists.');
        if (navigateToLinks) _onNavItemTapped(1);
        return false;
      }
    } catch (e) {
      _showSnackBar('Error saving link');
      return false;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onNavItemTapped(int index) {
    if (_selectedIndex == index) return;

    // Haptic feedback for better UX
    HapticFeedback.lightImpact();

    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });

    // Animate FAB
    _fabAnimationController.forward().then((_) {
      _fabAnimationController.reverse();
    });

    // Navigate with smooth animation
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }

    // Unfocus any active text fields
    FocusScope.of(context).unfocus();
  }

  void refreshLinks() {
    _linksPageKey.currentState?.loadLinks();
    _foldersPageKey.currentState?.loadFolders();
    _favoritesPageKey.currentState?.loadLinks();
  }

  Widget _buildModernNavItem(int index) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onNavItemTapped(index),
            borderRadius: BorderRadius.circular(16),
            splashColor: theme.colorScheme.primary.withOpacity(0.1),
            highlightColor: theme.colorScheme.primary.withOpacity(0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.all(isSelected ? 8 : 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: isSelected ? 26 : 24,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: isSelected ? 12 : 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    child: Text(item.label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernFAB() {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _fabScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabScaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: 'main_fab',
              backgroundColor: Colors.transparent,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              highlightElevation: 0,
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        InputPage(onLinkAdded: refreshLinks),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, 1.0);
                      const end = Offset.zero;
                      const curve = Curves.easeOutCubic;

                      var tween = Tween(begin: begin, end: end)
                          .chain(CurveTween(curve: curve));

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                );
              },
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          HomeScreen(onLinkAdded: refreshLinks),
          LinksPage(key: _linksPageKey, onRefresh: refreshLinks),
          LinksFoldersPage(key: _foldersPageKey, onRefresh: refreshLinks),
          const MenuPage(),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _navSlideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, (1 - _navSlideAnimation.value) * 100),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildModernNavItem(0),
                      _buildModernNavItem(1),
                      const SizedBox(width: 64), // Space for FAB
                      _buildModernNavItem(2),
                      _buildModernNavItem(3),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: _buildModernFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// Data class for navigation items
class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}