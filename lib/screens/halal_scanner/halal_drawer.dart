import 'package:flutter/material.dart';
import 'halal_scanner_home.dart';
import 'additives_list_screen.dart';
import 'scanned_history_screen.dart';
import 'analyze_product_screen.dart';
import 'daily_tracker_screen.dart';
import 'seasonal_foods_screen.dart';
import 'health_tips_screen.dart';
import 'additives_preferences_screen.dart';
import 'guides_and_walkthrough.dart';
import 'sources_screen.dart';

class HalalDrawer extends StatelessWidget {
  final String activeRoute;

  const HalalDrawer({
    super.key,
    required this.activeRoute,
  });

  void _navigateTo(BuildContext context, Widget screen, String routeName) {
    Navigator.of(context).pop(); // Close drawer
    if (activeRoute == routeName) return;

    if (routeName == 'Home') {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);

    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer Header
            DrawerHeader(
              decoration: const BoxDecoration(
                color: tealColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'حلال',
                      style: TextStyle(
                        color: tealColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tag Halal Food (v 204)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // General Items
            _buildDrawerItem(
              context,
              icon: Icons.local_offer_outlined,
              label: 'Home',
              routeName: 'Home',
              destination: const HalalScannerHomeScreen(),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.list_alt_rounded,
              label: 'List additives',
              routeName: 'List additives',
              destination: const AdditivesListScreen(),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.history_rounded,
              label: 'Scanned history',
              routeName: 'Scanned history',
              destination: const ScannedHistoryScreen(),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.report_problem_outlined,
              label: 'Report product',
              routeName: 'Report product',
              destination: const AnalyzeProductScreen(),
            ),

            const Divider(),
            _buildSectionHeader('Health & Wellness'),

            _buildDrawerItem(
              context,
              icon: Icons.calendar_today_outlined,
              label: 'Daily tracker',
              routeName: 'Daily tracker',
              destination: const DailyTrackerScreen(),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.eco_outlined,
              label: 'Seasonal foods',
              routeName: 'Seasonal foods',
              destination: const SeasonalFoodsScreen(),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.notifications_none_rounded,
              label: 'Health tips',
              routeName: 'Health tips',
              destination: const HealthTipsScreen(),
            ),

            const Divider(),
            _buildSectionHeader('Personal Settings'),

            _buildActionItem(
              context,
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings is a premium customizable feature!')),
                );
              },
            ),

            const Divider(),
            _buildSectionHeader('Help & Info'),

            _buildDrawerItem(
              context,
              icon: Icons.help_outline_rounded,
              label: 'Guide',
              routeName: 'Guide',
              destination: const GuidesAndWalkthroughScreen(),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.menu_book_outlined,
              label: 'Source',
              routeName: 'Source',
              destination: const SourcesScreen(),
            ),
            _buildActionItem(
              context,
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy policy',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Showing Privacy Policy...')),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String routeName,
    required Widget destination,
  }) {
    final bool isSelected = activeRoute == routeName;
    const tealColor = Color(0xFF55A498);

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? tealColor : Colors.grey[700],
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? tealColor : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: tealColor.withValues(alpha: 0.08),
      onTap: () => _navigateTo(context, destination, routeName),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.grey[700],
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.black87,
        ),
      ),
      onTap: onTap,
    );
  }
}