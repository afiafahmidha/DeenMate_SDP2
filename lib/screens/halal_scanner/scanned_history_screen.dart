import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'halal_scanner_home.dart';
import 'product_detail_screen.dart';
import '../../widgets/auth_header.dart';

class ScannedHistoryScreen extends StatefulWidget {
  final bool isDarkMode;
  const ScannedHistoryScreen({super.key, this.isDarkMode = false});

  @override
  State<ScannedHistoryScreen> createState() => _ScannedHistoryScreenState();
}

class _ScannedHistoryScreenState extends State<ScannedHistoryScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'ALL';

  List<ScannedProduct> get _filteredHistory {
    return HalalScannerState.history.where((product) {
      final query = _searchQuery.toLowerCase().trim();

      bool matchesFilter = true;
      if (_selectedFilter != 'ALL') {
        matchesFilter = product.status.toUpperCase() == _selectedFilter;
      }

      if (!matchesFilter) return false;
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
        title: Text('Clear Scan History?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('This will delete all scanned products from your local storage. This action cannot be undone.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
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
            child: Text('Clear All', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? const Color(0xFF101923) : const Color(0xFFF8FAF9);
    final cardColor = widget.isDarkMode ? const Color(0xFF1A2633) : Colors.white;
    final primaryTextColor = widget.isDarkMode ? Colors.white : AppColors.navyBlue;
    final historyList = _filteredHistory;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.navyBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scanned History',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        actions: [
          if (HalalScannerState.history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
              onPressed: _clearAllHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          if (HalalScannerState.history.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                  ),
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: GoogleFonts.poppins(color: primaryTextColor),
                  decoration: InputDecoration(
                    hintText: 'Search scanned products...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.midTeal),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All (${HalalScannerState.history.length})', cardColor, primaryTextColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('HALAL', 'Halal (${HalalScannerState.halalCount})', cardColor, primaryTextColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('MUSHBOOH', 'Mushbooh (${HalalScannerState.mushboohCount})', cardColor, primaryTextColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('HARAM', 'Haram (${HalalScannerState.haramCount})', cardColor, primaryTextColor),
                ],
              ),
            ),
          ],

          Expanded(
            child: historyList.isEmpty
                ? _buildEmptyState(cardColor, primaryTextColor)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: historyList.length,
                    itemBuilder: (context, index) {
                      final product = historyList[index];
                      return _buildProductCard(product, cardColor, primaryTextColor);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, Color cardColor, Color textColor) {
    bool isSelected = _selectedFilter == filterKey;
    Color activeColor = AppColors.navyBlue;
    if (filterKey == 'HALAL') activeColor = Colors.green;
    if (filterKey == 'MUSHBOOH') activeColor = AppColors.coralOrange;
    if (filterKey == 'HARAM') activeColor = Colors.redAccent;

    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : textColor,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filterKey;
          });
        }
      },
      selectedColor: activeColor,
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEmptyState(Color cardColor, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.midTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.manage_history_rounded, size: 54, color: AppColors.midTeal),
            ),
            const SizedBox(height: 16),
            Text(
              'No scan history found',
              style: GoogleFonts.poppins(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isEmpty
                  ? 'Products scanned by you will automatically appear here.'
                  : 'No products match your search query or filter.',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ScannedProduct product, Color cardColor, Color textColor) {
    Color badgeColor;
    IconData statusIcon;
    if (product.status == 'HALAL') {
      badgeColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
    } else if (product.status == 'HARAM') {
      badgeColor = Colors.redAccent;
      statusIcon = Icons.cancel_rounded;
    } else {
      badgeColor = AppColors.coralOrange;
      statusIcon = Icons.warning_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, color: badgeColor, size: 24),
        ),
        title: Text(
          product.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Barcode: ${product.barcode}',
              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
            ),
            Text(
              'Scanned: ${_formatDate(product.scanDate)}',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            product.status,
            style: GoogleFonts.poppins(
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