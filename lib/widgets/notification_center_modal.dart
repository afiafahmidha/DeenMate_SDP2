import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';

class NotificationCenterModal extends StatefulWidget {
  final Function(String prayerName)? onPrayed;
  final Function(String prayerName)? onSnooze;
  final Function(NotificationItem item)? onNotificationTap;
  final bool? isDarkMode;

  const NotificationCenterModal({
    super.key,
    this.onPrayed,
    this.onSnooze,
    this.onNotificationTap,
    this.isDarkMode,
  });

  static Future<void> show(
    BuildContext context, {
    Function(String prayerName)? onPrayed,
    Function(String prayerName)? onSnooze,
    Function(NotificationItem item)? onNotificationTap,
    bool? isDarkMode,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationCenterModal(
        onPrayed: onPrayed,
        onSnooze: onSnooze,
        onNotificationTap: onNotificationTap,
        isDarkMode: isDarkMode,
      ),
    );
  }

  @override
  State<NotificationCenterModal> createState() =>
      _NotificationCenterModalState();
}

class _NotificationCenterModalState extends State<NotificationCenterModal> {
  String _selectedCategory = 'all';
  bool _showSettings = false;
  bool _hasPermission = true;
  DateTime? _upcomingFastingDate;

  final List<Map<String, String>> _categories = const [
    {'id': 'all', 'label': 'All'},
    {'id': 'prayers', 'label': 'Prayers'},
    {'id': 'dhikr', 'label': 'Dhikr'},
    {'id': 'zakat', 'label': 'Zakat'},
    {'id': 'quran', 'label': 'Quran'},
    {'id': 'events', 'label': 'Events'},
    {'id': 'sos', 'label': 'SOS'},
  ];

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadUpcomingFasting();
    NotificationService.instance.fastingAlarmsRevision
        .addListener(_loadUpcomingFasting);
  }

  @override
  void dispose() {
    NotificationService.instance.fastingAlarmsRevision
        .removeListener(_loadUpcomingFasting);
    super.dispose();
  }

  Future<void> _loadUpcomingFasting() async {
    final date =
        await NotificationService.instance.getEarliestUpcomingFastingDate();
    if (mounted) {
      setState(() {
        _upcomingFastingDate = date;
      });
    }
  }

  Future<void> _checkPermission() async {
    final granted =
        await NotificationService.instance.checkAndRequestPermissions();
    if (mounted) {
      setState(() {
        _hasPermission = granted;
      });
    }
  }

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'prayers':
        return const Color(0xFF1D3557);
      case 'dhikr':
        return const Color(0xFFE63946);
      case 'zakat':
        return const Color(0xFF2A9D8F);
      case 'quran':
        return const Color(0xFF457B9D);
      case 'events':
        return const Color(0xFFE9C46A);
      case 'sos':
        return const Color(0xFFD62828);
      default:
        return const Color(0xFF1D3557);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day}/${dt.month} $hour:$minute $period';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = widget.isDarkMode ??
        Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1D3557);
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    final history = NotificationService.instance.history;
    final filteredItems = history.where((item) {
      if (_selectedCategory != 'all' && item.category != _selectedCategory) {
        return false;
      }
      // Filter out pre-scheduled or legacy fasting entries from history
      // so only the dynamic upcoming fast is shown without duplicate or stale items
      if (item.category == 'events' &&
          (item.title.toLowerCase().contains('fasting') ||
              item.title.contains('রোজা'))) {
        return false;
      }
      return true;
    }).toList();

    final showUpcomingFast = _upcomingFastingDate != null &&
        (_selectedCategory == 'all' || _selectedCategory == 'events');
    final hasContent = filteredItems.isNotEmpty || showUpcomingFast;
    final totalCount = filteredItems.length + (showUpcomingFast ? 1 : 0);

    return Container(
      height: size.height * 0.85,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle bar
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _showSettings ? 'Notification Settings' : 'Notification Center',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<int>(
                        valueListenable:
                            NotificationService.instance.unreadCountNotifier,
                        builder: (context, unreadCount, _) {
                          if (unreadCount == 0 || _showSettings) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE63946),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount new',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _showSettings
                            ? Icons.notifications_active_rounded
                            : Icons.settings_outlined,
                        color: textColor,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _showSettings = !_showSettings;
                        });
                      },
                    ),
                    if (!_showSettings)
                      IconButton(
                        icon: Icon(
                          Icons.done_all_rounded,
                          color: textColor.withValues(alpha: 0.7),
                          size: 22,
                        ),
                        tooltip: 'Mark all as read',
                        onPressed: () async {
                          await NotificationService.instance.markAllAsRead();
                          setState(() {});
                        },
                      ),
                    if (!_showSettings)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          size: 22,
                        ),
                        tooltip: 'Clear all notifications',
                        onPressed: () async {
                          await NotificationService.instance.clearHistory();
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 16, color: dividerColor),

          // Permission warning banner if permission is missing
          if (!_hasPermission)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade700, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                      'Notifications disabled in phone settings.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final ok = await NotificationService.instance
                          .checkAndRequestPermissions();
                      setState(() {
                        _hasPermission = ok;
                      });
                    },
                    child: Text(
                      'Enable',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Settings View OR Notification Feed
          Expanded(
            child: _showSettings
                ? _buildSettingsView(textColor, isDark)
                : Column(
                    children: [
                      // Category Filter Chips
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final selected = _selectedCategory == cat['id'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  cat['label']!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: selected
                                        ? Colors.white
                                        : isDark
                                            ? Colors.white70
                                            : textColor.withValues(alpha: 0.8),
                                  ),
                                ),
                                selected: selected,
                                // Set colors per state because the app's
                                // light Material theme can override the
                                // default ChoiceChip background color.
                                color: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return const Color(0xFF1D3557);
                                  }
                                  return isDark
                                      ? const Color(0xFF303030)
                                      : Colors.black.withValues(alpha: 0.05);
                                }),
                                surfaceTintColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: selected
                                        ? const Color(0xFF1D3557)
                                        : Colors.transparent,
                                  ),
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() {
                                      _selectedCategory = cat['id']!;
                                    });
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Notification History Feed
                      Expanded(
                        child: !hasContent
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_none_rounded,
                                      size: 54,
                                      color: textColor.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No notifications in this section.',
                                      style: GoogleFonts.inter(
                                        color: textColor.withValues(alpha: 0.5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  40,
                                ),
                                itemCount: totalCount,
                                itemBuilder: (context, index) {
                                  if (showUpcomingFast && index == 0) {
                                    return _buildUpcomingFastingCard(
                                      _upcomingFastingDate!,
                                      textColor,
                                      isDark,
                                    );
                                  }
                                  final itemIndex =
                                      showUpcomingFast ? index - 1 : index;
                                  final item = filteredItems[itemIndex];
                                  final accent = _categoryColor(item.category);

                                  return Dismissible(
                                    key: Key(item.id),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (_) {
                                      setState(() {
                                        NotificationService.instance
                                            .deleteNotificationItem(item.id);
                                      });
                                    },
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding:
                                          const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      elevation: 0,
                                      color: item.isRead
                                          ? (isDark
                                              ? Colors.white.withValues(alpha: 0.04)
                                              : Colors.grey.withValues(alpha: 0.06))
                                          : (isDark
                                              ? accent.withValues(alpha: 0.15)
                                              : accent.withValues(alpha: 0.08)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: item.isRead
                                              ? Colors.transparent
                                              : accent.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () async {
                                          await NotificationService.instance
                                              .markAsRead(item.id);
                                          setState(() {});
                                          widget.onNotificationTap?.call(item);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: accent.withValues(
                                                          alpha: 0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      item.category
                                                          .toUpperCase(),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: accent,
                                                      ),
                                                    ),
                                                  ),
                                                   Row(
                                                     children: [
                                                       Text(
                                                         _formatTimestamp(
                                                             item.timestamp),
                                                         style: GoogleFonts.inter(
                                                           fontSize: 11,
                                                           color: textColor
                                                               .withValues(alpha: 0.5),
                                                         ),
                                                       ),
                                                       const SizedBox(width: 6),
                                                       InkWell(
                                                         onTap: () {
                                                           NotificationService.instance
                                                               .deleteNotificationItem(item.id);
                                                           setState(() {});
                                                         },
                                                         child: Padding(
                                                           padding: const EdgeInsets.all(2),
                                                           child: Icon(
                                                             Icons.close_rounded,
                                                             size: 16,
                                                             color: textColor
                                                                 .withValues(alpha: 0.4),
                                                           ),
                                                         ),
                                                       ),
                                                     ],
                                                   ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                item.title,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: textColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.body,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: textColor
                                                      .withValues(alpha: 0.8),
                                                ),
                                              ),

                                              // Actionable buttons for prayer items
                                              if (item.prayerName != null) ...[
                                                const SizedBox(height: 10),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    OutlinedButton(
                                                      style: OutlinedButton
                                                          .styleFrom(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 14,
                                                          vertical: 6,
                                                        ),
                                                        side: BorderSide(
                                                          color: accent,
                                                        ),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        widget.onSnooze?.call(
                                                            item.prayerName!);
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              '${item.prayerName} snoozed for ${NotificationService.instance.snoozeDurationMinutes} minutes',
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      child: Text(
                                                        'Snooze (${NotificationService.instance.snoozeDurationMinutes}m)',
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 11,
                                                          color: accent,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ElevatedButton(
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor: accent,
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 16,
                                                          vertical: 6,
                                                        ),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        widget.onPrayed?.call(
                                                            item.prayerName!);
                                                        NotificationService
                                                            .instance
                                                            .markAsRead(item.id);
                                                        setState(() {});
                                                      },
                                                      child: Text(
                                                        'Prayed',
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 11,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingFastingCard(
    DateTime date,
    Color textColor,
    bool isDark,
  ) {
    final isMonday = date.weekday == DateTime.monday;
    final isThursday = date.weekday == DateTime.thursday;
    final dateStr = DateFormat('EEEE, d MMMM').format(date);
    final eveningBefore = date.subtract(const Duration(days: 1));
    final eveDayStr = DateFormat('EEEE').format(eveningBefore);

    String fastTitle = 'Sunnah Fast';
    if (isMonday) {
      fastTitle = 'Sunnah Monday Fast';
    } else if (isThursday) {
      fastTitle = 'Sunnah Thursday Fast';
    } else {
      fastTitle = 'Voluntary (Nafl) Fast';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark
          ? const Color(0xFFE9C46A).withValues(alpha: 0.12)
          : const Color(0xFFFFF9E6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFE9C46A).withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9C46A).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'EVENTS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFFFFD54F)
                          : const Color(0xFFB78103),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A9D8F).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        size: 11,
                        color: Color(0xFF2A9D8F),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'UPCOMING FAST',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2A9D8F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$fastTitle – $dateStr',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Reminder scheduled for $eveDayStr at Maghrib (sunset, Islamic start of day). Make intention (Niyyah) and prepare for Suhoor.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsView(Color textColor, bool isDark) {
    final service = NotificationService.instance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: [
        // Master Notification Toggle
        SwitchListTile(
          title: Text(
            'Master Notifications',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          subtitle: Text(
            'Turn off to pause all alarms and reminders',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
          value: service.masterEnabled,
          activeColor: isDark ? const Color(0xFF80CBC4) : const Color(0xFF1D3557),
          onChanged: (val) async {
            await service.setMasterEnabled(val);
            setState(() {});
          },
        ),

        Divider(height: 24, color: isDark ? Colors.white12 : Colors.black12),

        // Snooze Duration Selector
        Text(
          'Snooze Duration',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose recurring interval when snoozing prayer alarms',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: textColor.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [5, 10, 15, 20, 30].map((mins) {
            final isSelected = service.snoozeDurationMinutes == mins;
            return ChoiceChip(
              label: Text('$mins minutes'),
              selected: isSelected,
              // Use explicit state colors: the app's global light theme can
              // otherwise force a pale surface under the dark-mode text.
              color: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF1D3557);
                }
                return isDark
                    ? const Color(0xFF303030)
                    : Colors.black.withValues(alpha: 0.05);
              }),
              surfaceTintColor: Colors.transparent,
              labelStyle: GoogleFonts.inter(
                color: isSelected
                    ? Colors.white
                    : isDark
                        ? Colors.white70
                        : textColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (val) async {
                if (val) {
                  await service.setSnoozeDuration(mins);
                  setState(() {});
                }
              },
            );
          }).toList(),
        ),

        Divider(height: 28, color: isDark ? Colors.white12 : Colors.black12),

        // Feature Categories
        Text(
          'Category Preferences',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),

        _buildCategorySwitch('prayers', 'Prayer Adhan Alarms', service, textColor, isDark),
        _buildCategorySwitch('dhikr', 'Dhikr & Tasbih Reminders', service, textColor, isDark),
        _buildCategorySwitch('zakat', 'Zakat & Nisab Alerts', service, textColor, isDark),
        _buildCategorySwitch('quran', 'Daily Quran Streaks', service, textColor, isDark),
        _buildCategorySwitch('events', 'Islamic Event Calendar', service, textColor, isDark),
        _buildCategorySwitch('sos', 'Emergency SOS Alerts', service, textColor, isDark),
      ],
    );
  }

  Widget _buildCategorySwitch(
    String key,
    String label,
    NotificationService service,
    Color textColor,
    bool isDark,
  ) {
    return SwitchListTile(
      dense: true,
      title: Text(
        label,
        style: GoogleFonts.inter(fontSize: 13, color: textColor),
      ),
      value: service.isCategoryEnabled(key),
      activeColor: isDark ? const Color(0xFF80CBC4) : const Color(0xFF1D3557),
      onChanged: (val) async {
        await service.setCategoryEnabled(key, val);
        setState(() {});
      },
    );
  }
}
