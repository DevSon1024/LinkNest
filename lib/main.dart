import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'pages/home_screen.dart';
import 'pages/links_page.dart';
import 'screens/links_folders_page.dart';
import 'pages/input_page.dart';
import 'screens/menu_page.dart';
import 'screens/theme_notifier.dart';
import 'notification_service.dart';
import 'dart:async';
// import 'package:uri/uri.dart'; // Add this import for URL parsing

// Global callback function for notification handling
VoidCallback? onViewActionCallback;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
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
            // Define named routes for navigation
            routes: {
              '/links': (context) => LinksPage(
                key: GlobalKey<LinksPageState>(),
                onRefresh: () => (context as Element).findAncestorStateOfType<_MainScreenState>()?.refreshLinks(),
              ),
            },
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  final GlobalKey<LinksPageState> _linksPageKey = GlobalKey<LinksPageState>();
  final GlobalKey<LinksFoldersPageState> _foldersPageKey = GlobalKey<LinksFoldersPageState>();

  late StreamSubscription _intentMediaSub;
  bool _isProcessingSharedLink = false;
  final Set<String> _processedLinks = <String>{};
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupSharingIntent();
    _setupNotificationHandler();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentMediaSub.cancel();
    _pageController.dispose();
    _cleanupTimer?.cancel();
    onViewActionCallback = null;
    super.dispose();
  }

  void _setupNotificationHandler() {
    // Set the global callback function to navigate to LinksPage
    onViewActionCallback = () {
      print('Navigating to LinksPage from notification');
      _navigatorKey.currentState?.pushNamed('/links');
      // Refresh links and folders
      _linksPageKey.currentState?.loadLinks();
      _foldersPageKey.currentState?.loadFolders();
    };
  }

  void _setupSharingIntent() {
    print('Setting up sharing intent subscription for media...');
    _intentMediaSub = ReceiveSharingIntent.instance.getMediaStream().listen(
          (List<SharedMediaFile> files) {
        print('Received shared media: ${files.map((f) => f.toMap())}');
        if (files.isNotEmpty) {
          _processSharedMedia(files, showNotification: true);
        }
      },
      onError: (err) {
        print("getMediaStream error: $err");
        NotificationService().showNotification(
          title: 'LinkNest Error',
          body: 'Error processing shared media: $err',
          payload: 'error',
        );
      },
    );

    _checkForInitialSharedMedia();
    _setupMobile();
  }

  void _checkForInitialSharedMedia() {
    print('Checking for initial shared media...');
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile>? files) {
      if (files != null && files.isNotEmpty) {
        print('Initial shared media received: ${files.map((f) => f.toMap())}');
        _processSharedMedia(files, showNotification: true);
        ReceiveSharingIntent.instance.reset();
      } else {
        print('No initial shared media found');
      }
    }).catchError((error) {
      print('Error getting initial media: $error');
      NotificationService().showNotification(
        title: 'LinkNest Error',
        body: 'Error processing shared media: $error',
        payload: 'error',
      );
    });
  }

  Future<void> _processSharedMedia(List<SharedMediaFile> files, {bool showNotification = false}) async {
    if (_isProcessingSharedLink) {
      print('Already processing shared media, skipping: ${files.map((f) => f.toMap())}');
      return;
    }

    _isProcessingSharedLink = true;
    print('Processing shared media: ${files.map((f) => f.toMap())}');

    try {
      for (final file in files) {
        final url = file.path;
        if (url.isEmpty) {
          print('No valid URL found in media: ${file.toMap()}');
          if (showNotification) {
            NotificationService().showNotification(
              title: 'LinkNest',
              body: 'No valid URL found',
              payload: 'error',
            );
          }
          continue;
        }

        final linkKey = url.trim().toLowerCase();
        if (_processedLinks.contains(linkKey)) {
          print('Duplicate media detected, skipping: $linkKey');
          if (showNotification) {
            // Extract domain for duplicate notification
            String notificationBody = 'Link already exists';
            try {
              final uri = Uri.parse(url);
              final domain = uri.host.replaceFirst('www.', '');
              notificationBody = 'Link of $domain already exists';
            } catch (e) {
              print('Error parsing URL for notification: $e');
            }
            NotificationService().showNotification(
              title: 'LinkNest',
              body: notificationBody,
              payload: 'duplicate',
            );
          }
          continue;
        }

        _processedLinks.add(linkKey);

        final success = await _homeScreenKey.currentState?.addLinkFromUrl(url);

        if (success == true) {
          print('Link saved successfully: $url');
          if (showNotification) {
            // Extract domain for success notification
            String notificationBody = 'Link saved successfully';
            try {
              final uri = Uri.parse(url);
              final domain = uri.host.replaceFirst('www.', '');
              notificationBody = 'Link of $domain saved successfully';
            } catch (e) {
              print('Error parsing URL for notification: $e');
            }
            NotificationService().showNotification(
              title: 'LinkNest',
              body: notificationBody,
              payload: 'success',
            );
          }
          // Do not navigate or open the app
          if (mounted) {
            _linksPageKey.currentState?.loadLinks();
            _foldersPageKey.currentState?.loadFolders();
          }
        } else {
          print('Failed to save link or link already exists: $url');
          if (showNotification) {
            // Extract domain for error notification
            String notificationBody = 'Link already exists or failed to save';
            try {
              final uri = Uri.parse(url);
              final domain = uri.host.replaceFirst('www.', '');
              notificationBody = 'Link of $domain already exists or failed to save';
            } catch (e) {
              print('Error parsing URL for notification: $e');
            }
            NotificationService().showNotification(
              title: 'LinkNest',
              body: notificationBody,
              payload: 'error',
            );
          }
        }

        Timer(const Duration(milliseconds: 2000), () {
          _processedLinks.remove(linkKey);
        });
      }
    } catch (e) {
      print('Error processing shared media: $e');
      if (showNotification) {
        // Use a generic error message since no specific URL is available
        NotificationService().showNotification(
          title: 'LinkNest Error',
          body: 'Error processing shared media: $e',
          payload: 'error',
        );
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 1000), () {
        _isProcessingSharedLink = false;
      });
    }
  }

  void _setupMobile() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      final oldSize = _processedLinks.length;
      _processedLinks.clear();
      print('Periodic cleanup - cleared $oldSize processed links');
    });
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
      FocusScope.of(context).unfocus();
    });
  }

  // Add refreshLinks method for the named route
  void refreshLinks() {
    _linksPageKey.currentState?.loadLinks();
    _foldersPageKey.currentState?.loadFolders();
  }

  Widget _buildNavItem(int index, IconData filledIcon, IconData outlinedIcon, String label) {
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
      key: _scaffoldKey,
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
            FocusScope.of(context).unfocus();
          });
        },
        children: [
          HomeScreen(
            key: _homeScreenKey,
            onLinkAdded: () {
              _linksPageKey.currentState?.loadLinks();
              _foldersPageKey.currentState?.loadFolders();
            },
          ),
          LinksPage(
            key: _linksPageKey,
            onRefresh: () => _linksPageKey.currentState?.loadLinks(),
          ),
          LinksFoldersPage(
            key: _foldersPageKey,
            onRefresh: () => _foldersPageKey.currentState?.loadFolders(),
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
              _buildNavItem(2, Icons.folder_rounded, Icons.folder_outlined, 'Folders'),
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
                onLinkAdded: () {
                  _linksPageKey.currentState?.loadLinks();
                  _foldersPageKey.currentState?.loadFolders();
                },
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