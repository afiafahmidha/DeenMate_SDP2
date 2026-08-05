import 'package:flutter/material.dart';
import 'halal_scanner_home.dart';
import 'product_detail_screen.dart';
import 'guides_and_walkthrough.dart';

class ScannedHistoryScreen extends StatefulWidget {
  final bool isDarkMode;
  const ScannedHistoryScreen({super.key, this.isDarkMode = false});

  @override
  State<ScannedHistoryScreen> createState() => _ScannedHistoryScreenState();
}

class _ScannedHistoryScreenState extends State<ScannedHistoryScreen> {
  String _searchQuery = '';

  List<ScannedProduct> get _filteredHistory {
    return HalalScannerState.history.where((product) {
      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          product.barcode.contains(query) ||
          product.status.toLowerCase().contains(query);
    }).toList();
  }

  void _clearAllHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Scan History?'),
        content: const Text('This will delete all scanned products and reset your avoid statistics. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() {
                HalalScannerState.clearHistory();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('History successfully cleared!')),
              );
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);
    final historyList = _filteredHistory;

    return MobileFrame(
      child: Scaffold(
      backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF9F9FA),
      appBar: AppBar(
        backgroundColor: tealColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scanned history',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (HalalScannerState.history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
              onPressed: _clearAllHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search box inside history
          if (HalalScannerState.history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
              ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search scanned products...',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

          Expanded(
            child: historyList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: historyList.length,
                    itemBuilder: (context, index) {
                      final product = historyList[index];
                      return _buildProductCard(product);
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 80, color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.2) : Colors.grey[300]),
            const SizedBox(height: 20),
            const Text(
              'No results found for your search.',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Products scanned by you will appear here.'
                  : 'Try typing different keywords.',
              style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.grey[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ScannedProduct product) {
    Color badgeColor;
    if (product.status == 'HALAL') {
      badgeColor = Colors.green;
    } else if (product.status == 'HARAM') {
      badgeColor = Colors.red;
    } else {
      badgeColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          product.name,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: widget.isDarkMode ? Colors.white : Colors.black87),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Barcode: ${product.barcode}',
              style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              'Scanned: ${_formatDate(product.scanDate)}',
              style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.grey[400], fontSize: 11),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            product.status,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: product, isDarkMode: widget.isDarkMode),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}