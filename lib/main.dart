import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/link_model.dart';
import 'pages/home_screen.dart';
import 'pages/input_page.dart';
import 'pages/links_folders_page.dart';
import 'pages/links_page.dart';
import 'screens/menu_page.dart';
import 'screens/theme_notifier.dart';
import 'services/database_helper.dart';
import 'services/metadata_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final GlobalKey<LinksPageState> _linksPageKey = GlobalKey<LinksPageState>();
  final GlobalKey<LinksFoldersPageState> _foldersPageKey =
  GlobalKey<LinksFoldersPageState>();

  static const _platformChannel =
  MethodChannel('com.devson.link_nest/share');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformChannel.setMethodCallHandler(_handleMethodCall);
    // Important: Check for background-saved links when the app starts
    _processQuickSavedLinks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // When the user returns to the app, check if any links were saved in the background
      _processQuickSavedLinks();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
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
      // First, process any links that were just saved
        await _processQuickSavedLinks();
        // Then, navigate to the links page
        _onNavItemTapped(1);
        break;
    }
  }

  Future<void> _processQuickSavedLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final urlsToSave = prefs.getStringList('flutter.quick_save_urls');

    if (urlsToSave == null || urlsToSave.isEmpty) {
      return; // No links to process
    }

    final dbHelper = DatabaseHelper();
    int savedCount = 0;
    for (final url in urlsToSave) {
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

    await prefs.remove('flutter.quick_save_urls');

    if (savedCount > 0) {
      _showSnackBar('$savedCount link(s) saved in background!');
      refreshLinks();
    }
  }

  Future<bool> _processSharedUrl(String url, {bool navigateToLinks = false}) async {
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
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
      FocusScope.of(context).unfocus();
    });
  }

  void refreshLinks() {
    _linksPageKey.currentState?.loadLinks();
    _foldersPageKey.currentState?.loadFolders();
  }

  Widget _buildNavItem(
      int index, IconData filledIcon, IconData outlinedIcon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onNavItemTapped(index),
        borderRadius: BorderRadius.circular(50),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlinedIcon,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              size: 28,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          HomeScreen(
            onLinkAdded: refreshLinks,
          ),
          LinksPage(
            key: _linksPageKey,
            onRefresh: refreshLinks,
          ),
          LinksFoldersPage(
            key: _foldersPageKey,
            onRefresh: refreshLinks,
          ),
          const MenuPage(),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        color: Theme.of(context).colorScheme.primary,
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 71.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              _buildNavItem(1, Icons.link_rounded, Icons.link_outlined, 'Links'),
              const SizedBox(width: 40),
              _buildNavItem(
                  2, Icons.folder_rounded, Icons.folder_outlined, 'Folders'),
              _buildNavItem(3, Icons.menu_rounded, Icons.menu_outlined, 'Menu'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InputPage(
                onLinkAdded: refreshLinks,
              ),
            ),
          );
        },
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}