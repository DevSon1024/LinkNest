import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/links_page.dart';
import 'screens/input_page.dart';
import 'screens/menu_page.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkNest',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  final GlobalKey<LinksPageState> _linksPageKey = GlobalKey<LinksPageState>();

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
      // Small delay to ensure app is fully resumed
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && !_isProcessingSharedLink) {
          _checkForInitialSharedMedia();
        }
      });
    }
  }

  void _setupSharingIntent() {
    print('Setting up sharing intent subscription for media...');

    // Listen to media sharing coming from outside the app while the app is in memory
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

    // Get the media sharing coming from outside the app while the app is closed
    _checkForInitialSharedMedia();

    // Setup periodic cleanup
    _setupPeriodicCleanup();
  }

  void _checkForInitialSharedMedia() {
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile>? files) {
      if (files != null && files.isNotEmpty) {
        print('Initial shared media received: ${files.map((f) => f.toMap())}');
        _processSharedMedia(files);
        // Tell the library that we are done processing the intent
        ReceiveSharingIntent.instance.reset();
      }
    }).catchError((error) {
      print('Error getting initial media: $error');
    });
  }

  void _processSharedMedia(List<SharedMediaFile> files) async {
    // Prevent concurrent processing
    if (_isProcessingSharedLink) {
      print('Already processing shared media, skipping: ${files.map((f) => f.toMap())}');
      return;
    }

    _isProcessingSharedLink = true;
    print('Processing shared media: ${files.map((f) => f.toMap())}');

    try {
      for (final file in files) {
        final url = file.path; // Assuming path contains the URL or file path
        if (url.isEmpty) {
          print('No valid URL found in media: ${file.toMap()}');
          continue;
        }

        // Create a unique key for this URL
        final linkKey = url.trim().toLowerCase();

        // Check for duplicates
        if (_processedLinks.contains(linkKey)) {
          print('Duplicate media detected, skipping: $linkKey');
          continue;
        }

        // Add to processed set
        _processedLinks.add(linkKey);

        // Add the link (assuming addLinkFromUrl can handle media URLs)
        final success = await _homeScreenKey.currentState?.addLinkFromUrl(url);

        if (success == true) {
          // Switch to links page to show the new link
          setState(() {
            _selectedIndex = 1;
            _pageController.jumpToPage(1);
          });

          // Refresh the links page after a short delay
          await Future.delayed(Duration(milliseconds: 300));
          if (mounted) {
            _linksPageKey.currentState?.loadLinks();
          }

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Media saved successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else if (success == false) {
          print('Failed to save media or media already exists: $url');
        }

        // Schedule cleanup of this entry after 2 seconds
        Timer(Duration(milliseconds: 2000), () {
          _processedLinks.remove(linkKey);
        });
      }
    } catch (e) {
      print('Error processing shared media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing shared media'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Reset processing flag after a delay
      Future.delayed(Duration(milliseconds: 1000), () {
        _isProcessingSharedLink = false;
      });
    }
  }

  void _setupPeriodicCleanup() {
    // Clean up processed links periodically to prevent memory leaks
    _cleanupTimer = Timer.periodic(Duration(minutes: 5), (timer) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'LinkNest',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(15),
            ),
          ),
        ),
      ),
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
            onLinkAdded: () => _linksPageKey.currentState?.loadLinks(),
          ),
          LinksPage(
            key: _linksPageKey,
            onRefresh: () => _linksPageKey.currentState?.loadLinks(),
          ),
          Container(), // Placeholder for Folder page
          const MenuPage(),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        color: Theme.of(context).primaryColor,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 71.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home, Icons.home_outlined, 'Home'),
              _buildNavItem(1, Icons.link, Icons.link_outlined, 'Links'),
              const SizedBox(width: 40), // Gap for FAB
              _buildNavItem(2, Icons.folder, Icons.folder_outlined, 'Folder'),
              _buildNavItem(3, Icons.menu, Icons.menu_outlined, 'Menu'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InputPage(
                onLinkAdded: () => _linksPageKey.currentState?.loadLinks(),
              ),
            ),
          );
        },
        shape: const CircleBorder(),
        elevation: 4,
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 50.0,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
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
}