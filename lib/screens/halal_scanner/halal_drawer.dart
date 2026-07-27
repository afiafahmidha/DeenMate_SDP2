import 'package:flutter/material.dart';
import 'halal_scanner_home.dart';
import 'additives_list_screen.dart';
import 'scanned_history_screen.dart';
import 'analyze_product_screen.dart';
import 'health_tips_screen.dart';
import 'guides_and_walkthrough.dart';

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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HalalScannerHomeScreen()),
        (route) => route.isFirst,
      );
    } else {
      Navigator.of(context).pushReplacement(
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
              icon: Icons.notifications_none_rounded,
              label: 'Health tips',
              routeName: 'Health tips',
              destination: const HealthTipsScreen(),
            ),


            _buildDrawerItem(
              context,
              icon: Icons.help_outline_rounded,
              label: 'Guide',
              routeName: 'Guide',
              destination: const GuidesAndWalkthroughScreen(),
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

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Go Premium'),
          ],
        ),
        content: const Text(
          'Unlock unlimited scans, custom additives overrides, ad-free experience, and advanced ingredient AI analysis for only \$1.99/month!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF55A498),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Successfully subscribed to DeenMate Premium!')),
              );
            },
            child: const Text('Subscribe Now'),
          ),
        ],
      ),
    );
  }
}