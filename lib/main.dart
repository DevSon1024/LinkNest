import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'pages/home_screen.dart';
import 'pages/links_page.dart';
import 'pages/links_folders_page.dart';
import 'pages/input_page.dart';
import 'screens/menu_page.dart';
import 'screens/theme_notifier.dart';
import 'dart:async';
import 'services/metadata_service.dart';
import 'services/database_helper.dart';
import 'services/background_service.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupSharingIntent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentMediaSub.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool showViewAction = false}) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      action: showViewAction
          ? SnackBarAction(
        label: 'View',
        textColor: Colors.white,
        onPressed: () {
          _navigatorKey.currentState!.pushNamed('/links');
        },
      )
          : null,
    );
    ScaffoldMessenger.of(_navigatorKey.currentState!.overlay!.context).showSnackBar(snackBar);
  }

  void _setupSharingIntent() {
    print('Setting up sharing intent subscription for media...');
    _intentMediaSub = ReceiveSharingIntent.instance.getMediaStream().listen(
          (List<SharedMediaFile> files) {
        print('Received shared media: ${files.map((f) => f.toMap())}');
        if (files.isNotEmpty) {
          _processSharedMedia(files);
        }
      },
      onError: (err) {
        print("getMediaStream error: $err");
        _showSnackBar('Error processing shared link: $err');
      },
    );

    _checkForInitialSharedMedia();
  }

  void _checkForInitialSharedMedia() {
    print('Checking for initial shared media...');
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile>? files) {
      if (files != null && files.isNotEmpty) {
        print('Initial shared media received: ${files.map((f) => f.toMap())}');
        _processSharedMedia(files);
        ReceiveSharingIntent.instance.reset();
      } else {
        print('No initial shared media found');
      }
    }).catchError((error) {
      print('Error getting initial media: $error');
      _showSnackBar('Error getting initial media: $error');
    });
  }

  String _normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      final scheme = uri.scheme.toLowerCase() == 'http' ? 'https' : uri.scheme;
      final path = uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;
      return Uri(scheme: scheme, host: uri.host.toLowerCase(), path: path, query: uri.query).toString();
    } catch (e) {
      return url.trim().toLowerCase();
    }
  }

  Future<void> _processSharedMedia(List<SharedMediaFile> files) async {
    final dbHelper = DatabaseHelper();
    for (final file in files) {
      final url = file.path;
      if (url.isEmpty || !MetadataService.isValidUrl(url)) {
        print('Invalid URL found in media: ${file.toMap()}');
        _showSnackBar('Invalid URL: $url');
        continue;
      }

      final normalizedUrl = _normalizeUrl(url);
      final dbHelper = DatabaseHelper();
      if (await dbHelper.linkExists(normalizedUrl)) {
        print('Link already exists: $normalizedUrl');
        _showSnackBar('Link already exists: $normalizedUrl');
        continue;
      }

      // --- New Instant Save Logic ---
      final domain = Uri.tryParse(url)?.host ?? '';
      final newLink = LinkModel(
        url: url,
        createdAt: DateTime.now(),
        domain: domain,
        status: MetadataStatus.pending, // Start as pending
      );

      try {
        await dbHelper.insertLink(newLink);
        _showSnackBar('Link saved! Fetching details...');

        // Trigger background service to start fetching
        final service = FlutterBackgroundService();
        service.invoke('startFetching');

        // Refresh UI
        refreshLinks();
      } catch (e) {
        _showSnackBar('Link already exists!');
      }

      final metadata = await MetadataService.extractMetadata(normalizedUrl);
      if (metadata != null) {
        await dbHelper.insertLink(metadata);
        print('Link saved successfully: $normalizedUrl');
        _showSnackBar('Link saved successfully', showViewAction: true);
        if (mounted) {
          _linksPageKey.currentState?.loadLinks();
          _foldersPageKey.currentState?.loadFolders();
        }
      } else {
        print('Failed to extract metadata for: $normalizedUrl');
        _showSnackBar('Failed to extract metadata for: $normalizedUrl');
      }
    }
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
      FocusScope.of(context).unfocus();
    });
  }

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