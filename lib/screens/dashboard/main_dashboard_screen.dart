import 'package:flutter/material.dart';

import '../../community/screens/community_feed_screen.dart';
import '../../events/models/sport_event.dart';
import '../../events/screens/events_screen.dart';
import '../../services/auth_service.dart';
import '../catalog/food_catalog_screen.dart';
import '../journal/meal_water_journal_screen.dart';
import 'user_dashboard_screen.dart';

class MainDashboardScreen extends StatefulWidget {
  final AuthService authService;
  const MainDashboardScreen({super.key, required this.authService});
  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentIndex = 1; // Default to Module 3 Meal & Water Journal
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    final user = widget.authService.currentUser!;
    _screens = [
      FoodCatalogScreen(currentUserId: user.id),
      MealWaterJournalScreen(authService: widget.authService),
      CommunityFeedScreen(user: user),
      UserDashboardScreen(authService: widget.authService),
      EventsScreen(
        user: EventUser(
          id: user.id,
          name: '${user.firstName} ${user.lastName}',
          city: 'Tunis',
          latitude: 36.8065,
          longitude: 10.1815,
          activityLevel: user.activityLevel ?? 'Non renseigné',
          goals: const [],
          interests: const [],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Theme.of(context).colorScheme.surface,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Catalogue',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Journal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: 'Publications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Événements',
          ),
        ],
      ),
    );
  }
}
