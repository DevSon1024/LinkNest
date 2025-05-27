import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/links_page.dart';
import 'screens/links_folders_page.dart';
import 'screens/input_page.dart';
import 'screens/menu_page.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkNest',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true, // Enable Material 3 for modern Android look
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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

  // Sharing intent variables
  late StreamSubscription _intentMediaSub;
  bool _isProcessingSharedLink = false;
  final Set<String> _processedLinks = <String>{};
  Timer? _cleanupTimer;

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
    _cleanupTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('App lifecycle state changed: $state');

    if (state == AppLifecycleState.resumed) {
      print('App resumed, checking for shared data...');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isProcessingSharedLink) {
          _checkForInitialSharedMedia();
        }
      });
    }
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
        _isProcessingSharedLink = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing shared media: $err'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );

    _checkForInitialSharedMedia();
    _setupMobile();
  }

  void _checkForInitialSharedMedia() {
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile>? files) {
      if (files != null && files.isNotEmpty) {
        print('Initial shared media received: ${files.map((f) => f.toMap())}');
        _processSharedMedia(files);
        ReceiveSharingIntent.instance.reset();
      }
    }).catchError((error) {
      print('Error getting initial media: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing shared media: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  Future<void> _processSharedMedia(List<SharedMediaFile> files) async {
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
          continue;
        }

        final linkKey = url.trim().toLowerCase();
        if (_processedLinks.contains(linkKey)) {
          print('Duplicate media detected, skipping: $linkKey');
          continue;
        }

        _processedLinks.add(linkKey);

        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
            _pageController.jumpToPage(0);
          });
          await Future.delayed(const Duration(milliseconds: 300));
        }

        final success = await _homeScreenKey.currentState?.addLinkFromUrl(url);

        if (success == true) {
          print('Link saved successfully: $url');
          setState(() {
            _selectedIndex = 1;
            _pageController.jumpToPage(1);
          });

          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            _linksPageKey.currentState?.loadLinks();
            _foldersPageKey.currentState?.loadFolders();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Link saved successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          print('Failed to save link or link already exists: $url');
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Link already exists or failed to save: $url'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        Timer(const Duration(milliseconds: 2000), () {
          _processedLinks.remove(linkKey);
        });
      }
    } catch (e) {
      print('Error processing shared media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing shared media: $e'),
            backgroundColor: Colors.red,
          ),
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