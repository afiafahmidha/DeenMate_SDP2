import 'package:flutter/material.dart';
import 'halal_drawer.dart';

class CustomOverride {
  final String code;
  final String originalStatus;
  final String customizedStatus;

  CustomOverride({
    required this.code,
    required this.originalStatus,
    required this.customizedStatus,
  });
}

class AdditivesPreferencesScreen extends StatefulWidget {
  const AdditivesPreferencesScreen({super.key});

  @override
  State<AdditivesPreferencesScreen> createState() => _AdditivesPreferencesScreenState();
}

class _AdditivesPreferencesScreenState extends State<AdditivesPreferencesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // In-memory list of customized overrides
  final List<CustomOverride> _overrides = [];

  void _addNewOverride() {
    String searchCode = '';
    String selectedStatus = 'HALAL';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Additive Preference'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter E-Number code (e.g. E102, E120):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'e.g. E120',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) {
                      searchCode = val.trim().toUpperCase();
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Select your preferred status:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['HALAL', 'HARAM', 'MUSHBOOH'].map((status) {
                      final bool isSelected = selectedStatus == status;
                      Color btnColor = status == 'HALAL'
                          ? Colors.green
                          : status == 'HARAM'
                              ? Colors.red
                              : Colors.orange;

                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedStatus = status;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? btnColor : btnColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: btnColor),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: isSelected ? Colors.white : btnColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF55A498),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (searchCode.isEmpty) return;
                    setState(() {
                      // Remove existing if duplicate
                      _overrides.removeWhere((o) => o.code == searchCode);
                      _overrides.add(
                        CustomOverride(
                          code: searchCode,
                          originalStatus: 'MUSHBOOH', // Mock original
                          customizedStatus: selectedStatus,
                        ),
                      );
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Custom preference for $searchCode saved successfully!')),
                    );
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeOverride(int index) {
    setState(() {
      _overrides.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preference reset to system default.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9F9FA),
      drawer: const HalalDrawer(activeRoute: 'Preferences'),
      appBar: AppBar(
        backgroundColor: tealColor,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        title: const Text(
          'My additives preferences',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 28),
            onPressed: _addNewOverride,
          ),
        ],
      ),
      body: _overrides.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _overrides.length,
              itemBuilder: (context, index) {
                final item = _overrides[index];
                return _buildOverrideCard(item, index);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune_rounded, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'Change the status of each additive that you consider is not correct in your country.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverrideCard(CustomOverride item, int index) {
    Color badgeColor = item.customizedStatus == 'HALAL'
        ? Colors.green
        : item.customizedStatus == 'HARAM'
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        title: Text(
          item.code,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Row(
          children: [
            const Text('Preference: ', style: TextStyle(fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.customizedStatus,
                style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _removeOverride(index),
        ),
      ),
    );
  }
}