import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/links_page.dart';
import 'services/share_service.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ShareService.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Link Saver',
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

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  final GlobalKey<LinksPageState> _linksPageKey = GlobalKey<LinksPageState>();
  late StreamSubscription _sharingIntentSubscription;

  @override
  void initState() {
    super.initState();
    _setupSharingIntent();
  }

  @override
  void dispose() {
    _sharingIntentSubscription.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _setupSharingIntent() {
    _sharingIntentSubscription = ShareService.sharedLinkStream.listen((sharedText) {
      final url = ShareService.extractUrlFromText(sharedText);
      if (url != null) {
        _homeScreenKey.currentState?.addLinkFromUrl(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No valid URL found in shared content')),
        );
      }
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
          'Link Saver',
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
          Container(), // Placeholder for Settings page
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
          _homeScreenKey.currentState?.showAddLinkDialog(context);
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