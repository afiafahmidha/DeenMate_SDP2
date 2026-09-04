import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/auth_header.dart';
import '../services/notification_service.dart';
import 'zakat_manager_screen.dart';

// =============================================================================
// REUSABLE DEENMATE AVATAR WIDGET
// =============================================================================
class DeenMateAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String? avatarBase64;
  final double radius;

  const DeenMateAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.avatarBase64,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (avatarBase64 != null && avatarBase64!.trim().isNotEmpty) {
      try {
        final bytes = base64Decode(avatarBase64!.trim());
        content = Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (_, __, ___) => _fallbackText(),
        );
      } catch (_) {
        content = _fallbackText();
      }
    } else if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      content = Image.network(
        photoUrl!.trim(),
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        errorBuilder: (_, __, ___) => _fallbackText(),
      );
    } else {
      content = _fallbackText();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: AppColors.midTeal.withValues(alpha: 0.15),
        child: content,
      ),
    );
  }

  Widget _fallbackText() {
    final initial = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'U';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.midTeal,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.95,
        ),
      ),
    );
  }
}

// =============================================================================
// MODELS
// =============================================================================

class QParticipant {
  final String id;
  final String name;
  final String? phone;
  final int shares;
  final double amountDue;
  final double amountPaid;
  final String paymentStatus; // "unpaid" | "partial" | "paid"
  final String ownerId;
  final String ownerName;
  final String? photoUrl;
  final String? avatarBase64;
  final bool isDeenMateUser;
  final String? uid;

  QParticipant({
    required this.id,
    required this.name,
    this.phone,
    required this.shares,
    this.amountDue = 0,
    this.amountPaid = 0,
    this.paymentStatus = 'unpaid',
    required this.ownerId,
    required this.ownerName,
    this.photoUrl,
    this.avatarBase64,
    this.isDeenMateUser = false,
    this.uid,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'shares': shares,
        'amountDue': amountDue,
        'amountPaid': amountPaid,
        'paymentStatus': paymentStatus,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'photoUrl': photoUrl,
        'avatarBase64': avatarBase64,
        'isDeenMateUser': isDeenMateUser,
        'uid': uid,
      };

  factory QParticipant.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return QParticipant(
      id: d.id,
      name: m['name'] ?? '',
      phone: m['phone'],
      shares: (m['shares'] ?? 1) as int,
      amountDue: (m['amountDue'] ?? 0).toDouble(),
      amountPaid: (m['amountPaid'] ?? 0).toDouble(),
      paymentStatus: m['paymentStatus'] ?? 'unpaid',
      ownerId: m['ownerId'] ?? '',
      ownerName: m['ownerName'] ?? 'Unknown',
      photoUrl: m['photoUrl'] as String?,
      avatarBase64: m['avatarBase64'] as String?,
      isDeenMateUser: m['isDeenMateUser'] as bool? ?? false,
      uid: m['uid'] as String?,
    );
  }

  QParticipant copyWith({String? name, int? shares}) => QParticipant(
        id: id,
        name: name ?? this.name,
        phone: phone,
        shares: shares ?? this.shares,
        amountDue: amountDue,
        amountPaid: amountPaid,
        paymentStatus: paymentStatus,
        ownerId: ownerId,
        ownerName: ownerName,
        photoUrl: photoUrl,
        avatarBase64: avatarBase64,
        isDeenMateUser: isDeenMateUser,
        uid: uid,
      );
}

class QPlanMember {
  final String id;
  final String name;
  final int shares;
  final String? photoUrl;
  final String? avatarBase64;

  const QPlanMember({required this.id, required this.name, required this.shares, this.photoUrl, this.avatarBase64});

  factory QPlanMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    return QPlanMember(
      id: d.id,
      name: data['name'] as String? ?? 'Unnamed member',
      shares: (data['shares'] as num?)?.toInt() ?? 1,
      photoUrl: data['photoUrl'] as String?,
      avatarBase64: data['avatarBase64'] as String?,
    );
  }
}

class QPayer {
  final String participantId;
  final double amount;
  const QPayer({required this.participantId, required this.amount});

  Map<String, dynamic> toMap() => {'participantId': participantId, 'amount': amount};

  factory QPayer.fromMap(Map<String, dynamic> m) => QPayer(
        participantId: m['participantId'] ?? '',
        amount: (m['amount'] ?? 0).toDouble(),
      );
}

class QExpense {
  final String id;
  final String category;
  final double amount;
  final String notes;
  final List<QPayer> payers;
  final String ownerId;
  final String ownerName;
  final String? photoUrl;
  final String? avatarBase64;
  final DateTime createdAt;

  QExpense({
    required this.id,
    required this.category,
    required this.amount,
    required this.notes,
    required this.payers,
    required this.ownerId,
    required this.ownerName,
    this.photoUrl,
    this.avatarBase64,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'category': category,
        'amount': amount,
        'notes': notes,
        'payers': payers.map((p) => p.toMap()).toList(),
        'ownerId': ownerId,
        'ownerName': ownerName,
        'photoUrl': photoUrl,
        'avatarBase64': avatarBase64,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory QExpense.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return QExpense(
      id: d.id,
      category: m['category'] ?? '',
      amount: (m['amount'] ?? 0).toDouble(),
      notes: m['notes'] ?? '',
      payers: ((m['payers'] ?? []) as List)
          .map((e) => QPayer.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      ownerId: m['ownerId'] ?? '',
      ownerName: m['ownerName'] ?? 'Unknown',
      photoUrl: m['photoUrl'] as String?,
      avatarBase64: m['avatarBase64'] as String?,
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class QChatMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String? photoUrl;
  final String? avatarBase64;
  final String text;
  final String mediaType; // 'text' | 'image' | 'video' | 'audio' | 'document'
  final String? mediaData; // Base64 or URL
  final String? fileName;
  final bool? edited;
  final DateTime createdAt;

  QChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    this.photoUrl,
    this.avatarBase64,
    required this.text,
    this.mediaType = 'text',
    this.mediaData,
    this.fileName,
    this.edited,
    required this.createdAt,
  });

  factory QChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return QChatMessage(
      id: d.id,
      senderUid: m['senderId'] ?? m['senderUid'] ?? '',
      senderName: m['senderName'] ?? 'Member',
      photoUrl: m['photoUrl'] as String?,
      avatarBase64: m['avatarBase64'] as String?,
      text: m['text'] ?? '',
      mediaType: m['mediaType'] as String? ?? 'text',
      mediaData: m['mediaData'] as String?,
      fileName: m['fileName'] as String?,
      edited: m['edited'] as bool?,
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class QurbaniSharePost {
  final String id;
  final String posterUid;
  final String posterName;
  final String? posterPhone;
  final String? photoUrl;
  final String? avatarBase64;
  final String animalType; // 'cow', 'camel', 'buffalo', 'goat'
  final int totalShares;
  final int availableShares;
  final double costPerShare;
  final String locationName;
  final double latitude;
  final double longitude;
  final String description;
  final String status; // 'active', 'matched', 'closed'
  final DateTime createdAt;
  final String? planId;
  final String? planOwnerUid;

  QurbaniSharePost({
    required this.id,
    required this.posterUid,
    required this.posterName,
    this.posterPhone,
    this.photoUrl,
    this.avatarBase64,
    required this.animalType,
    required this.totalShares,
    required this.availableShares,
    required this.costPerShare,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.status,
    required this.createdAt,
    this.planId,
    this.planOwnerUid,
  });

  factory QurbaniSharePost.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return QurbaniSharePost(
      id: d.id,
      posterUid: m['posterUid'] ?? '',
      posterName: m['posterName'] ?? 'Poster',
      posterPhone: m['posterPhone'] as String?,
      photoUrl: m['photoUrl'] as String?,
      avatarBase64: m['avatarBase64'] as String?,
      animalType: m['animalType'] ?? 'cow',
      totalShares: (m['totalShares'] ?? 7) as int,
      availableShares: (m['availableShares'] ?? 1) as int,
      costPerShare: (m['costPerShare'] ?? 0).toDouble(),
      locationName: m['locationName'] ?? 'Dhaka',
      latitude: (m['latitude'] ?? 0.0).toDouble(),
      longitude: (m['longitude'] ?? 0.0).toDouble(),
      description: m['description'] ?? '',
      status: m['status'] ?? 'active',
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      planId: m['planId'] as String?,
      planOwnerUid: m['planOwnerUid'] as String?,
    );
  }
}

class QPlanSummary {
  final String ownerUid;
  final String planId;
  final String ownerName;
  final String animalType;
  final int totalShares;
  final bool isOwner;

  QPlanSummary({
    required this.ownerUid,
    required this.planId,
    required this.ownerName,
    required this.animalType,
    required this.totalShares,
    required this.isOwner,
  });
}

class QShareResponse {
  final String id;
  final String postId;
  final String responderUid;
  final String responderName;
  final String? photoUrl;
  final String? avatarBase64;
  final int sharesRequested;
  final String note;
  final String status; // 'pending', 'accepted', 'rejected', 'filled', 'joined'
  final String? inviteCode; // set when poster accepts — used by responder to join
  final String? rejectReason; // reason if poster declined
  final DateTime createdAt;

  QShareResponse({
    required this.id,
    required this.postId,
    required this.responderUid,
    required this.responderName,
    this.photoUrl,
    this.avatarBase64,
    required this.sharesRequested,
    required this.note,
    required this.status,
    this.inviteCode,
    this.rejectReason,
    required this.createdAt,
  });

  factory QShareResponse.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return QShareResponse(
      id: d.id,
      postId: m['postId'] ?? '',
      responderUid: m['responderUid'] ?? '',
      responderName: m['responderName'] ?? 'Responder',
      photoUrl: m['photoUrl'] as String?,
      avatarBase64: m['avatarBase64'] as String?,
      sharesRequested: (m['sharesRequested'] ?? 1) as int,
      note: m['note'] ?? '',
      status: m['status'] ?? 'pending',
      inviteCode: m['inviteCode'] as String?,
      rejectReason: m['rejectReason'] as String?,
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

enum QEditTargetType { participant, expense }

class QEditRequest {
  final String id;
  final QEditTargetType targetType;
  final String targetId;
  final String targetLabel; // human-readable snapshot, e.g. participant name / expense category
  final String targetOwnerId; // the owner of the targeted item — only this person can approve/reject
  final String requestedById;
  final String requestedByName;
  final String reason;
  final Map<String, dynamic> proposedChanges; // e.g. {'name': 'New name'} or {'amount': 500.0}
  final String status; // pending | approved | rejected
  final DateTime createdAt;

  QEditRequest({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    required this.targetOwnerId,
    required this.requestedById,
    required this.requestedByName,
    required this.reason,
    required this.proposedChanges,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'targetType': targetType.name,
        'targetId': targetId,
        'targetLabel': targetLabel,
        'targetOwnerId': targetOwnerId,
        'requestedById': requestedById,
        'requestedByName': requestedByName,
        'reason': reason,
        'proposedChanges': proposedChanges,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory QEditRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return QEditRequest(
      id: d.id,
      targetType: (m['targetType'] == 'expense') ? QEditTargetType.expense : QEditTargetType.participant,
      targetId: m['targetId'] ?? '',
      targetLabel: m['targetLabel'] ?? '',
      targetOwnerId: m['targetOwnerId'] ?? '',
      requestedById: m['requestedById'] ?? '',
      requestedByName: m['requestedByName'] ?? 'Unknown',
      reason: m['reason'] ?? '',
      proposedChanges: Map<String, dynamic>.from(m['proposedChanges'] ?? {}),
      status: m['status'] ?? 'pending',
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

// A confirmed (or pending) settlement payment between two participants.
class QSettlement {
  final String id;
  final String fromId;
  final String fromName;
  final String toId;
  final String toName;
  final double amount;
  final bool confirmed;
  final DateTime date;

  QSettlement({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.amount,
    required this.confirmed,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'fromId': fromId,
        'fromName': fromName,
        'toId': toId,
        'toName': toName,
        'amount': amount,
        'confirmed': confirmed,
        'date': Timestamp.fromDate(date),
      };

  factory QSettlement.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return QSettlement(
      id: d.id,
      fromId: m['fromId'] ?? '',
      fromName: m['fromName'] ?? '',
      toId: m['toId'] ?? '',
      toName: m['toName'] ?? '',
      amount: (m['amount'] ?? 0).toDouble(),
      confirmed: m['confirmed'] ?? false,
      date: (m['date'] is Timestamp) ? (m['date'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}



// A suggested (not-yet-recorded) payment produced by the debt-simplification
// algorithm. Purely computed, never stored.
class SuggestedPayment {
  final QParticipant from;
  final QParticipant to;
  final double amount;
  SuggestedPayment({required this.from, required this.to, required this.amount});
}

// =============================================================================
// SETTLEMENT / DEBT-SIMPLIFICATION LOGIC
// =============================================================================
//
// Balance model:
//   share of cost   = (participant.shares / totalShares) * totalExpenses
//   raw balance     = totalPaidOnExpenses(participant) - shareOfCost
//   effective bal.  = raw balance, then adjusted by every CONFIRMED settlement:
//                       payer's balance moves toward 0 (+amount)
//                       receiver's balance moves toward 0 (-amount)
//
// A positive effective balance means the participant is OWED money overall
// (they fronted more than their share and haven't been paid back).
// A negative effective balance means the participant still OWES money.
//
// The suggested payments are the minimum-transaction settlement of whatever
// is LEFT after confirmed settlements — recomputed fresh every time, so it
// doesn't matter how people actually chose to pay each other so far.

class QBalanceRow {
  final QParticipant participant;
  final double shareOfCost; // "Owes" column (their portion of total cost)
  final double totalPaid; // "Paid" column (what they've physically paid on expenses)
  final double effectiveBalance; // "Balance" column, after confirmed settlements
  QBalanceRow({
    required this.participant,
    required this.shareOfCost,
    required this.totalPaid,
    required this.effectiveBalance,
  });
}

class SettlementEngine {
  static List<QBalanceRow> computeBalances({
    required List<QParticipant> participants,
    required List<QExpense> expenses,
    required List<QSettlement> settlements,
  }) {
    final totalShares = participants.fold<int>(0, (s, p) => s + p.shares);
    final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);

    final paidMap = <String, double>{for (final p in participants) p.id: 0.0};
    for (final e in expenses) {
      for (final payer in e.payers) {
        paidMap[payer.participantId] = (paidMap[payer.participantId] ?? 0) + payer.amount;
      }
    }

    final rawBalance = <String, double>{};
    final shareMap = <String, double>{};
    for (final p in participants) {
      final share = totalShares == 0 ? 0.0 : totalExpenses * (p.shares / totalShares);
      shareMap[p.id] = share;
      rawBalance[p.id] = (paidMap[p.id] ?? 0) - share;
    }

    // Apply confirmed settlements only.
    final effective = Map<String, double>.from(rawBalance);
    for (final s in settlements.where((s) => s.confirmed)) {
      effective[s.fromId] = (effective[s.fromId] ?? 0) + s.amount;
      effective[s.toId] = (effective[s.toId] ?? 0) - s.amount;
    }

    return participants
        .map((p) => QBalanceRow(
              participant: p,
              shareOfCost: shareMap[p.id] ?? 0,
              totalPaid: paidMap[p.id] ?? 0,
              effectiveBalance: effective[p.id] ?? 0,
            ))
        .toList();
  }

  /// Greedy minimum-transaction debt simplification over the *current*
  /// effective balances (i.e. what's left after confirmed settlements).
  static List<SuggestedPayment> suggestPayments(List<QBalanceRow> balances) {
    const epsilon = 0.5; // ignore sub-taka rounding noise

    final creditors = balances
        .where((b) => b.effectiveBalance > epsilon)
        .map((b) => MapEntry(b.participant, b.effectiveBalance))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final debtors = balances
        .where((b) => b.effectiveBalance < -epsilon)
        .map((b) => MapEntry(b.participant, -b.effectiveBalance)) // store as positive owed amount
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = <SuggestedPayment>[];
    int ci = 0, di = 0;
    final cred = creditors.map((e) => MapEntry(e.key, e.value)).toList();
    final debt = debtors.map((e) => MapEntry(e.key, e.value)).toList();

    while (ci < cred.length && di < debt.length) {
      final c = cred[ci];
      final d = debt[di];
      final amt = c.value < d.value ? c.value : d.value;

      if (amt > epsilon) {
        result.add(SuggestedPayment(from: d.key, to: c.key, amount: amt));
      }

      cred[ci] = MapEntry(c.key, c.value - amt);
      debt[di] = MapEntry(d.key, d.value - amt);

      if (cred[ci].value <= epsilon) ci++;
      if (debt[di].value <= epsilon) di++;
    }

    return result;
  }
}

// =============================================================================
// REPOSITORY — Cloud Firestore backed storage
// =============================================================================
//
// Aligned with the app-wide schema already in use elsewhere in DeenMate:
//
//   users/{ownerUid}/qurbaniPlans/{planId}
//   ├── year, status, animalType, totalShares, myShares, estimatedCost,
//   │   paidAmount, vendorName, vendorPhone, slaughterDate, notes,
//   │   createdAt, updatedAt                       (existing schema fields)
//   ├── ownerId, ownerName, memberIds: array<string> (added for sharing —
//   │   same pattern as emergencyGroups' members-based access)
//   │
//   ├── participants/{participantId}
//   │     name, phone?, shares, amountDue, amountPaid, paymentStatus,
//   │     ownerId, ownerName                        (ownerId/ownerName added)
//   │
//   ├── distributions/{distributionId}               (existing schema, as-is)
//   │
//   ├── expenses/{expenseId}                         (new sub-collection)
//   │     category, amount, notes, payers[], ownerId, ownerName, createdAt
//   │
//   ├── editRequests/{requestId}                     (new sub-collection)
//   │     targetType, targetId, targetLabel, requestedById, requestedByName,
//   │     reason, proposedChanges, status, createdAt
//   │
//   ├── settlements/{settlementId}                   (new sub-collection)
//   │     fromId, fromName, toId, toName, amount, confirmed, date
//   │
//   └── checklist/{itemId}                           (new sub-collection)
//         done: bool
//
// Top-level lookup collection (mirrors the SOS feature's inviteTokens idea,
// simplified — this is a low-stakes join code, not a security-sensitive one,
// so it's stored in plain text rather than hashed):
//
//   qurbaniPlanInvites/{code} -> { ownerUid, planId, createdAt }
//
// A user's own plans are found locally (planId + ownerUid cached via
// SharedPreferences after creation/joining) rather than via a collection
// group query, so no extra composite index is required. If you'd rather
// list "my plans" straight from Firestore (e.g. for a plans-picker screen),
// add `collectionGroup('qurbaniPlans').where('memberIds', arrayContains: uid)`
// once the corresponding security rule and index are in place.
//
// SECURITY RULES — add alongside your existing rules:
//   match /users/{ownerUid}/qurbaniPlans/{planId} {
//     allow read, write: if request.auth.uid in resource.data.memberIds
//         || request.auth.uid == ownerUid;
//     match /{sub=**} {
//       allow read, write: if request.auth.uid in
//           get(/databases/$(database)/documents/users/$(ownerUid)/qurbaniPlans/$(planId)).data.memberIds
//           || request.auth.uid == ownerUid;
//     }
//   }
//   match /qurbaniPlanInvites/{code} {
//     allow read: if request.auth != null;
//     allow create: if request.auth.uid == request.resource.data.ownerUid;
//   }
class QurbaniRepository {
  QurbaniRepository._(this.ownerUid, this.planId);
  final String ownerUid;
  final String planId;

  // UID-scoped pref keys so each Firebase account keeps its own group, even
  // when multiple accounts share the same device / SharedPreferences store.
  static String _prefsOwnerKey() => 'qurbani_plan_owner_uid_${currentUid()}';
  static String _prefsPlanKey()  => 'qurbani_plan_id_${currentUid()}';

  /// Fetches current user's avatarBase64 from SharedPreferences or Firestore user document.
  /// Checks the UID-namespaced key first (written by profile_tab after an update),
  /// then falls back to the legacy global key, then Firestore.
  static Future<String?> currentAvatarBase64() async {
    try {
      final uid = currentUid();
      final prefs = await SharedPreferences.getInstance();

      // 1. Prefer the namespaced key — always written on image update.
      final namespaced = prefs.getString('profile_avatar_base64_$uid');
      if (namespaced != null && namespaced.trim().isNotEmpty) {
        return namespaced.trim();
      }

      // 2. Fall back to legacy global key (old devices / web that haven't updated yet).
      final legacy = prefs.getString('profile_avatar_base64');
      if (legacy != null && legacy.trim().isNotEmpty) {
        // Migrate it to the namespaced key so future reads are faster.
        await prefs.setString('profile_avatar_base64_$uid', legacy.trim());
        return legacy.trim();
      }

      // 3. Fetch from Firestore as the definitive source of truth.
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final profile = doc.data()?['profile'] as Map<String, dynamic>?;
        if (profile != null && profile['avatarBase64'] != null) {
          final b64 = (profile['avatarBase64'] as String).trim();
          if (b64.isNotEmpty) {
            // Cache under both keys for future calls.
            await prefs.setString('profile_avatar_base64_$uid', b64);
            await prefs.setString('profile_avatar_base64', b64);
            return b64;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching DeenMate avatar: $e");
    }
    return null;
  }

  /// Loads the active group for the signed-in user.
  ///
  /// Strategy (in priority order):
  ///   1. If local SharedPreferences has a saved ownerUid+planId, validate it
  ///      against Firestore and return it if still valid.
  ///   2. Check if the user owns any plan (users/{uid}/qurbaniPlans).
  ///   3. Check the collectionGroup for plans where memberIds contains uid.
  ///   4. Check if the user has a members subcollection document in any plan
  ///      (handles the edge case where memberIds array wasn't updated).
  ///
  /// On success the ownerUid+planId is always persisted so future loads are fast.
  static Future<QurbaniRepository?> load() async {
    final uid = currentUid();
    if (uid == 'local_device') return null;

    // ── Step 1: Check Cloud User Document for activeQurbaniPlan (100% Cross-Device & Web Synced)
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final active = userDoc.data()?['activeQurbaniPlan'] as Map<String, dynamic>?;
        if (active != null) {
          final owner = active['ownerUid'] as String?;
          final plan = active['planId'] as String?;
          if (owner != null && plan != null) {
            final planDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(owner)
                .collection('qurbaniPlans')
                .doc(plan)
                .get();
            if (planDoc.exists) {
              await _persist(owner, plan);
              return QurbaniRepository._(owner, plan);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking cloud activeQurbaniPlan: $e");
    }

    // ── Step 2: Check Cloud joinedQurbaniPlans subcollection ─────────────────
    try {
      final joinedSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('joinedQurbaniPlans')
          .limit(1)
          .get();
      if (joinedSnap.docs.isNotEmpty) {
        final jData = joinedSnap.docs.first.data();
        final owner = (jData['ownerUid'] as String?) ?? joinedSnap.docs.first.id;
        final plan = (jData['planId'] as String?) ?? joinedSnap.docs.first.id;
        final planDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(owner)
            .collection('qurbaniPlans')
            .doc(plan)
            .get();
        if (planDoc.exists) {
          await _persist(owner, plan);
          return QurbaniRepository._(owner, plan);
        }
      }
    } catch (e) {
      debugPrint("Error checking joinedQurbaniPlans subcollection: $e");
    }

    // ── Step 3: Check direct owned plan under users/{uid}/qurbaniPlans ──────
    try {
      final ownedSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('qurbaniPlans')
          .limit(1)
          .get();
      if (ownedSnap.docs.isNotEmpty) {
        final planDoc = ownedSnap.docs.first;
        await _persist(uid, planDoc.id);
        return QurbaniRepository._(uid, planDoc.id);
      }
    } catch (e) {
      debugPrint("Error checking owned plans: $e");
    }

    // ── Step 4: Check local cache as fallback ──────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    final savedOwner = prefs.getString(_prefsOwnerKey());
    final savedPlan = prefs.getString(_prefsPlanKey());
    if (savedOwner != null && savedPlan != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(savedOwner)
            .collection('qurbaniPlans')
            .doc(savedPlan)
            .get();
        if (doc.exists) {
          await _persist(savedOwner, savedPlan);
          return QurbaniRepository._(savedOwner, savedPlan);
        }
      } catch (_) {}
    }

    // ── Step 5: Global collectionGroup query (memberIds array) ─────────────
    try {
      final memberSnap = await FirebaseFirestore.instance
          .collectionGroup('qurbaniPlans')
          .where('memberIds', arrayContains: uid)
          .limit(1)
          .get();
      if (memberSnap.docs.isNotEmpty) {
        final planDoc = memberSnap.docs.first;
        final ownerUid = planDoc.reference.parent.parent!.id;
        await _persist(ownerUid, planDoc.id);
        return QurbaniRepository._(ownerUid, planDoc.id);
      }
    } catch (e) {
      debugPrint("Error in collectionGroup memberIds query: $e");
    }

    // ── Step 6: Global collectionGroup participants / members ──────────────
    try {
      final participantSubSnap = await FirebaseFirestore.instance
          .collectionGroup('participants')
          .where(FieldPath.documentId, isEqualTo: uid)
          .limit(1)
          .get();
      if (participantSubSnap.docs.isNotEmpty) {
        final partRef = participantSubSnap.docs.first.reference;
        final planRef = partRef.parent.parent!;
        final ownerUid = planRef.parent.parent!.id;
        final planId = planRef.id;

        // Self heal memberIds
        try {
          await planRef.update({
            'memberIds': FieldValue.arrayUnion([uid]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}

        await _persist(ownerUid, planId);
        return QurbaniRepository._(ownerUid, planId);
      }
    } catch (e) {
      debugPrint("Error in collectionGroup participants query: $e");
    }

    return null;
  }

  static Stream<List<QPlanSummary>> watchUserPlans() {
    final uid = currentUid();
    // Watch plans where memberIds contains uid (joined groups),
    // then merge with the user's own plans (by ownerId) for a complete list
    final memberStream = FirebaseFirestore.instance
        .collectionGroup('qurbaniPlans')
        .where('memberIds', arrayContains: uid)
        .snapshots();
    return memberStream.asyncMap((snap) async {
      final ownedSnap = await FirebaseFirestore.instance
          .collectionGroup('qurbaniPlans')
          .where('ownerId', isEqualTo: uid)
          .get();
      // Deduplicate by planId using a Map
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = {};
      for (final d in snap.docs) {
        allDocs[d.id] = d;
      }
      for (final d in ownedSnap.docs) {
        allDocs[d.id] = d;
      }
      return allDocs.values.map((doc) {
        final ownerUid = doc.reference.parent.parent!.id;
        final data = doc.data();
        return QPlanSummary(
          ownerUid: ownerUid,
          planId: doc.id,
          ownerName: data['ownerName'] ?? 'Qurbani Group',
          animalType: data['animalType'] ?? 'cow',
          totalShares: (data['totalShares'] ?? 7) as int,
          isOwner: ownerUid == uid,
        );
      }).toList();
    });
  }

  static Future<void> switchGroup(String ownerUid, String planId) async {
    await _persist(ownerUid, planId);
  }

  static Future<QurbaniRepository> _createNewPlan() async {
    final uid = currentUid();
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('qurbaniPlans').doc();
    final now = FieldValue.serverTimestamp();
    final avatarBase64 = await currentAvatarBase64();
    await docRef.set({
      'year': DateTime.now().year,
      'status': 'planned',
      'animalType': 'cow',
      'totalShares': 7,
      'myShares': 1,
      'estimatedCost': 0.0,
      'paidAmount': 0.0,
      'vendorName': null,
      'vendorPhone': null,
      'slaughterDate': null,
      'notes': null,
      'ownerId': uid,
      'ownerName': currentDisplayName(),
      'memberIds': [uid],
      'createdAt': now,
      'updatedAt': now,
    });
    await docRef.collection('members').doc(uid).set({
      'name': currentDisplayName(),
      'shares': 1,
      'photoUrl': currentPhotoUrl(),
      'avatarBase64': avatarBase64,
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await docRef.collection('participants').doc(uid).set({
      'name': currentDisplayName(),
      'phone': null,
      'shares': 1,
      'amountDue': 0.0,
      'amountPaid': 0.0,
      'paymentStatus': 'unpaid',
      'ownerId': uid,
      'ownerName': currentDisplayName(),
      'photoUrl': currentPhotoUrl(),
      'avatarBase64': avatarBase64,
      'isDeenMateUser': true,
      'uid': uid,
    });
    await _persist(uid, docRef.id);
    final repository = QurbaniRepository._(uid, docRef.id);
    try {
      await repository.createInviteCode();
    } catch (_) {}
    return repository;
  }

  static Future<void> _persist(String ownerUid, String planId) async {
    final uid = currentUid();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsOwnerKey(), ownerUid);
      await prefs.setString(_prefsPlanKey(), planId);
    } catch (_) {}

    if (uid != 'local_device') {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'activeQurbaniPlan': {
            'ownerUid': ownerUid,
            'planId': planId,
            'updatedAt': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('joinedQurbaniPlans')
            .doc(planId)
            .set({
          'ownerUid': ownerUid,
          'planId': planId,
          'isOwner': ownerUid == uid,
          'joinedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error persisting activeQurbaniPlan to Firestore: $e");
      }
    }
  }

  Future<String> createInviteCode() async {
    if (ownerUid != currentUid()) {
      throw StateError('Only the group owner can generate a code.');
    }
    final existingCode = await getInviteCode();
    if (existingCode != null) return existingCode;
    final code = await _newUnusedInviteCode();
    await FirebaseFirestore.instance.collection('qurbaniPlanInvites').doc(code).set({
      'ownerUid': ownerUid,
      'planId': planId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await planRef.update({
      'inviteCode': code,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  static Future<void> _clearPersistedPlan() async {
    final uid = currentUid();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsOwnerKey());
      await prefs.remove(_prefsPlanKey());
    } catch (_) {}

    if (uid != 'local_device') {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'activeQurbaniPlan': FieldValue.delete(),
        });
      } catch (_) {}
    }
  }

  static Future<QurbaniRepository> createGroup() => _createNewPlan();

  Future<String?> getInviteCode() async {
    final value = (await planRef.get()).data()?['inviteCode'];
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<String> getAnimalType() async {
    final snap = await planRef.get();
    return (snap.data()?['animalType'] as String?) ?? 'cow';
  }

  Future<int> getTotalShares() async {
    final snap = await planRef.get();
    return (snap.data()?['totalShares'] as num?)?.toInt() ?? 7;
  }

  Future<void> leaveGroup() async {
    if (ownerUid == currentUid()) {
      throw StateError('The owner must delete the group instead of leaving it.');
    }
    final uid = currentUid();
    try {
      await planRef.collection('members').doc(uid).delete();
    } catch (_) {}
    try {
      await planRef.collection('participants').doc(uid).delete();
    } catch (_) {}
    try {
      await planRef.update({
        'memberIds': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    await _clearPersistedPlan();
  }

  Future<void> deleteGroup() async {
    if (ownerUid != currentUid()) {
      throw StateError('Only the group owner can delete this group.');
    }
    final code = await getInviteCode();
    if (code != null) {
      try {
        await FirebaseFirestore.instance.collection('qurbaniPlanInvites').doc(code).delete();
      } catch (_) {}
    }
    await planRef.delete();
    await _clearPersistedPlan();
  }

  static Future<String> _newUnusedInviteCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = math.Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final suffix = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
      final code = 'QRB-$suffix';
      final existing = await FirebaseFirestore.instance.collection('qurbaniPlanInvites').doc(code).get();
      if (!existing.exists) return code;
    }
    throw StateError('Could not create a unique invite code. Please try again.');
  }

  Future<void> joinCurrentUserWithShares(int shares) async {
    final uid = currentUid();
    final name = currentDisplayName();
    final avatarBase64 = await currentAvatarBase64();

    // Check cap
    final pSnap = await participantsRef.get();
    final otherTotal = pSnap.docs.fold<int>(0, (sum, d) {
      if (d.id == uid) return sum;
      return sum + ((d.data()['shares'] as num?)?.toInt() ?? 0);
    });
    await _validateShareCap(otherTotal + shares);

    await planRef.collection('members').doc(uid).set({
      'name': name,
      'shares': shares,
      'photoUrl': currentPhotoUrl(),
      'avatarBase64': avatarBase64,
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await participantsRef.doc(uid).set({
      'name': name,
      'phone': null,
      'shares': shares,
      'amountDue': 0.0,
      'amountPaid': 0.0,
      'paymentStatus': 'unpaid',
      'ownerId': uid,
      'ownerName': name,
      'photoUrl': currentPhotoUrl(),
      'avatarBase64': avatarBase64,
      'isDeenMateUser': true,
      'uid': uid,
    }, SetOptions(merge: true));

    // Ensure memberIds array has uid
    try {
      await planRef.update({
        'memberIds': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    await recalcAndSyncBalances();

    // If total shares reach cap, close any linked share post
    try {
      final updatedSnap = await participantsRef.get();
      final newTotal = updatedSnap.docs.fold<int>(0, (sum, d) => sum + ((d.data()['shares'] as num?)?.toInt() ?? 0));
      final planSnap = await planRef.get();
      final animalType = (planSnap.data()?['animalType'] as String?) ?? 'cow';
      final cap = _animalShareCaps[animalType] ?? 7;
      if (newTotal >= cap) {
        final postSnaps = await FirebaseFirestore.instance
            .collection('qurbaniSharePosts')
            .where('planId', isEqualTo: planId)
            .get();
        for (final pDoc in postSnaps.docs) {
          await pDoc.reference.update({'availableShares': 0, 'status': 'closed'});
        }
      }
    } catch (_) {}
  }

  Future<void> updateOwnShares(int shares) => joinCurrentUserWithShares(shares);

  Future<void> forgetLocally() => _clearPersistedPlan();

  /// Syncs the signed-in user's latest avatar and name from profile cache / Firestore
  /// to their participant and member records in the current group.
  Future<void> syncCurrentUserProfile() async {
    try {
      final uid = currentUid();
      if (uid == 'local_device') return;
      final name = currentDisplayName();
      final photoUrl = currentPhotoUrl();
      final avatarBase64 = await currentAvatarBase64();

      final memberDoc = planRef.collection('members').doc(uid);
      final mSnap = await memberDoc.get();
      if (mSnap.exists) {
        await memberDoc.update({
          if (name.isNotEmpty) 'name': name,
          'photoUrl': photoUrl,
          'avatarBase64': avatarBase64,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final participantDoc = participantsRef.doc(uid);
      final pSnap = await participantDoc.get();
      if (pSnap.exists) {
        await participantDoc.update({
          if (name.isNotEmpty) 'name': name,
          if (name.isNotEmpty) 'ownerName': name,
          'photoUrl': photoUrl,
          'avatarBase64': avatarBase64,
        });
      }
    } catch (e) {
      debugPrint("Error syncing profile to Qurbani group: $e");
    }
  }

  static Future<QurbaniRepository> joinByCode(String code, int shares) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      throw Exception('Enter an invite code first');
    }
    final inviteDoc = await FirebaseFirestore.instance.collection('qurbaniPlanInvites').doc(trimmed).get();
    if (!inviteDoc.exists) {
      throw Exception('Invite code not found');
    }
    final data = inviteDoc.data()!;
    final targetOwner = data['ownerUid'] as String;
    final targetPlan = data['planId'] as String;

    final repository = QurbaniRepository._(targetOwner, targetPlan);

    // Validate share cap before joining
    final pSnap = await repository.participantsRef.get();
    final uid = currentUid();
    final otherTotal = pSnap.docs.fold<int>(0, (sum, d) {
      if (d.id == uid) return sum;
      return sum + ((d.data()['shares'] as num?)?.toInt() ?? 0);
    });

    final planDoc = await repository.planRef.get();
    if (!planDoc.exists) {
      throw Exception('The requested Qurbani group no longer exists.');
    }
    final animalType = (planDoc.data()?['animalType'] as String?) ?? 'cow';
    final cap = _animalShareCaps[animalType] ?? 7;
    final remaining = cap - otherTotal;

    if (remaining <= 0) {
      throw Exception('Sorry, shares are already complete in this group (All $cap shares filled).');
    }
    if (shares > remaining) {
      throw Exception('Cannot join with $shares shares. Only $remaining share${remaining > 1 ? "s" : ""} available for this $animalType (Maximum $cap shares).');
    }

    await repository.joinCurrentUserWithShares(shares);
    await _persist(targetOwner, targetPlan);
    return repository;
  }

  DocumentReference<Map<String, dynamic>> get planRef =>
      FirebaseFirestore.instance.collection('users').doc(ownerUid).collection('qurbaniPlans').doc(planId);

  CollectionReference<Map<String, dynamic>> get participantsRef => planRef.collection('participants');
  CollectionReference<Map<String, dynamic>> get expensesRef => planRef.collection('expenses');
  CollectionReference<Map<String, dynamic>> get editRequestsRef => planRef.collection('editRequests');
  CollectionReference<Map<String, dynamic>> get settlementsRef => planRef.collection('settlements');
  CollectionReference<Map<String, dynamic>> get checklistRef => planRef.collection('checklist');
  CollectionReference<Map<String, dynamic>> get distributionsRef => planRef.collection('distributions');
  CollectionReference<Map<String, dynamic>> get messagesRef => planRef.collection('messages');

  static String currentUid() => FirebaseAuth.instance.currentUser?.uid ?? 'local_device';
  static String currentDisplayName() =>
      FirebaseAuth.instance.currentUser?.displayName ??
      FirebaseAuth.instance.currentUser?.email?.split('@').first ??
      'Me';
  static String? currentPhotoUrl() => FirebaseAuth.instance.currentUser?.photoURL;

  static const _animalShareCaps = <String, int>{'cow': 7, 'buffalo': 7, 'camel': 7, 'goat': 1};

  Stream<List<QParticipant>> watchParticipants() =>
      participantsRef.orderBy('name').snapshots().map((s) => s.docs.map(QParticipant.fromDoc).toList());

  Stream<List<QPlanMember>> watchMembers() =>
      planRef.collection('members').orderBy('name').snapshots().map((s) => s.docs.map(QPlanMember.fromDoc).toList());

  Stream<List<QExpense>> watchExpenses() =>
      expensesRef.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(QExpense.fromDoc).toList());

  Stream<List<QEditRequest>> watchEditRequests() =>
      editRequestsRef.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(QEditRequest.fromDoc).toList());

  Stream<List<QSettlement>> watchSettlements() =>
      settlementsRef.orderBy('date', descending: true).snapshots().map((s) => s.docs.map(QSettlement.fromDoc).toList());

  CollectionReference<Map<String, dynamic>> get yearlyArchiveRef =>
      planRef.collection('yearlyArchive');

  Stream<List<Map<String, dynamic>>> watchYearlyArchive() {
    return yearlyArchiveRef.orderBy('year', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  Future<void> archiveCurrentYear({
    required int year,
    required double totalCost,
    required String animalType,
    required int totalShares,
    required double costPerShare,
    required List<QExpense> expenses,
  }) async {
    final expData = expenses
        .map((e) => {
              'category': e.category,
              'amount': e.amount,
              'notes': e.notes,
            })
        .toList();

    await yearlyArchiveRef.doc(year.toString()).set({
      'year': year,
      'animalType': animalType,
      'totalShares': totalShares,
      'totalCost': totalCost,
      'costPerShare': costPerShare,
      'expenses': expData,
      'archivedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<QChatMessage>> watchMessages() =>
      messagesRef.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(QChatMessage.fromDoc).toList());

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final avatarBase64 = await currentAvatarBase64();
    await messagesRef.add({
      'senderId': currentUid(),
      'senderName': currentDisplayName(),
      'photoUrl': currentPhotoUrl(),
      'avatarBase64': avatarBase64,
      'text': text.trim(),
      'mediaType': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendMediaMessage({
    required String mediaType,
    required String mediaData,
    String? text,
    String? fileName,
  }) async {
    final avatarBase64 = await currentAvatarBase64();
    await messagesRef.add({
      'senderId': currentUid(),
      'senderName': currentDisplayName(),
      'photoUrl': currentPhotoUrl(),
      'avatarBase64': avatarBase64,
      'text': (text ?? '').trim(),
      'mediaType': mediaType,
      'mediaData': mediaData,
      'fileName': fileName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addParticipantUser({
    required String name,
    required int shares,
    String? phone,
    String? photoUrl,
    String? avatarBase64,
    bool isDeenMateUser = false,
    String? uid,
  }) async {
    final currentTotal = await participantsRef.get().then((s) => s.docs.fold<int>(0, (sum, d) => sum + ((d.data()['shares'] as num?)?.toInt() ?? 0)));
    await _validateShareCap(currentTotal + shares);
    final pUid = (uid != null && uid.isNotEmpty) ? uid : participantsRef.doc().id;
    await participantsRef.doc(pUid).set({
      'name': name,
      'phone': phone,
      'shares': shares,
      'amountDue': 0.0,
      'amountPaid': 0.0,
      'paymentStatus': 'unpaid',
      'ownerId': currentUid(),
      'ownerName': currentDisplayName(),
      'photoUrl': photoUrl,
      'avatarBase64': avatarBase64,
      'isDeenMateUser': isDeenMateUser,
      'uid': uid,
    });
    if (isDeenMateUser && uid != null && uid.isNotEmpty) {
      try {
        await planRef.collection('members').doc(uid).set({
          'name': name,
          'shares': shares,
          'photoUrl': photoUrl,
          'avatarBase64': avatarBase64,
          'joinedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Could not write member doc: $e');
      }
      try {
        await planRef.update({
          'memberIds': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Could not update memberIds array: $e');
      }
    }
    await recalcAndSyncBalances();
  }

  Future<void> addParticipant(String name, int shares, {String? phone}) =>
      addParticipantUser(name: name, shares: shares, phone: phone);

  Future<void> _validateShareCap(int proposedTotal) async {
    final planSnap = await planRef.get();
    final planData = planSnap.data() ?? {};
    final animalType = planData['animalType'] as String? ?? 'cow';
    final cap = _animalShareCaps[animalType] ?? 7;
    if (proposedTotal > cap) {
      throw Exception('Total shares ($proposedTotal) would exceed the $cap-share cap for a $animalType.');
    }
  }

  Future<void> updateParticipantDirect(String id, {String? name, int? shares}) async {
    if (shares != null) {
      final existing = await participantsRef.doc(id).get();
      final oldShares = (existing.data()?['shares'] as num?)?.toInt() ?? 0;
      final currentTotal = await participantsRef.get().then((s) => s.docs.fold<int>(0, (sum, d) => sum + ((d.data()['shares'] as num?)?.toInt() ?? 0)));
      await _validateShareCap(currentTotal - oldShares + shares);
    }
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (shares != null) data['shares'] = shares;
    await participantsRef.doc(id).update(data);
    await recalcAndSyncBalances();
  }

  Future<void> deleteParticipant(String id) async {
    await participantsRef.doc(id).delete();
    await recalcAndSyncBalances();
  }

  Future<void> addExpense({
    required String category,
    required double amount,
    required String notes,
    required List<QPayer> payers,
  }) async {
    final avatarBase64 = await currentAvatarBase64();
    await expensesRef.add(
      QExpense(
        id: '',
        category: category,
        amount: amount,
        notes: notes,
        payers: payers,
        ownerId: currentUid(),
        ownerName: currentDisplayName(),
        photoUrl: currentPhotoUrl(),
        avatarBase64: avatarBase64,
        createdAt: DateTime.now(),
      ).toMap(),
    );
    await recalcAndSyncBalances();
  }

  Future<void> deleteExpense(String id) async {
    await expensesRef.doc(id).delete();
    await recalcAndSyncBalances();
  }

  Future<void> submitEditRequest({
    required QEditTargetType type,
    required String targetId,
    required String targetLabel,
    required String reason,
    required Map<String, dynamic> proposedChanges,
  }) async {
    final ref = type == QEditTargetType.participant ? participantsRef.doc(targetId) : expensesRef.doc(targetId);
    final targetOwnerId = (await ref.get()).data()?['ownerId'] as String? ?? '';
    await editRequestsRef.add(
      QEditRequest(
        id: '',
        targetType: type,
        targetId: targetId,
        targetLabel: targetLabel,
        targetOwnerId: targetOwnerId,
        requestedById: currentUid(),
        requestedByName: currentDisplayName(),
        reason: reason,
        proposedChanges: proposedChanges,
        status: 'pending',
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  Future<void> approveEditRequest(QEditRequest req) async {
    if (req.targetType == QEditTargetType.participant && req.proposedChanges['shares'] != null) {
      final newShares = req.proposedChanges['shares'] as int;
      final existing = await participantsRef.doc(req.targetId).get();
      final oldShares = (existing.data()?['shares'] as num?)?.toInt() ?? 0;
      final currentTotal = await participantsRef.get().then((s) => s.docs.fold<int>(0, (sum, d) => sum + ((d.data()['shares'] as num?)?.toInt() ?? 0)));
      await _validateShareCap(currentTotal - oldShares + newShares);
    }
    if (req.targetType == QEditTargetType.participant) {
      await participantsRef.doc(req.targetId).update(req.proposedChanges);
    } else {
      await expensesRef.doc(req.targetId).update(req.proposedChanges);
    }
    await editRequestsRef.doc(req.id).update({'status': 'approved'});
    await recalcAndSyncBalances();
  }

  Future<void> rejectEditRequest(String id) => editRequestsRef.doc(id).update({'status': 'rejected'});

  Future<void> deleteEditRequest(String id) => editRequestsRef.doc(id).delete();

  Future<void> deleteMessage(String id) => messagesRef.doc(id).delete();

  Future<void> editMessage(String id, String newText) =>
      messagesRef.doc(id).update({'text': newText, 'edited': true});

  Future<void> recordSettlement({
    required QParticipant from,
    required QParticipant to,
    required double amount,
    bool confirmed = false,
  }) async {
    await settlementsRef.add(
      QSettlement(
        id: '',
        fromId: from.id,
        fromName: from.name,
        toId: to.id,
        toName: to.name,
        amount: amount,
        confirmed: confirmed,
        date: DateTime.now(),
      ).toMap(),
    );
    await recalcAndSyncBalances();
  }

  Future<void> confirmSettlement(String settlementId) async {
    await settlementsRef.doc(settlementId).update({'confirmed': true});
    await recalcAndSyncBalances();
  }

  Future<void> disputeSettlement(String settlementId, bool confirmed) async {
    if (!confirmed) {
      await settlementsRef.doc(settlementId).delete();
      await recalcAndSyncBalances();
    }
  }

  Future<void> recalcAndSyncBalances() async {
    final pSnap = await participantsRef.get();
    final eSnap = await expensesRef.get();
    final sSnap = await settlementsRef.get();
    final participants = pSnap.docs.map(QParticipant.fromDoc).toList();
    final expenses = eSnap.docs.map(QExpense.fromDoc).toList();
    final settlements = sSnap.docs.map(QSettlement.fromDoc).toList();
    final balances = SettlementEngine.computeBalances(participants: participants, expenses: expenses, settlements: settlements);
    await syncParticipantBalances(balances);
  }

  Future<void> setChecklistDone(String itemId, bool done) =>
      checklistRef.doc(itemId).set({'done': done}, SetOptions(merge: true));

  Stream<Map<String, bool>> watchChecklistState() =>
      checklistRef.snapshots().map((s) => {for (final d in s.docs) d.id: (d.data()['done'] ?? false) as bool});

  Future<void> syncParticipantBalances(List<QBalanceRow> balances) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final b in balances) {
      final status = b.totalPaid <= 0
          ? 'unpaid'
          : (b.totalPaid >= b.shareOfCost ? 'paid' : 'partial');
      batch.update(participantsRef.doc(b.participant.id), {
        'amountDue': b.shareOfCost,
        'amountPaid': b.totalPaid,
        'paymentStatus': status,
      });
    }
    await batch.commit();
  }
}

// =============================================================================
// LOCATION SHARE BOARD REPOSITORY
// =============================================================================
class QShareBoardRepository {
  static CollectionReference<Map<String, dynamic>> get postsRef =>
      FirebaseFirestore.instance.collection('qurbaniSharePosts');

  static Stream<List<QurbaniSharePost>> watchPosts() {
    return postsRef.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((doc) => QurbaniSharePost.fromDoc(doc)).toList(),
        );
  }

  static Future<void> createPost({
    required String animalType,
    required int totalShares,
    required int availableShares,
    required double costPerShare,
    required String locationName,
    required double latitude,
    required double longitude,
    required String description,
    String? planId,
    String? planOwnerUid,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'local_device';
    final name = QurbaniRepository.currentDisplayName();
    final photoUrl = QurbaniRepository.currentPhotoUrl();
    final avatarBase64 = await QurbaniRepository.currentAvatarBase64();

    await postsRef.add({
      'posterUid': uid,
      'posterName': name,
      'photoUrl': photoUrl,
      'avatarBase64': avatarBase64,
      'animalType': animalType,
      'totalShares': totalShares,
      'availableShares': availableShares,
      'costPerShare': costPerShare,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'status': 'active',
      'planId': planId,
      'planOwnerUid': planOwnerUid ?? uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<QShareResponse>> watchResponses(String postId) {
    return postsRef.doc(postId).collection('responses').orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((doc) => QShareResponse.fromDoc(doc)).toList(),
        );
  }

  static Future<void> respondToPost({
    required String postId,
    required int sharesRequested,
    required String note,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'local_device';

    // Verify post is active and has enough available shares
    final postDoc = await postsRef.doc(postId).get();
    if (!postDoc.exists) {
      throw Exception('This post no longer exists.');
    }
    final postData = postDoc.data() ?? {};
    final status = postData['status'] as String? ?? 'active';
    final available = (postData['availableShares'] as num?)?.toInt() ?? 0;

    if (status == 'closed' || status == 'matched' || available <= 0) {
      throw Exception('Sorry, share is complete in this group.');
    }
    if (sharesRequested > available) {
      throw Exception('Only $available share${available > 1 ? "s" : ""} available in this group.');
    }

    // Server-side duplicate guard: check if user already responded to this post
    final existing = await postsRef
        .doc(postId)
        .collection('responses')
        .where('responderUid', isEqualTo: uid)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('You have already responded to this post.');
    }

    final name = QurbaniRepository.currentDisplayName();
    final photoUrl = QurbaniRepository.currentPhotoUrl();
    final avatarBase64 = await QurbaniRepository.currentAvatarBase64();

    await postsRef.doc(postId).collection('responses').add({
      'postId': postId,
      'responderUid': uid,
      'responderName': name,
      'photoUrl': photoUrl,
      'avatarBase64': avatarBase64,
      'sharesRequested': sharesRequested,
      'note': note,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Rejects a response with a specific reason provided by the poster.
  static Future<void> rejectResponse({
    required String postId,
    required String responseId,
    required String reason,
  }) async {
    await postsRef.doc(postId).collection('responses').doc(responseId).update({
      'status': 'rejected',
      'rejectReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a post and all its responses. Only the poster should call this.
  static Future<void> deletePost(String postId) async {
    // Delete all responses first
    final responsesSnap = await postsRef.doc(postId).collection('responses').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in responsesSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(postsRef.doc(postId));
    await batch.commit();
  }

  /// Accepts a response and sends the specified group invite code to the responder.
  /// The responder can then join via the code — this preserves the poster's existing group.
  static Future<void> acceptAndSendCode({
    required QurbaniSharePost post,
    required QShareResponse response,
    required String inviteCode,
  }) async {
    // Mark the response as accepted and store the invite code on the response doc
    // so the responder can see it on their side
    await postsRef.doc(post.id).collection('responses').doc(response.id).update({
      'status': 'accepted',
      'inviteCode': inviteCode,
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // Update available shares on the post
    final remaining = math.max(0, post.availableShares - response.sharesRequested);
    if (remaining <= 0) {
      // Mark all other pending responses as 'filled'
      try {
        final allResponses = await postsRef.doc(post.id).collection('responses').get();
        for (final doc in allResponses.docs) {
          if (doc.id != response.id && doc.data()['status'] == 'pending') {
            await doc.reference.update({'status': 'filled'});
          }
        }
      } catch (_) {}
      await postsRef.doc(post.id).update({'availableShares': 0, 'status': 'closed'});
    } else {
      await postsRef.doc(post.id).update({'availableShares': remaining, 'status': 'active'});
    }
  }

  /// Marks a response as 'joined' after member joins the group, and closes the post if all shares filled.
  static Future<void> markResponseJoined(String postId, String responseId) async {
    try {
      await postsRef.doc(postId).collection('responses').doc(responseId).update({
        'status': 'joined',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      final postSnap = await postsRef.doc(postId).get();
      final avail = (postSnap.data()?['availableShares'] ?? 0) as int;
      if (avail <= 0) {
        await postsRef.doc(postId).update({'status': 'closed'});
      }
    } catch (e) {
      debugPrint("Error marking response joined: $e");
    }
  }
}

// =============================================================================
// STATIC CONTENT — Activities Checklist items & Rules/Verses
// =============================================================================

class ChecklistItem {
  final String id;
  final String title;
  final String section; // 'before' | 'day' | 'after'
  const ChecklistItem(this.id, this.title, this.section);
}

const List<ChecklistItem> kQurbaniChecklist = [
  // Before Eid al-Adha
  ChecklistItem('before_eligibility', "Confirm eligibility using the Eligibility Guide", 'before'),
  ChecklistItem('before_animal_type', "Decide animal type and how many shares are needed", 'before'),
  ChecklistItem('before_select_animal', "Select and reserve a healthy animal free of visible defects", 'before'),
  ChecklistItem('before_min_age', "Confirm the animal meets the minimum age for its type", 'before'),
  ChecklistItem('before_butcher', "Arrange a trustworthy butcher or slaughter facility", 'before'),
  ChecklistItem('before_agree_shares', "Agree shares and cost-per-share with co-sharers in this planner", 'before'),
  ChecklistItem('before_log_contrib', "Collect / log every participant's contribution in the Expenses tab", 'before'),
  ChecklistItem('before_hair_nails', "If you personally intend to sacrifice and are within the first 10 days of Dhul Hijjah, consider not cutting hair/nails until after", 'before'),

  // On the Day of Sacrifice (10-13 Dhul Hijjah)
  ChecklistItem('day_eid_prayer', "Attend Eid prayer before sacrificing on day one", 'day'),
  ChecklistItem('day_gentle_water', "Treat the animal gently and give it water beforehand", 'day'),
  ChecklistItem('day_qibla', "Face the animal towards the Qibla where possible", 'day'),
  ChecklistItem('day_bismillah', "Say Bismillah, Allahu Akbar at the moment of slaughter", 'day'),
  ChecklistItem('day_swift_slaughter', "Ensure a swift, sharp-blade slaughter by a competent person", 'day'),
  ChecklistItem('day_divide_meat', "Divide the meat: roughly a third to eat, a third to gift, a third to charity", 'day'),
  ChecklistItem('day_distribute', "Distribute meat to relatives, neighbours, and those in need", 'day'),

  // After the Sacrifice
  ChecklistItem('after_settle', "Settle all outstanding shares and payments among participants", 'after'),
  ChecklistItem('after_confirm_cost', "Confirm final total cost and per-share amount in this app", 'after'),
  ChecklistItem('after_reflect', "Reflect on the meaning of the sacrifice and give thanks", 'after'),
  ChecklistItem('after_clean', "Clean and tidy the slaughter site", 'after'),
];

const _sectionTitles = {
  'before': 'Before Eid al-Adha',
  'day': 'On the Day of Sacrifice (10–13 Dhul Hijjah)',
  'after': 'After the Sacrifice',
};

class VerseEntry {
  final String reference;
  final String text;
  const VerseEntry(this.reference, this.text);
}

const List<VerseEntry> kQuranVerses = [
  VerseEntry(
    'Surah Al-Kawthar — 108:1-2',
    "Allah tells the Prophet ﷺ that He has granted him abundant good, and instructs him to turn to his Lord in prayer and offer sacrifice in gratitude.",
  ),
  VerseEntry(
    'Surah Al-Hajj — 22:34',
    "For every community Allah appointed a rite of sacrifice, so that His name is pronounced over the livestock He has provided for them, as an act of gratitude to one God.",
  ),
  VerseEntry(
    'Surah Al-Hajj — 22:36-37',
    "The sacrificial camels and cattle are described as symbols of Allah in which there is much good for believers; neither their meat nor their blood reaches Allah — what reaches Him is the God-consciousness (taqwa) behind the act.",
  ),
  VerseEntry(
    'Surah As-Saffat — 37:102-107',
    "The story of Ibrahim (AS) being commanded in a vision to sacrifice his son, both submitting to Allah's command, and Allah ransoming the boy with a great sacrifice — understood by scholars as the historical origin of the Qurbani tradition.",
  ),
];

// =============================================================================
// MAIN WIDGET
// =============================================================================

class _Slice {
  final double fraction;
  final Color color;
  _Slice(this.fraction, this.color);
}

class _DistributionDonutPainter extends CustomPainter {
  final List<_Slice> slices;
  final bool isDarkMode;
  _DistributionDonutPainter(this.slices, {required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 22.0;
    final rect = Rect.fromCircle(center: center, radius: math.max(0, radius - strokeWidth / 2));
    var startAngle = -math.pi / 2;

    for (final s in slices) {
      final sweep = s.fraction * 2 * math.pi;
      if (sweep <= 0) continue;

      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweep, false, paint);

      final borderPaint = Paint()
        ..color = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawArc(rect, startAngle, sweep, false, borderPaint);

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DistributionDonutPainter oldDelegate) => true;
}

class _DistributionPiePainter extends CustomPainter {
  final List<_Slice> slices;
  _DistributionPiePainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    var startAngle = -math.pi / 2;

    for (final s in slices) {
      final sweep = s.fraction * 2 * math.pi;
      if (sweep <= 0) continue;

      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweep, true, paint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(rect, startAngle, sweep, true, borderPaint);

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DistributionPiePainter oldDelegate) => true;
}

class QurbaniPlannerSheet extends StatefulWidget {
  final ScrollController scrollController;
  final bool isPage;
  const QurbaniPlannerSheet({super.key, required this.scrollController, this.isPage = false});

  @override
  State<QurbaniPlannerSheet> createState() => _QurbaniPlannerSheetState();
}

class _QurbaniPlannerSheetState extends State<QurbaniPlannerSheet> {
  int _tab = 0;
  static const _tabLabels = ['Eligibility', 'Calculators', 'Shares', 'Share Board', 'Distribution', 'Tasks'];
  static const _tabIcons = [
    Icons.check_circle_rounded,
    Icons.calculate_rounded,
    Icons.people_alt_rounded,
    Icons.storefront_rounded,
    Icons.restaurant_menu_rounded,
    Icons.task_rounded,
  ];

  bool _isDarkMode = false;
  QurbaniRepository? _repo;
  String? _repositoryError;
  bool _isLoadingRepo = false;

  // Registered User Search
  List<Map<String, dynamic>> _userSearchResults = [];
  bool _isSearchingUsers = false;
  Map<String, dynamic>? _selectedDeenMateUser;
  bool _isOfflineFamilyMember = false;

  // Real-time Chat & Media Playback
  final TextEditingController _chatMsgCtrl = TextEditingController();
  String? _editingMessageId;
  String? _myCurrentAvatarBase64;
  Map<String, String> _membersAvatarCache = {};

  // Location Share Board
  Position? _currentUserPosition;
  bool _isGettingLocation = false;
  double _selectedMaxDistanceKm = 25.0; // 5, 10, 25, 50, 9999 (All)


  // Eligibility
  final TextEditingController _savingsCtrl = TextEditingController(text: '0');
  final TextEditingController _metalsCtrl = TextEditingController(text: '0');
  final TextEditingController _cashCtrl = TextEditingController(text: '0');
  final TextEditingController _debtsCtrl = TextEditingController(text: '0');
  bool _hasCheckedEligibility = false;
  bool _isEligible = false;
  double _netAssets = 0.0;
  String _eligibilityReason = '';
  double _zakatNetWealth = 0.0;
  double _zakatNisabLimit = 115000.0;
  bool _hasZakatData = false;

  // Calculators
  String _selectedAnimal = 'Cow';
  String _selectedLocation = 'Dhaka';
  int _selectedShares = 1;
  double _estimatedCost = 0.0;
  String _aqiqahBabyGender = 'Boy';
  int _aqiqahQuantity = 2;
  double _aqiqahEstimatedCost = 0.0;
  final List<Map<String, dynamic>> _aqiqahChecklist = [
    {
      'title': "Name baby on 7th day",
      'rule': "It is Sunnah to give the baby a meaningful Islamic name on the 7th day after birth.",
      'done': false
    },
    {
      'title': "Shave baby's hair & give charity in silver weight equivalent",
      'rule': "Shaving the baby's head on the 7th day is a recommended Sunnah. The hair should be weighed and its equivalent value in silver (or cash) should be given as charity (Sadaqah) to the poor.",
      'done': false
    },
    {
      'title': "Purchase Aqiqah animals",
      'rule': "Sacrifice 2 goats/sheep for a baby boy and 1 goat/sheep for a baby girl. The animals must be of equal quality and meet standard health conditions (defect-free, 1+ years old).",
      'done': false
    },
    {
      'title': "Arrange food/distribution of meat",
      'rule': "Unlike Qurbani, it is recommended to cook the Aqiqah meat and invite relatives, friends, and the needy to a feast. Distributing raw meat is also permissible.",
      'done': false
    },
  ];

  // Distribution
  double _totalMeatKg = 30.0;

  // Reminders
  final Map<String, bool> _activeReminders = {
    'Eid': false,
    'Payment': false,
    'Collection': false,
    'Distribution': false,
    'Eligibility': false,
  };

  // Shares sub-tabs: 0 Participants, 1 Expenses, 2 Settlements, 3 Requests, 4 Chat
  int _sharesSubTab = 0;
  // Tasks sub-tabs: 0 Checklist, 1 Rules & Verses
  int _tasksSubTab = 0;
  // Local checklist state used when no group/repo is active
  final Map<String, bool> _localChecklistState = {};

  final TextEditingController _participantNameCtrl = TextEditingController();
  int _newParticipantShares = 1;
  final TextEditingController _expCategoryCtrl = TextEditingController();
  final TextEditingController _expAmountCtrl = TextEditingController();
  final TextEditingController _expNotesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadCurrentAvatar();
    _calculateCosts();
    _calculateAqiqahCosts();
    _loadRepository();
    _getCurrentLocation();
    _loadZakatWealthData();
  }

  Future<void> _getCurrentLocation() async {
    if (_isGettingLocation) return;
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      if (mounted) setState(() => _currentUserPosition = pos);
    } catch (e) {
      debugPrint("Error getting GPS location: $e");
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  /// Reverse geocodes lat/lng to a specific area name like "Mirpur 11" or "Banasree"
  /// using OpenStreetMap Nominatim (no API key needed).
  Future<String> _reverseGeocodeToArea(double lat, double lng) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1&accept-language=en');
      final response = await http.get(url, headers: {'User-Agent': 'DeenMate-App/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};
        String area = '';
        for (final key in ['neighbourhood', 'suburb', 'quarter', 'city_district', 'residential']) {
          if (address.containsKey(key) && address[key] != null) {
            area = address[key].toString();
            break;
          }
        }
        final city = address['city']?.toString() ?? address['town']?.toString() ?? address['county']?.toString() ?? '';
        if (area.isNotEmpty && city.isNotEmpty) return '$area, $city';
        if (area.isNotEmpty) return area;
        if (city.isNotEmpty) return city;
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    return '';
  }

  Future<void> _searchDeenMateUsers(String query) async {
    if (query.trim().length < 2) {
      setState(() => _userSearchResults = []);
      return;
    }
    setState(() => _isSearchingUsers = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .limit(20)
          .get();

      final results = <Map<String, dynamic>>[];
      final q = query.trim().toLowerCase();
      for (final doc in snap.docs) {
        final profile = doc.data()['profile'] as Map<String, dynamic>?;
        if (profile != null) {
          final name = (profile['fullName'] as String? ?? '').trim();
          final email = (profile['email'] as String? ?? '').trim();
          final phone = (profile['phone'] as String? ?? '').trim();
          if (name.toLowerCase().contains(q) || email.toLowerCase().contains(q) || phone.toLowerCase().contains(q)) {
            results.add({
              'uid': doc.id,
              'fullName': name,
              'email': email,
              'phone': phone,
              'photoUrl': profile['avatarPath'] ?? profile['photoUrl'],
              'avatarBase64': profile['avatarBase64'],
            });
          }
        }
      }
      if (mounted) setState(() => _userSearchResults = results);
    } catch (e) {
      debugPrint("Error searching users: $e");
    } finally {
      if (mounted) setState(() => _isSearchingUsers = false);
    }
  }

  Future<void> _loadRepository() async {
    setState(() {
      _isLoadingRepo = true;
      _repositoryError = null;
    });

    if (FirebaseAuth.instance.currentUser == null) {
      if (mounted) {
        setState(() {
          _repo = null;
          _isLoadingRepo = false;
          _repositoryError = 'Please sign in before using the Qurbani Planner.';
        });
      }
      return;
    }

    try {
      final repository = await QurbaniRepository.load();
      if (repository != null) {
        // Sync the latest profile avatar & name into the group
        repository.syncCurrentUserProfile();
      }
      if (mounted) {
        setState(() {
          _repo = repository;
          _isLoadingRepo = false;
        });
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() {
          _repo = null;
          _isLoadingRepo = false;
          _repositoryError = error.code == 'permission-denied'
              ? 'The Qurbani Planner is not permitted by Firestore yet. Deploy the updated Firestore rules, then try again.'
              : 'Could not load your Qurbani plan: ${error.message ?? error.code}';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _repo = null;
          _isLoadingRepo = false;
          _repositoryError = 'Could not load your Qurbani plan: $error';
        });
      }
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('is_dark_mode') ?? false);
  }

  @override
  void dispose() {
    _savingsCtrl.dispose();
    _metalsCtrl.dispose();
    _cashCtrl.dispose();
    _debtsCtrl.dispose();
    _participantNameCtrl.dispose();
    _expCategoryCtrl.dispose();
    _expAmountCtrl.dispose();
    _expNotesCtrl.dispose();
    super.dispose();
  }

  void _calculateCosts() {
    double basePrice = 0.0;
    if (_selectedAnimal == 'Cow') {
      basePrice = _selectedLocation == 'Dhaka' ? 18000.0 : (_selectedLocation == 'Chittagong' ? 20000.0 : 15500.0);
      _estimatedCost = basePrice * _selectedShares;
    } else if (_selectedAnimal == 'Goat') {
      basePrice = _selectedLocation == 'Dhaka' ? 28000.0 : (_selectedLocation == 'Chittagong' ? 30000.0 : 22000.0);
      _estimatedCost = basePrice;
    } else if (_selectedAnimal == 'Camel') {
      basePrice = _selectedLocation == 'Dhaka' ? 60000.0 : 50000.0;
      _estimatedCost = basePrice * _selectedShares;
    }
  }

  void _calculateAqiqahCosts() {
    double pricePerGoat =
        _selectedLocation == 'Dhaka' ? 25000.0 : (_selectedLocation == 'Chittagong' ? 27000.0 : 20000.0);
    _aqiqahEstimatedCost = pricePerGoat * _aqiqahQuantity;
  }

  void _checkEligibility() {
    if (_hasZakatData) {
      _loadZakatWealthData();
      return;
    }
    double savings = double.tryParse(_savingsCtrl.text) ?? 0.0;
    double metals = double.tryParse(_metalsCtrl.text) ?? 0.0;
    double cash = double.tryParse(_cashCtrl.text) ?? 0.0;
    double debts = double.tryParse(_debtsCtrl.text) ?? 0.0;
    _netAssets = savings + metals + cash - debts;
    const double nisabLimit = 115000.0;
    setState(() {
      _hasCheckedEligibility = true;
      _isEligible = _netAssets >= nisabLimit;
      _eligibilityReason = _isEligible
          ? 'Qurbani is WAJIB (mandatory) for you. Your net assets (৳${NumberFormat('#,##,###').format(_netAssets)}) exceed the Silver Nisab threshold of ৳${NumberFormat('#,##,###').format(nisabLimit)}.'
          : 'Qurbani is not mandatory for you. Your net assets (৳${NumberFormat('#,##,###').format(_netAssets)}) are below the Silver Nisab threshold of ৳${NumberFormat('#,##,###').format(nisabLimit)}. You can still perform it voluntarily.';
    });
  }

  Future<void> _loadZakatWealthData() async {
    final p = await SharedPreferences.getInstance();
    if (p.containsKey('zm_cash') || p.containsKey('zm_gold_24k') || p.containsKey('zm_custom_assets')) {
      final selectedCurrency = p.getString('zm_currency') ?? 'BDT';
      double toBDT = 1.0;
      if (selectedCurrency == 'USD') toBDT = 110.0;
      else if (selectedCurrency == 'SAR') toBDT = 29.3;
      else if (selectedCurrency == 'GBP') toBDT = 139.0;
      else if (selectedCurrency == 'EUR') toBDT = 118.0;
      else if (selectedCurrency == 'AED') toBDT = 30.0;
      else if (selectedCurrency == 'MYR') toBDT = 24.0;
      else if (selectedCurrency == 'PKR') toBDT = 0.39;
      else if (selectedCurrency == 'INR') toBDT = 1.31;

      final cashText = p.getString('zm_cash') ?? '0';
      final gold24kText = p.getString('zm_gold_24k') ?? '0';
      final gold22kText = p.getString('zm_gold_22k') ?? '0';
      final gold21kText = p.getString('zm_gold_21k') ?? '0';
      final gold18kText = p.getString('zm_gold_18k') ?? '0';
      final silverGramsText = p.getString('zm_silver') ?? '0';
      final stocksText = p.getString('zm_stocks') ?? '0';
      final businessText = p.getString('zm_business') ?? '0';
      final receivableText = p.getString('zm_receivable') ?? '0';
      final liabilitiesText = p.getString('zm_liabilities') ?? '0';

      final double cashVal = (double.tryParse(cashText.replaceAll(',', '')) ?? 0.0) * toBDT;
      final double stocksVal = (double.tryParse(stocksText.replaceAll(',', '')) ?? 0.0) * toBDT;
      final double businessVal = (double.tryParse(businessText.replaceAll(',', '')) ?? 0.0) * toBDT;
      final double receivableVal = (double.tryParse(receivableText.replaceAll(',', '')) ?? 0.0) * toBDT;
      final double liabilitiesVal = (double.tryParse(liabilitiesText.replaceAll(',', '')) ?? 0.0) * toBDT;

      final double g24k = double.tryParse(gold24kText.replaceAll(',', '')) ?? 0.0;
      final double g22k = double.tryParse(gold22kText.replaceAll(',', '')) ?? 0.0;
      final double g21k = double.tryParse(gold21kText.replaceAll(',', '')) ?? 0.0;
      final double g18k = double.tryParse(gold18kText.replaceAll(',', '')) ?? 0.0;
      final double pureGoldGrams = (g24k * 1.0) + (g22k * 0.9167) + (g21k * 0.875) + (g18k * 0.75);
      final double silverGrams = double.tryParse(silverGramsText.replaceAll(',', '')) ?? 0.0;

      final manualGoldPriceText = p.getString('zm_manual_gold_val') ?? '';
      final manualSilverPriceText = p.getString('zm_manual_silver_val') ?? '';
      
      double effectiveGoldPrice = (double.tryParse(manualGoldPriceText) ?? 0.0) * toBDT;
      if (effectiveGoldPrice == 0.0) {
        effectiveGoldPrice = (3280.0 / 31.1035) * 110.0;
      }
      double effectiveSilverPrice = (double.tryParse(manualSilverPriceText) ?? 0.0) * toBDT;
      if (effectiveSilverPrice == 0.0) {
        effectiveSilverPrice = (34.0 / 31.1035) * 110.0;
      }

      final double goldVal = pureGoldGrams * effectiveGoldPrice;
      final double silverVal = silverGrams * effectiveSilverPrice;

      double customAssetsTotalBDT = 0.0;
      double customLiabilitiesTotalBDT = 0.0;
      final customJson = p.getString('zm_custom_assets');
      if (customJson != null) {
        try {
          final list = json.decode(customJson) as List<dynamic>;
          for (var item in list) {
            final isLiability = item['isLiability'] as bool? ?? false;
            final value = (item['value'] as num?)?.toDouble() ?? 0.0;
            final currency = item['currency'] as String? ?? 'BDT';
            double cRate = 1.0;
            if (currency == 'USD') cRate = 110.0;
            else if (currency == 'SAR') cRate = 29.3;
            else if (currency == 'GBP') cRate = 139.0;
            else if (currency == 'EUR') cRate = 118.0;
            else if (currency == 'AED') cRate = 30.0;
            else if (currency == 'MYR') cRate = 24.0;
            else if (currency == 'PKR') cRate = 0.39;
            else if (currency == 'INR') cRate = 1.31;
            
            if (isLiability) {
              customLiabilitiesTotalBDT += value * cRate;
            } else {
              customAssetsTotalBDT += value * cRate;
            }
          }
        } catch (_) {}
      }

      final rentalGrossText = p.getString('zm_rental_gross') ?? '0';
      final double rentalGross = (double.tryParse(rentalGrossText.replaceAll(',', '')) ?? 0.0) * toBDT;

      final double gross = cashVal + goldVal + silverVal + stocksVal + businessVal + receivableVal + rentalGross + customAssetsTotalBDT;
      final double netWealth = (gross - liabilitiesVal - customLiabilitiesTotalBDT).clamp(0.0, double.infinity);

      final String nisabStandard = p.getString('zm_nisab_std') ?? 'silver';
      double calculatedNisabLimit = nisabStandard == 'gold'
          ? 85.0 * effectiveGoldPrice
          : 595.0 * effectiveSilverPrice;

      setState(() {
        _zakatNetWealth = netWealth;
        _zakatNisabLimit = calculatedNisabLimit;
        _hasZakatData = true;
        _cashCtrl.text = NumberFormat('####').format(cashVal + stocksVal + businessVal + receivableVal + rentalGross + customAssetsTotalBDT);
        _metalsCtrl.text = NumberFormat('####').format(goldVal + silverVal);
        _savingsCtrl.text = '0';
        _debtsCtrl.text = NumberFormat('####').format(liabilitiesVal + customLiabilitiesTotalBDT);
        
        _netAssets = _zakatNetWealth;
        _hasCheckedEligibility = true;
        _isEligible = _netAssets >= _zakatNisabLimit;
        _eligibilityReason = _isEligible
            ? 'Qurbani is WAJIB (mandatory) for you. Your Zakat net assets (৳${NumberFormat('#,##,###').format(_netAssets)}) exceed the Zakat Manager\'s ${nisabStandard == 'gold' ? 'Gold' : 'Silver'} Nisab threshold of ৳${NumberFormat('#,##,###').format(_zakatNisabLimit)}.'
            : 'Qurbani is not mandatory for you. Your Zakat net assets (৳${NumberFormat('#,##,###').format(_netAssets)}) are below the Zakat Manager\'s ${nisabStandard == 'gold' ? 'Gold' : 'Silver'} Nisab threshold of ৳${NumberFormat('#,##,###').format(_zakatNisabLimit)}. You can still perform it voluntarily.';
      });
    }
  }

  Widget _buildQurbaniWealthRecommendationCard(NumberFormat fmt) {
    if (!_hasZakatData) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          '💡 Enter your wealth in Zakat Manager to get a customized budget recommendation.',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    String recommendationText = '';
    double minRec = 0.0;
    double maxRec = 0.0;

    if (_zakatNetWealth < 115000.0) {
      recommendationText = 'Your wealth is below the Nisab threshold. Qurbani is optional for you. If you wish to perform it voluntarily, we recommend keeping it within a modest range so as to not burden yourself.';
      minRec = 15000.0;
      maxRec = 25000.0;
    } else if (_zakatNetWealth <= 500000.0) {
      recommendationText = 'Qurbani is wajib. Based on your net wealth, a budget of ৳20,000 - ৳35,000 is recommended. This is sufficient for a single share of a cow or a healthy goat/sheep.';
      minRec = 20000.0;
      maxRec = 35000.0;
    } else if (_zakatNetWealth <= 2000000.0) {
      recommendationText = 'Based on your ample net wealth, we recommend a budget of ৳35,000 - ৳80,000. You can easily purchase a high-quality goat/sheep or participate in multiple cow/camel shares to share more meat with the needy.';
      minRec = 35000.0;
      maxRec = 80000.0;
    } else {
      recommendationText = 'Based on your abundant net wealth, we recommend a budget of ৳80,000 - ৳250,000. You can easily purchase a full cow/camel or multiple animals to distribute generous portions of meat to the poor.';
      minRec = 80000.0;
      maxRec = 250000.0;
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.amber.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDarkMode ? Colors.white24 : Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: Colors.amber.shade700, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Personalized Budget Recommendation',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _isDarkMode ? Colors.amber.shade200 : AppColors.navyBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Based on your Zakat Net Wealth: ৳${fmt.format(_zakatNetWealth)}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _isDarkMode ? Colors.white70 : Colors.grey[750],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            recommendationText,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: _isDarkMode ? Colors.white60 : Colors.grey[800],
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recommended Range:',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white70 : Colors.black87),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '৳${fmt.format(minRec)} – ৳${fmt.format(maxRec)}',
                  textAlign: TextAlign.end,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.coralOrange),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAqiqahWealthRecommendationCard(NumberFormat fmt) {
    if (!_hasZakatData) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          '💡 Enter your wealth in Zakat Manager to get a customized Aqiqah animal recommendation.',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    String recText = '';
    double minPerAnimal = 0.0;
    double maxPerAnimal = 0.0;

    if (_zakatNetWealth < 115000.0) {
      recText = 'Your wealth is below Nisab. Performing Aqiqah is a sunnah and is highly encouraged. Since your wealth is modest, we recommend choosing a healthy but standard animal to fit your means.';
      minPerAnimal = 15000.0;
      maxPerAnimal = 22000.0;
    } else if (_zakatNetWealth <= 500000.0) {
      recText = 'Based on your net wealth, a budget of ৳22,000 - ৳28,000 per animal is recommended. This will buy a healthy and suitable goat/sheep for the Aqiqah.';
      minPerAnimal = 22000.0;
      maxPerAnimal = 28000.0;
    } else if (_zakatNetWealth <= 2000000.0) {
      recText = 'Based on your ample net wealth, we recommend a budget of ৳28,000 - ৳40,000 per animal. A high-quality goat/sheep is ideal so you can share delicious meat with family and feed the poor.';
      minPerAnimal = 28000.0;
      maxPerAnimal = 40000.0;
    } else {
      recText = 'Based on your abundant net wealth, we recommend a premium budget of ৳40,000+ per animal. You can purchase the best quality livestock to fully honor this beautiful sunnah and share generously with the community.';
      minPerAnimal = 40000.0;
      maxPerAnimal = 75000.0;
    }

    double totalMin = minPerAnimal * _aqiqahQuantity;
    double totalMax = maxPerAnimal * _aqiqahQuantity;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.teal.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDarkMode ? Colors.white24 : Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.child_care_rounded, color: AppColors.midTeal, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Personalized Aqiqah Recommendation',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _isDarkMode ? Colors.teal.shade200 : AppColors.navyBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Based on your Zakat Net Wealth: ৳${fmt.format(_zakatNetWealth)}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _isDarkMode ? Colors.white70 : Colors.grey[750],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            recText,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: _isDarkMode ? Colors.white60 : Colors.grey[800],
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recommended Range (${_aqiqahQuantity} animal${_aqiqahQuantity > 1 ? 's' : ''}):',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white70 : Colors.black87),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '৳${fmt.format(totalMin)} – ৳${fmt.format(totalMax)}',
                  textAlign: TextAlign.end,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAqiqahRules() {
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDarkMode ? Colors.white12 : Colors.grey.shade300),
      ),
      child: ExpansionTile(
        title: Text(
          '📜 Detailed Aqiqah Rules & Rulings',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: _isDarkMode ? Colors.white : AppColors.navyBlue,
          ),
        ),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.symmetric(vertical: 8),
        iconColor: _isDarkMode ? Colors.white70 : AppColors.navyBlue,
        collapsedIconColor: _isDarkMode ? Colors.white54 : AppColors.navyBlue,
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          _labeledRuleBullet('Animal Count:', '2 sheep/goats for a baby boy and 1 sheep/goat for a baby girl. The animals must be of equal standard.'),
          _labeledRuleBullet('Recommended Days:', 'Performing Aqiqah on the 7th day after birth is a highly recommended Sunnah. If missed, the 14th or 21st days are preferred.'),
          _labeledRuleBullet('Animal Quality:', 'Animals must meet the same health/age conditions as Qurbani (1+ years old, healthy, no severe defects).'),
          _labeledRuleBullet('Shaving & Charity:', 'Shave the baby\'s head on the 7th day, weigth the hair, and give its value in silver (or cash equivalent) as charity.'),
          _labeledRuleBullet('Naming:', 'Give the baby a meaningful Islamic name on the 7th day.'),
          _labeledRuleBullet('Meat Distribution:', 'Unlike Qurbani, it is recommended to cook the Aqiqah meat and invite guests (relatives, friends, and the poor) to a feast, though distributing raw meat is also valid.'),
        ],
      ),
    );
  }

  Future<void> _toggleReminder(String type, String title, String body, DateTime time) async {
    bool current = _activeReminders[type] ?? false;
    setState(() => _activeReminders[type] = !current);
    if (!current) {
      int id = 2000 + type.hashCode % 1000;
      await NotificationService.instance.scheduleCustomNotification(
        id: id,
        title: title,
        body: body,
        scheduledTime: time,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🔔 Scheduled: "$title" for ${DateFormat('dd MMM hh:mm a').format(time)}')),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔕 Reminder disabled.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##,###');
    final containerBg = _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor = _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.55);

    return Container(
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: widget.isPage
            ? null
            : const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      child: Column(
        children: [
          if (widget.isPage) ...[
            SizedBox(height: MediaQuery.of(context).padding.top),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? const Color(0xFF2C2C2C) : AppColors.navyBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.pets_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qurbani & Aqiqah Planner',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(color: textColor, fontSize: 15.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Rules, calculation, shares & distribution',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: subtextColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? const Color(0xFF2A2A3E) : AppColors.navyBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.pets_rounded, color: _isDarkMode ? AppColors.midTeal : AppColors.navyBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qurbani & Aqiqah Planner',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Rules, calculation, shares & distribution',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: _isDarkMode ? Colors.white60 : Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                    style: IconButton.styleFrom(backgroundColor: Colors.grey.withValues(alpha: 0.15), padding: const EdgeInsets.all(6)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildTabBar(),
          Expanded(child: _buildTabContent(currencyFormat)),
        ],
      ),
    );
  }

  Future<void> _showGroupSwitcherSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final dialogBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
        return StreamBuilder<List<QPlanSummary>>(
          stream: QurbaniRepository.watchUserPlans(),
          builder: (context, snapshot) {
            final plans = snapshot.data ?? [];
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: dialogBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.groups_rounded, color: AppColors.midTeal, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'My Qurbani Groups',
                            style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Switch seamlessly between all Qurbani groups you own or have joined.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: _isDarkMode ? Colors.white60 : Colors.grey[600]),
                    ),
                    const SizedBox(height: 14),
                    if (plans.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('No active groups found.', style: GoogleFonts.inter(color: Colors.grey)),
                      )
                    else
                      ...plans.map((p) {
                        final isCurrent = _repo != null && _repo!.ownerUid == p.ownerUid && _repo!.planId == p.planId;
                        final animalIcon = p.animalType.toLowerCase() == 'goat' ? '🐐' : '🐄';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.midTeal.withValues(alpha: 0.12)
                                : (_isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent ? AppColors.midTeal : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.midTeal.withValues(alpha: 0.2),
                              child: Text(animalIcon, style: const TextStyle(fontSize: 18)),
                            ),
                            title: Text(
                              '${p.ownerName}\'s Qurbani Plan',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                            ),
                            subtitle: Text(
                              '${p.animalType.toUpperCase()} · ${p.totalShares} Shares · ${p.isOwner ? "Owner" : "Member"}',
                              style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white60 : Colors.grey[600]),
                            ),
                            trailing: isCurrent
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.midTeal)
                                : OutlinedButton(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      // Directly set the repo from the known ownerUid + planId
                                      // This avoids re-validation through load() which might fail
                                      // if memberIds array hasn't yet propagated
                                      await QurbaniRepository.switchGroup(p.ownerUid, p.planId);
                                      final newRepo = QurbaniRepository._(p.ownerUid, p.planId);
                                      if (mounted) setState(() => _repo = newRepo);
                                    },
                                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                                    child: const Text('Switch', style: TextStyle(fontSize: 11)),
                                  ),
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final newRepo = await QurbaniRepository.createGroup();
                              if (mounted) setState(() => _repo = newRepo);
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                            label: const Text('New Group', style: TextStyle(fontSize: 11.5)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showHouseholdSharingSheet();
                            },
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                            label: const Text('Join Group', style: TextStyle(fontSize: 11.5)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal, foregroundColor: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }



  // Lets the plan owner see/generate their invite code (persistent, like the
  // Emergency SOS group code), or lets any user enter someone else's code to
  // join their plan instead (switching this device to point at that shared
  // Firestore path).
  Future<void> _showHouseholdSharingSheet() async {
    final repo = _repo;
    final isOwner = repo?.ownerUid == QurbaniRepository.currentUid();
    final joinCtrl = TextEditingController();

    // Fetch whatever code already exists BEFORE opening the sheet, so the
    // owner always lands on "here is your code", never on a stale
    // "Generate" button for a code that was already created (e.g. at
    // group-creation time).
    String? generatedCode;
    String? loadError;
    if (isOwner && repo != null) {
      try {
        generatedCode = await repo.getInviteCode();
      } catch (error) {
        loadError = 'Could not load your existing code: $error';
      }
    }

    bool generating = false;
    bool updatingShares = false;
    bool joining = false;
    String? error = loadError;
    int myShares = 1;
    int joinShares = 1;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share this plan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 6),
                Text(
                  'Use one code to share the same member list, expenses, and settlements. Anyone with the code can join this plan.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], height: 1.4),
                ),
                const SizedBox(height: 20),

                if (isOwner) ...[
                  Text('Your group code', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    'Keep this screen handy — this code stays the same and is shown here any time you need to give it to a new member.',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600], height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  if (generatedCode != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(generatedCode!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2, color: AppColors.midTeal)),
                          ),
                          IconButton(
                            tooltip: 'Copy code',
                            icon: const Icon(Icons.copy_rounded, color: AppColors.midTeal),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: generatedCode!));
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Code copied')));
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: generating
                          ? null
                          : () async {
                              setD(() {
                                generating = true;
                                error = null;
                              });
                              try {
                                final code = await repo!.createInviteCode();
                                setD(() {
                                  generatedCode = code;
                                  generating = false;
                                });
                              } catch (e) {
                                setD(() {
                                  error = e is FirebaseException
                                      ? (e.code == 'permission-denied'
                                          ? 'Could not generate a code: Firestore rules for this plan are not deployed yet.'
                                          : 'Could not generate a code: ${e.message ?? e.code}')
                                      : 'Could not generate a code: $e';
                                  generating = false;
                                });
                              }
                            },
                      icon: generating
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.qr_code_rounded, size: 18),
                      label: const Text('Generate group code'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: GoogleFonts.inter(color: Colors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),
                ],

                Text('My shares in this plan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Row(children: [
                  IconButton(onPressed: myShares > 1 ? () => setD(() => myShares--) : null, icon: const Icon(Icons.remove_circle_outline)),
                  Text('$myShares', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: myShares < 7 ? () => setD(() => myShares++) : null, icon: const Icon(Icons.add_circle_outline)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (repo == null || updatingShares)
                          ? null
                          : () async {
                              setD(() => updatingShares = true);
                              try {
                                await repo.updateOwnShares(myShares);
                                setD(() => updatingShares = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Your shares were updated')));
                                }
                              } catch (e) {
                                setD(() {
                                  updatingShares = false;
                                  error = 'Could not update your shares: $e';
                                });
                              }
                            },
                      child: updatingShares
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Update my shares'),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                Text('Join a shared plan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Row(children: [
                  Text('Shares to join with:', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                  IconButton(onPressed: joinShares > 1 ? () => setD(() => joinShares--) : null, icon: const Icon(Icons.remove_circle_outline, size: 20)),
                  Text('$joinShares', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: joinShares < 7 ? () => setD(() => joinShares++) : null, icon: const Icon(Icons.add_circle_outline, size: 20)),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: joinCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter invite code (e.g. QRB-AB12CD)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: joining
                      ? null
                      : () async {
                          if (joinCtrl.text.trim().isEmpty) return;
                          setD(() {
                            joining = true;
                            error = null;
                          });
                          try {
                            final r = await QurbaniRepository.joinByCode(joinCtrl.text, joinShares);
                            if (mounted) {
                              setState(() => _repo = r);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setD(() {
                              joining = false;
                              error = e is FirebaseException
                                  ? 'Could not join: ${e.message ?? e.code}'
                                  : 'Could not join: $e';
                            });
                          }
                        },
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                  child: joining ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Join with this code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    const compactLabels = ['Eligib.', 'Calc.', 'Shares', 'Board', 'Distrib.', 'Tasks'];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: List.generate(_tabLabels.length, (i) {
          final active = i == _tab;
          final activeBg = _isDarkMode ? AppColors.midTeal : AppColors.navyBlue;
          final inactiveColor = _isDarkMode ? Colors.white60 : AppColors.navyBlue.withValues(alpha: 0.5);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_tabIcons[i],
                        size: 16,
                        color: active ? Colors.white : inactiveColor),
                    const SizedBox(height: 2),
                    Text(compactLabels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : inactiveColor)),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(NumberFormat fmt) {
    switch (_tab) {
      case 0:
        return _buildEligibilityTab(fmt);
      case 1:
        return _buildCalculatorsTab(fmt);
      case 2:
        return _buildSharesTab(fmt);
      case 3:
        return _buildShareBoardTab(fmt);
      case 4:
        return _buildMeatDistributionTab();
      case 5:
        return _buildTasksTab();
      default:
        return _buildEligibilityTab(fmt);
    }
  }

  // ===========================================================================
  // ELIGIBILITY TAB (unchanged logic from previous version)
  // ===========================================================================
  // ===========================================================================
  // ELIGIBILITY TAB (unchanged logic from previous version)
  // ===========================================================================
  Widget _buildReadOnlyRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: _isDarkMode ? Colors.white70 : AppColors.navyBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: _isDarkMode ? Colors.white70 : Colors.grey[750],
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityTab(NumberFormat fmt) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E1E1E) : AppColors.dustyBlueTeal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _isDarkMode ? Colors.white.withValues(alpha: 0.12) : AppColors.dustyBlueTeal.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.info_outline_rounded, color: _isDarkMode ? AppColors.midTeal : AppColors.navyBlue, size: 20),
                const SizedBox(width: 8),
                Text('Qurbani Guidance',
                    style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
              const SizedBox(height: 8),
              Text(
                'Qurbani is WAJIB (compulsory) for every adult, sane Muslim who owns the Nisab threshold of wealth on the days of Eid. It requires sacrificing one goat/sheep per person, or 1 share in a larger animal (like cow/camel).',
                style: GoogleFonts.inter(color: _isDarkMode ? Colors.white70 : Colors.grey[800], fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Check Your Eligibility',
            style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15.5)),
        const SizedBox(height: 10),
        if (_hasZakatData) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.midTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.sync_alt_rounded, color: AppColors.midTeal, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Assets imported from Zakat Manager (Net: ৳${fmt.format(_zakatNetWealth)})',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isDarkMode ? Colors.white70 : AppColors.navyBlue,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _loadZakatWealthData,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Sync',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.midTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Card(
            color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: _isDarkMode ? BorderSide(color: Colors.white.withValues(alpha: 0.12)) : BorderSide.none),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildReadOnlyRow(icon: Icons.savings_outlined, label: 'Annual Savings', value: '৳${fmt.format(double.tryParse(_savingsCtrl.text) ?? 0)}'),
                  _buildReadOnlyRow(icon: Icons.storefront_outlined, label: 'Gold / Silver (value in BDT)', value: '৳${fmt.format(double.tryParse(_metalsCtrl.text) ?? 0)}'),
                  _buildReadOnlyRow(icon: Icons.monetization_on_outlined, label: 'Available Cash & Assets', value: '৳${fmt.format(double.tryParse(_cashCtrl.text) ?? 0)}'),
                  _buildReadOnlyRow(icon: Icons.money_off_csred_outlined, label: 'Debts & Liabilities', value: '৳${fmt.format(double.tryParse(_debtsCtrl.text) ?? 0)}'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ZakatManagerScreen()),
                      ).then((_) => _loadZakatWealthData());
                    },
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: Text('Edit Wealth in Zakat Manager', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Card(
            color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: _isDarkMode ? BorderSide(color: Colors.white.withValues(alpha: 0.12)) : BorderSide.none),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.midTeal.withValues(alpha: 0.8)),
                  const SizedBox(height: 12),
                  Text(
                    'No Zakat Wealth Data Found',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: _isDarkMode ? Colors.white : AppColors.navyBlue),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To calculate Qurbani eligibility, please set up your assets in the Zakat Manager first. Your eligibility will be automatically calculated based on your Zakat records.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: _isDarkMode ? Colors.white70 : Colors.grey[750], fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ZakatManagerScreen()),
                      ).then((_) => _loadZakatWealthData());
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: Text('Set Up Wealth in Zakat Manager', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_hasCheckedEligibility) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isEligible ? AppColors.midTeal.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _isEligible ? AppColors.midTeal : AppColors.coralOrange),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_isEligible ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                    color: _isEligible ? AppColors.midTeal : AppColors.coralOrange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isEligible ? '✔ Eligible for Qurbani' : '✖ Not Eligible / Optional',
                          style: GoogleFonts.poppins(
                              color: _isEligible ? AppColors.midTeal : AppColors.coralOrange, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(_eligibilityReason,
                          style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.grey[800], fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('General Rules & Guidelines',
            style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _labeledRuleBullet('Age limits:', 'Goat/Sheep must be 1+ years. Cow/Buffalo must be 2+ years. Camel must be 5+ years.'),
              _labeledRuleBullet('Health conditions:', 'The animal must be healthy and free of defects like blindness, severe limp, or extreme emaciation.'),
              _labeledRuleBullet('Timing:', 'Valid from after Eid prayer on 10 Dhul Hijjah until sunset on 13 Dhul Hijjah.'),
              _labeledRuleBullet('Important Sunnahs:', 'Fast during the first 9 days of Dhul Hijjah, avoid cutting hair or nails from 1st Dhul Hijjah until sacrifice is done (if you are the one sacrificing), and recite Takbeer Tashreeq after prayers.'),
              _labeledRuleBullet('Meat distribution:', 'Recommended to divide the meat into three parts: 1/3 for family, 1/3 for relatives/friends, 1/3 for poor/needy.', last: true),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _tab = 5; // Tasks tab (Rules & Verses)
                    _tasksSubTab = 1;
                  }),
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: const Text("Read full Qur'anic basis & detailed rulings"),
                  style: TextButton.styleFrom(foregroundColor: AppColors.midTeal, padding: EdgeInsets.zero),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('🔔 Eligibility Reminder', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Re-check Nisab before Dhul Hijjah',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : null)),
                    const SizedBox(height: 4),
                    Text('Get a nudge a few days before Eid to re-check your assets against the current Nisab value, since gold/silver prices change.',
                        style: GoogleFonts.inter(color: _isDarkMode ? Colors.white54 : Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: _activeReminders['Eligibility'] ?? false,
                activeThumbColor: AppColors.navyBlue,
                onChanged: (val) => _toggleReminder(
                  'Eligibility',
                  '\ud83d\udccb Nisab Re-check Reminder',
                  'Eid al-Adha is approaching. Re-check your savings, gold/silver and cash against the current Nisab value to confirm Qurbani eligibility.',
                  DateTime.now().add(const Duration(seconds: 20)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _labeledRuleBullet(String boldText, String text, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(Icons.brightness_1, size: 6, color: _isDarkMode ? AppColors.midTeal : AppColors.navyBlue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(color: _isDarkMode ? Colors.white70 : Colors.grey[800], fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: '$boldText ', style: TextStyle(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow({required IconData icon, required String label, required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: _isDarkMode ? Colors.white : AppColors.navyBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.grey[700], fontSize: 13))),
          SizedBox(
            width: 120,
            height: 38,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _isDarkMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                prefixText: '৳ ',
                prefixStyle: GoogleFonts.inter(color: _isDarkMode ? Colors.white54 : Colors.grey[600]),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: _isDarkMode ? BorderSide.none : const BorderSide(color: Colors.grey)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CALCULATORS TAB (unchanged logic from previous version)
  // ===========================================================================
  // ===========================================================================
  // CALCULATORS TAB (unchanged logic from previous version)
  // ===========================================================================
  Widget _buildCalculatorsTab(NumberFormat fmt) {
    double minRec = 0.0;
    double maxRec = 0.0;
    if (_zakatNetWealth < 115000.0) {
      minRec = 15000.0;
      maxRec = 25000.0;
    } else if (_zakatNetWealth <= 500000.0) {
      minRec = 20000.0;
      maxRec = 35000.0;
    } else if (_zakatNetWealth <= 2000000.0) {
      minRec = 35000.0;
      maxRec = 80000.0;
    } else {
      minRec = 80000.0;
      maxRec = 250000.0;
    }

    double minPerAnimal = 0.0;
    double maxPerAnimal = 0.0;
    if (_zakatNetWealth < 115000.0) {
      minPerAnimal = 15000.0;
      maxPerAnimal = 22000.0;
    } else if (_zakatNetWealth <= 500000.0) {
      minPerAnimal = 22000.0;
      maxPerAnimal = 28000.0;
    } else if (_zakatNetWealth <= 2000000.0) {
      minPerAnimal = 28000.0;
      maxPerAnimal = 40000.0;
    } else {
      minPerAnimal = 40000.0;
      maxPerAnimal = 75000.0;
    }
    double aqiqahTotalMin = minPerAnimal * _aqiqahQuantity;
    double aqiqahTotalMax = maxPerAnimal * _aqiqahQuantity;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Text('Qurbani Cost Planner',
            style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15.5)),
        const SizedBox(height: 12),
        Card(
          color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Animal', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _isDarkMode ? Colors.white70 : Colors.grey[700])),
                const SizedBox(height: 6),
                Row(
                  children: ['Cow', 'Goat', 'Camel'].map((animal) {
                    bool sel = _selectedAnimal == animal;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedAnimal = animal;
                          if (animal == 'Goat') _selectedShares = 1;
                          _calculateCosts();
                        }),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(color: sel ? AppColors.navyBlue : Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: Text(animal, style: GoogleFonts.inter(color: sel ? Colors.white : Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Select Location', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _isDarkMode ? Colors.white70 : Colors.grey[700])),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLocation,
                  dropdownColor: _isDarkMode ? const Color(0xFF2C2C2C) : null,
                  style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.black87),
                  items: [
                    DropdownMenuItem(value: 'Dhaka', child: Text('Dhaka', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.black87))),
                    DropdownMenuItem(value: 'Chittagong', child: Text('Chittagong', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.black87))),
                    DropdownMenuItem(value: 'Other', child: Text('Other Divisions', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.black87))),
                  ],
                  onChanged: (val) => setState(() {
                    _selectedLocation = val!;
                    _calculateCosts();
                    _calculateAqiqahCosts();
                  }),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: _isDarkMode,
                    fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isDarkMode ? Colors.white30 : Colors.grey)),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedAnimal != 'Goat') ...[
                  Text('Number of Shares (1 to 7)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _isDarkMode ? Colors.white70 : Colors.grey[700])),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _selectedShares > 1 ? () => setState(() { _selectedShares--; _calculateCosts(); }) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      const SizedBox(width: 8),
                      Text('$_selectedShares Share(s)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: _isDarkMode ? Colors.white : null)),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _selectedShares < 7 ? () => setState(() { _selectedShares++; _calculateCosts(); }) : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.navyBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasZakatData ? 'Estimated Cost (Based on Wealth):' : 'Estimated Cost:',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _hasZakatData
                                    ? '৳${fmt.format(minRec)} – ৳${fmt.format(maxRec)}'
                                    : '৳${fmt.format(_estimatedCost)}',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.coralOrange,
                                  fontSize: 15.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_hasZakatData) ...[
                        const SizedBox(height: 6),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Selected Animal Cost:',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: _isDarkMode ? Colors.white70 : Colors.grey[750],
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '৳${fmt.format(_estimatedCost)}',
                                textAlign: TextAlign.end,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _isDarkMode ? Colors.white70 : Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                _buildQurbaniWealthRecommendationCard(fmt),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('🍼 Aqiqah Planner', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15.5)),
        const SizedBox(height: 12),
        Card(
          color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aqiqah Guidelines', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontSize: 14)),
                const SizedBox(height: 6),
                Text(
                  'Aqiqah is a sunnah practice of sacrificing animal(s) upon the birth of a child. It is recommended to perform it on the 7th, 14th, or 21st day after birth.',
                  style: GoogleFonts.inter(color: _isDarkMode ? Colors.white70 : Colors.grey[700], fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Baby's Gender", style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _aqiqahBabyGender,
                            dropdownColor: _isDarkMode ? const Color(0xFF2C2C2C) : null,
                            style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.black87),
                            items: [
                              DropdownMenuItem(value: 'Boy', child: Text('Boy', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.black87))),
                              DropdownMenuItem(value: 'Girl', child: Text('Girl', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.black87))),
                            ],
                            onChanged: (val) => setState(() {
                              _aqiqahBabyGender = val!;
                              _aqiqahQuantity = _aqiqahBabyGender == 'Boy' ? 2 : 1;
                              _calculateAqiqahCosts();
                            }),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              filled: _isDarkMode,
                              fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _isDarkMode ? Colors.white30 : Colors.grey)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Animal Qty', style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: _isDarkMode ? const Color(0xFF2C2C2C) : null,
                              border: Border.all(color: _isDarkMode ? Colors.white30 : Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$_aqiqahQuantity Goat / Sheep',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : Colors.black87)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.midTeal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasZakatData ? 'Aqiqah Recommended Cost:' : 'Aqiqah Estimated Cost:',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: AppColors.midTeal,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _hasZakatData
                                  ? '৳${fmt.format(aqiqahTotalMin)} - ৳${fmt.format(aqiqahTotalMax)}'
                                  : '৳${fmt.format(_aqiqahEstimatedCost)}',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: AppColors.midTeal,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_hasZakatData) ...[
                        const SizedBox(height: 6),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Standard Animal Cost:',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: _isDarkMode ? Colors.white70 : Colors.grey[750],
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '৳${fmt.format(_aqiqahEstimatedCost)}',
                                textAlign: TextAlign.end,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _isDarkMode ? Colors.white70 : Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                _buildAqiqahWealthRecommendationCard(fmt),
                _buildAqiqahRules(),
                Text('Aqiqah Checklist', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontSize: 13)),
                const SizedBox(height: 8),
        Column(
                  children: _aqiqahChecklist.map((item) {
                    final bool done = item['done'] as bool? ?? false;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.midTeal.withValues(alpha: 0.07)
                            : (_isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.white),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: done
                              ? AppColors.midTeal.withValues(alpha: 0.3)
                              : (_isDarkMode ? Colors.white10 : Colors.grey.shade200),
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                          minTileHeight: 0,
                          leading: Transform.scale(
                            scale: 0.85,
                            child: Checkbox(
                              value: done,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              checkColor: _isDarkMode ? Colors.black : Colors.white,
                              activeColor: AppColors.midTeal,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) => setState(() => item['done'] = val),
                            ),
                          ),
                          title: Text(
                            item['title'],
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: done
                                  ? AppColors.midTeal
                                  : (_isDarkMode ? Colors.white : Colors.black87),
                              decoration: done ? TextDecoration.lineThrough : null,
                              decorationColor: AppColors.midTeal,
                            ),
                          ),
                          children: [
                            Text(
                              item['rule'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _isDarkMode ? Colors.white60 : Colors.grey[700],
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // DISTRIBUTION TAB (unchanged logic from previous version)
  // ===========================================================================
  Widget _buildMeatDistributionTab() {
    double familyQty = _totalMeatKg / 3;
    double relativesQty = _totalMeatKg / 3;
    double poorQty = _totalMeatKg / 3;
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final familyColor = _isDarkMode ? const Color(0xFF4A7DFF) : AppColors.navyBlue;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Icon(Icons.scale_rounded, color: AppColors.midTeal, size: 22),
            const SizedBox(width: 8),
            Text('Meat Distribution Planner', style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 15.5)),
          ],
        ),
        const SizedBox(height: 4),
        Text('Set your total meat quantity to plan the Sunnah-based 3-way distribution.',
            style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 20),

        // --- DONUT CHART ---
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(150, 150),
                      painter: _DistributionDonutPainter([
                        _Slice(1 / 3, familyColor),
                        _Slice(1 / 3, AppColors.midTeal),
                        _Slice(1 / 3, AppColors.coralOrange),
                      ], isDarkMode: _isDarkMode),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_totalMeatKg.toStringAsFixed(0)} kg',
                            style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.bold, color: textColor)),
                        Text('Total Meat', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _isDarkMode ? Colors.white54 : Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _pieLegend('Family (1/3)', familyColor),
                  const SizedBox(width: 14),
                  _pieLegend('Relatives (1/3)', AppColors.midTeal),
                  const SizedBox(width: 14),
                  _pieLegend('Poor (1/3)', AppColors.coralOrange),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- INPUT CARD ---
        Card(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Meat Amount (in kg)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      Text('Adjust slider or enter below', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white54 : Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor),
                    decoration: InputDecoration(
                      suffixText: ' kg',
                      suffixStyle: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey),
                      filled: _isDarkMode,
                      fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : null,
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _isDarkMode ? Colors.white30 : Colors.grey)),
                    ),
                    onChanged: (val) => setState(() => _totalMeatKg = double.tryParse(val) ?? 0.0),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Slider(
          value: _totalMeatKg.clamp(0.0, 300.0),
          min: 0,
          max: 300,
          divisions: 30,
          activeColor: AppColors.midTeal,
          inactiveColor: Colors.grey[300],
          label: '${_totalMeatKg.round()} kg',
          onChanged: (val) => setState(() => _totalMeatKg = val),
        ),
        const SizedBox(height: 16),

        Text('Suggested Distribution Split', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
        const SizedBox(height: 8),
        Container(
          height: 35,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.grey[200]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Expanded(child: Container(color: familyColor, alignment: Alignment.center, child: Text('Family (1/3)', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                Container(width: 1.5, color: Colors.white),
                Expanded(child: Container(color: AppColors.midTeal, alignment: Alignment.center, child: Text('Relatives (1/3)', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                Container(width: 1.5, color: Colors.white),
                Expanded(child: Container(color: AppColors.coralOrange, alignment: Alignment.center, child: Text('Poor (1/3)', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _buildDistributionCard('Family Portion', familyQty, familyColor),
          const SizedBox(width: 8),
          _buildDistributionCard('Relatives Portion', relativesQty, AppColors.midTeal),
          const SizedBox(width: 8),
          _buildDistributionCard('Poor / Needy', poorQty, AppColors.coralOrange),
        ]),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF2B2414) : Colors.amber[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _isDarkMode ? Colors.amber[700]!.withValues(alpha: 0.4) : Colors.amber[200]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 18, color: Colors.amber[800]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Note: The 1/3 meat distribution rule is a highly recommended (Mustahabb) Sunnah based on traditional Islamic practices to encourage sharing and charity, but it is not a binding compulsory requirement. You may distribute more to charity or retain more based on family size and needs.',
                  style: GoogleFonts.inter(color: _isDarkMode ? Colors.amber[200] : Colors.amber[900], fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionCard(String title, double qty, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(top: BorderSide(color: accentColor, width: 4)),
        ),
        child: Column(
          children: [
            Text(title, style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white60 : Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('${qty.toStringAsFixed(1)} kg', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
          ],
        ),
      ),
    );
  }

  Widget _pieLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white70 : Colors.grey[700])),
      ],
    );
  }

  // ===========================================================================
  // SHARES TAB — Participants / Expenses / Settlements / Edit Requests
  // ===========================================================================
  Future<void> _createGroup() async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to create a shared plan.')));
      return;
    }
    try {
      final group = await QurbaniRepository.createGroup();
      if (mounted) setState(() => _repo = group);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create group: $error')));
    }
  }

  Future<void> _showJoinGroupDialog() async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to join a shared plan.')));
      return;
    }
    final codeCtrl = TextEditingController();
    int joinShares = 1;
    bool joining = false;
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Join a shared plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter the invite code you received and choose your share count.',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], height: 1.4)),
                const SizedBox(height: 12),
                Row(children: [
                  Text('Shares:', style: GoogleFonts.inter(fontSize: 12)),
                  IconButton(onPressed: joinShares > 1 ? () => setD(() => joinShares--) : null, icon: const Icon(Icons.remove, size: 18)),
                  Text('$joinShares', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  IconButton(onPressed: joinShares < 7 ? () => setD(() => joinShares++) : null, icon: const Icon(Icons.add, size: 18)),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter invite code (e.g. QRB-AB12CD)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: joining ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: joining
                  ? null
                  : () async {
                      if (codeCtrl.text.trim().isEmpty) return;
                      setD(() => joining = true);
                      try {
                        final r = await QurbaniRepository.joinByCode(codeCtrl.text, joinShares);
                        if (mounted) setState(() => _repo = r);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setD(() => error = e is FirebaseException ? 'Could not join: ${e.message ?? e.code}' : 'Could not join: $e');
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal, foregroundColor: Colors.white),
              child: joining ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmGroupAction({required bool isOwner}) {
    final title = isOwner ? 'Delete Qurbani Group?' : 'Leave Qurbani Group?';
    final message = isOwner
        ? 'Are you sure you want to delete this group? This removes the shared plan and invalidates the group invite code for all participants. This action cannot be undone.'
        : 'Are you sure you want to leave the group? You will lose access to this shared plan, members, expenses, and settlements.';
    final dialogBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
        content: Text(message, style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: _isDarkMode ? Colors.white70 : Colors.grey[700])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                if (isOwner) {
                  await _repo!.deleteGroup();
                } else {
                  await _repo!.leaveGroup();
                }
                if (mounted) {
                  setState(() => _repo = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isOwner ? 'Group deleted.' : 'You have left the group.')),
                  );
                }
              } catch (error) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not complete action: $error')));
              }
            },
            child: Text(isOwner ? 'Delete Group' : 'Leave Group', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSharesTab(NumberFormat fmt) {
    if (_isLoadingRepo) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.midTeal),
            const SizedBox(height: 16),
            Text(
              'Connecting to your Qurbani Group...',
              style: GoogleFonts.poppins(fontSize: 13, color: _isDarkMode ? Colors.white70 : AppColors.navyBlue),
            ),
          ],
        ),
      );
    }

    if (_repo == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_outlined, size: 42, color: AppColors.midTeal),
              const SizedBox(height: 12),
              Text(
                _repositoryError ?? 'Create a shared plan to become its owner, generate a group code, and invite others.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: _isDarkMode ? Colors.white70 : Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _createGroup,
                icon: const Icon(Icons.group_add_rounded),
                label: const Text('Create a group'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal, foregroundColor: Colors.white),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _repositoryError == null ? _showJoinGroupDialog : null,
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Join a group'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navyBlue,
                  side: const BorderSide(color: AppColors.navyBlue),
                ),
              ),

            ],
          ),
        ),
      );
    }
    final subLabels = ['Participants', 'Expenses', 'Settlements', 'Requests', 'Chat'];
    final subIcons = [
      Icons.people_alt_rounded,
      Icons.payments_rounded,
      Icons.handshake_rounded,
      Icons.edit_note_rounded,
      Icons.chat_bubble_rounded,
    ];
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: List.generate(subLabels.length, (i) {
                final active = _sharesSubTab == i;
                // Compact sub-tab labels
                const compact = ['People', 'Expenses', 'Settle', 'Requests', 'Chat'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _sharesSubTab = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
                      decoration: BoxDecoration(
                        color: active ? AppColors.midTeal : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(subIcons[i],
                              size: 14,
                              color: active ? Colors.white : (_isDarkMode ? Colors.white54 : Colors.grey[500])),
                          const SizedBox(height: 2),
                          Text(compact[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: active ? Colors.white : (_isDarkMode ? Colors.white54 : Colors.grey[500]))),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),


        Expanded(
          child: () {
            switch (_sharesSubTab) {
              case 0:
                return _buildParticipantsSection(fmt);
              case 1:
                return _buildExpensesSection(fmt);
              case 2:
                return _buildSettlementsSection(fmt);
              case 3:
                return _buildEditRequestsSection();
              default:
                return _buildGroupChatSection();
            }
          }(),
        ),
      ],
    );
  }

  // ---- Participants -------------------------------------------------------
  Widget _buildParticipantsSection(NumberFormat fmt) {
    final myUid = QurbaniRepository.currentUid();
    return StreamBuilder<List<QParticipant>>(
      stream: _repo!.watchParticipants(),
      builder: (context, snap) {
        final participants = snap.data ?? [];
        return ListView(
          controller: widget.scrollController,
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).padding.bottom + 100),
          children: [
            _buildDashboardOverviewCard(fmt, participants),
            const SizedBox(height: 16),
            Text('Participants', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15.5)),
            const SizedBox(height: 4),
            Text("Each member joins with the group code and chooses their own share count.",
                style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 12, height: 1.4)),
            const SizedBox(height: 12),
            _sharedGroupCard(),
            const SizedBox(height: 16),
            if (participants.isEmpty)
              _emptyState('No participants yet. Add the first one below.')
            else
              ...participants.map((p) => _participantCard(p, myUid)),
            const SizedBox(height: 16),
            _addParticipantCard(),
          ],
        );
      },
    );
  }

  Widget _buildDashboardOverviewCard(NumberFormat fmt, List<QParticipant> participants) {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final palette = [
      AppColors.midTeal,
      AppColors.coralOrange,
      AppColors.navyBlue,
      Colors.purple,
      Colors.amber,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];

    return StreamBuilder<List<QExpense>>(
      stream: _repo!.watchExpenses(),
      builder: (context, expSnap) {
        final expenses = expSnap.data ?? [];
        final totalSpent = expenses.fold<double>(0, (sum, e) => sum + e.amount);
        final assignedShares = participants.fold<int>(0, (sum, p) => sum + p.shares);
        final totalShares = 7;
        final costPerShare = assignedShares > 0 ? totalSpent / assignedShares : 0.0;

        final slices = <_Slice>[];
        final legendItems = <Widget>[];

        if (assignedShares > 0) {
          for (var i = 0; i < participants.length; i++) {
            final p = participants[i];
            final color = palette[i % palette.length];
            final frac = p.shares / assignedShares;
            slices.add(_Slice(frac, color));

            final pct = (frac * 100).round();
            // Shorten name to max 9 chars so labels never truncate
            final shortName = p.name.length > 9 ? '${p.name.substring(0, 8)}.' : p.name;
            legendItems.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isDarkMode ? Colors.white38 : Colors.black12,
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$shortName ${p.shares}/$assignedShares ($pct%)',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Full planning enabled! Reserve your animal, log costs & track assigned shares. Summary updates automatically as participants & expenses are added.',
                      style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.amber[200] : Colors.amber[900], height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _summaryStatCard(
                      title: 'TOTAL SPENT',
                      value: '৳${fmt.format(totalSpent.round())}',
                      subtitle: '${expenses.length} expenses',
                      color: AppColors.coralOrange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryStatCard(
                      title: 'SHARES ASSIGNED',
                      value: '$assignedShares / $totalShares',
                      subtitle: '${participants.length} members',
                      color: AppColors.midTeal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryStatCard(
                      title: 'COST / SHARE',
                      value: '৳${fmt.format(costPerShare.round())}',
                      subtitle: 'total ÷ shares',
                      color: _isDarkMode ? AppColors.midTeal : AppColors.navyBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SHARE WHEEL', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                  if (slices.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No shares assigned yet. Add participants to build the share wheel automatically!',
                            textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey)),
                      ),
                    )
                  else
                    Row(
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CustomPaint(
                            painter: _DistributionPiePainter(slices),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: legendItems,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    // In dark mode, ensure the accent colour is bright enough to read
    final labelColor = _isDarkMode
        ? HSLColor.fromColor(color).withLightness(0.72).toColor()
        : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: _isDarkMode ? 0.45 : 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.bold, color: labelColor, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 9, color: _isDarkMode ? Colors.white54 : Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _sharedGroupCard() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final isOwner = _repo!.ownerUid == QurbaniRepository.currentUid();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _repo!.planRef.snapshots(),
      builder: (context, planSnapshot) {
        if (planSnapshot.connectionState != ConnectionState.waiting &&
            planSnapshot.hasData &&
            !planSnapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This group no longer exists',
                    style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Text('The owner deleted this shared plan. You can create your own group or join a different one.',
                    style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 11.5, height: 1.35)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _repo!.forgetLocally();
                      if (mounted) setState(() => _repo = null);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal, foregroundColor: Colors.white),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          );
        }
        final code = planSnapshot.data?.data()?['inviteCode'] as String?;
        return StreamBuilder<List<QParticipant>>(
          stream: _repo!.watchParticipants(),
          builder: (context, participantsSnapshot) {
            final members = participantsSnapshot.data ?? const <QParticipant>[];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.groups_rounded, color: AppColors.midTeal, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Shared Plan Group', style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(isOwner ? 'You are the Owner of this plan.' : 'You are a Member of this shared plan.',
                              style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 11)),
                        ],
                      ),
                    ),
                  ]),
                  if (code != null) ...[
                    const SizedBox(height: 12),
                    Text('INVITE GROUP CODE', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.8)),
                    const SizedBox(height: 5),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(code, style: GoogleFonts.poppins(color: AppColors.midTeal, fontWeight: FontWeight.bold, fontSize: 19, letterSpacing: 2)),
                          ),
                          IconButton(
                            tooltip: 'Copy code',
                            icon: const Icon(Icons.copy_rounded, color: AppColors.midTeal, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied to clipboard')));
                            },
                          ),
                          IconButton(
                            tooltip: 'Share via SMS / Message',
                            icon: const Icon(Icons.share_rounded, color: AppColors.midTeal, size: 20),
                            onPressed: () async {
                              final shareText = "Join my Qurbani Plan on DeenMate using code: $code";
                              final uri = Uri.parse("sms:?body=${Uri.encodeComponent(shareText)}");
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                Clipboard.setData(ClipboardData(text: shareText));
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share text copied!')));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Group Members (${members.length})', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (members.isEmpty)
                    Text('No members yet.', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 11.5))
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: members.map((member) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DeenMateAvatar(name: member.name, photoUrl: member.photoUrl, avatarBase64: member.avatarBase64, radius: 12),
                            const SizedBox(width: 6),
                            Text('${member.name} (${member.shares} share${member.shares > 1 ? "s" : ""})',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
                          ],
                        ),
                      )).toList(),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmGroupAction(isOwner: isOwner),
                      icon: Icon(isOwner ? Icons.delete_outline_rounded : Icons.logout_rounded, size: 18),
                      label: Text(isOwner ? 'Delete Group' : 'Leave Group'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _participantCard(QParticipant p, String myUid) {
    final recordOwnedByMe = p.ownerId == myUid;
    final isPlanOwner = _repo != null && _repo!.ownerUid == myUid;
    // Group Owner badge belongs ONLY to the group creator/owner (not everyone added by owner)
    final isParticipantGroupOwner = _repo != null && (p.uid == _repo!.ownerUid || p.id == _repo!.ownerUid);
    final canEditDirect = recordOwnedByMe || isPlanOwner;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => canEditDirect ? _editParticipantDirect(p) : _requestParticipantEdit(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              DeenMateAvatar(name: p.name, photoUrl: p.photoUrl, avatarBase64: p.avatarBase64, radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.name.isNotEmpty ? p.name : (isParticipantGroupOwner ? 'Group Owner' : 'Member'),
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : null),
                          ),
                        ),
                        if (isParticipantGroupOwner) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text('Owner', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                          ),
                        ],
                      ],
                    ),
                    Text('${p.shares} Share(s) · added by ${recordOwnedByMe ? "you" : p.ownerName}',
                        style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
                  ],
                ),
              ),
              if (canEditDirect)
                IconButton(
                  tooltip: 'Edit shares',
                  icon: const Icon(Icons.edit_rounded, color: AppColors.midTeal, size: 19),
                  onPressed: () => _editParticipantDirect(p),
                )
              else
                IconButton(
                  tooltip: 'Request a change',
                  icon: Icon(Icons.rate_review_outlined, color: _isDarkMode ? Colors.white54 : Colors.grey[500], size: 19),
                  onPressed: () => _requestParticipantEdit(p),
                ),
              if (canEditDirect)
                IconButton(
                  tooltip: 'Remove participant',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 19),
                  onPressed: () => _confirmDeleteParticipant(p),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteParticipant(QParticipant p) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove participant'),
        content: Text('Remove ${p.name} and their ${p.shares} share(s) from this plan\'s expense split? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _repo!.deleteParticipant(p.id);
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not remove participant: $error')));
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _addParticipantCard() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('＋ Add Participant', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
              InkWell(
                onTap: () {
                  setState(() {
                    _isOfflineFamilyMember = !_isOfflineFamilyMember;
                    _selectedDeenMateUser = null;
                    _userSearchResults.clear();
                    _participantNameCtrl.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isOfflineFamilyMember ? Colors.orange.withValues(alpha: 0.15) : AppColors.midTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isOfflineFamilyMember ? 'Offline Family Member' : 'DeenMate User Lookup',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _isOfflineFamilyMember ? Colors.orange[800] : AppColors.midTeal),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_isOfflineFamilyMember) ...[
            TextField(
              onChanged: _searchDeenMateUsers,
              style: GoogleFonts.inter(fontSize: 12, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search DeenMate user by name, email, phone...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white54 : null),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.midTeal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : null,
                filled: _isDarkMode,
              ),
            ),
            if (_isSearchingUsers) ...[
              const SizedBox(height: 8),
              const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            ] else if (_selectedDeenMateUser != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.midTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.midTeal),
                ),
                child: Row(
                  children: [
                    DeenMateAvatar(
                      name: _selectedDeenMateUser!['fullName'],
                      photoUrl: _selectedDeenMateUser!['photoUrl'],
                      avatarBase64: _selectedDeenMateUser!['avatarBase64'],
                      radius: 14,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_selectedDeenMateUser!['fullName'],
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => setState(() => _selectedDeenMateUser = null),
                    ),
                  ],
                ),
              ),
            ] else if (_userSearchResults.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.3)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _userSearchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final u = _userSearchResults[i];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDeenMateUser = u;
                          _userSearchResults.clear();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            DeenMateAvatar(name: u['fullName'], photoUrl: u['photoUrl'], avatarBase64: u['avatarBase64'], radius: 14),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                u['fullName'],
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ] else ...[
            TextField(
              controller: _participantNameCtrl,
              style: GoogleFonts.inter(fontSize: 12, color: textColor),
              decoration: InputDecoration(
                hintText: 'Participant Name (Family / Offline member)',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white54 : null),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : null,
                filled: _isDarkMode,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Shares:', style: GoogleFonts.inter(fontSize: 13, color: textColor)),
              Row(
                children: [
                  IconButton(onPressed: _newParticipantShares > 1 ? () => setState(() => _newParticipantShares--) : null, icon: const Icon(Icons.remove)),
                  Text('$_newParticipantShares', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
                  IconButton(onPressed: _newParticipantShares < 7 ? () => setState(() => _newParticipantShares++) : null, icon: const Icon(Icons.add)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              String name = '';
              String? photoUrl;
              String? avatarBase64;
              bool isDeenMateUser = false;
              String? uid;

              if (_selectedDeenMateUser != null) {
                name = _selectedDeenMateUser!['fullName'];
                photoUrl = _selectedDeenMateUser!['photoUrl'];
                avatarBase64 = _selectedDeenMateUser!['avatarBase64'];
                isDeenMateUser = true;
                uid = _selectedDeenMateUser!['uid'];
              } else {
                name = _participantNameCtrl.text.trim();
              }

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or type a participant name')));
                return;
              }
              try {
                await _repo!.addParticipantUser(
                  name: name,
                  shares: _newParticipantShares,
                  photoUrl: photoUrl,
                  avatarBase64: avatarBase64,
                  isDeenMateUser: isDeenMateUser,
                  uid: uid,
                );
                _participantNameCtrl.clear();
                setState(() {
                  _newParticipantShares = 1;
                  _selectedDeenMateUser = null;
                  _userSearchResults.clear();
                });
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add participant: $error')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.midTeal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Add Participant', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCurrentAvatar() async {
    final b64 = await QurbaniRepository.currentAvatarBase64();
    if (mounted && b64 != null) {
      setState(() => _myCurrentAvatarBase64 = b64);
    }
  }

  String _formatMessageDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(messageDate).inDays;

    if (diffDays == 0) {
      return 'Today';
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else if (diffDays < 7 && diffDays > 0) {
      return DateFormat('EEEE').format(date); // e.g. Monday
    } else if (date.year == now.year) {
      return DateFormat('MMMM d').format(date); // e.g. August 23
    } else {
      return DateFormat('MMMM d, yyyy').format(date); // e.g. August 23, 2026
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildGroupChatSection() {
    final myUid = QurbaniRepository.currentUid();
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Group Discussion', style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text('Real-time chat for updates, photos, videos & receipts.',
                  style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 11.5)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: StreamBuilder<List<QChatMessage>>(
            stream: _repo!.watchMessages(),
            builder: (context, snap) {
              final messages = snap.data ?? [];
              if (messages.isEmpty) {
                return Center(
                  child: Text('No messages yet. Start the conversation!', style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                );
              }
              return StreamBuilder<List<QPlanMember>>(
                stream: _repo!.watchMembers(),
                builder: (context, memberSnap) {
                  final members = memberSnap.data ?? [];
                  final memberAvatarMap = <String, String>{};
                  for (final m in members) {
                    if (m.avatarBase64 != null && m.avatarBase64!.isNotEmpty) {
                      memberAvatarMap[m.id] = m.avatarBase64!;
                    }
                  }

                  return ListView.builder(
                    controller: widget.scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = messages[i];
                      final isMe = msg.senderUid == myUid;
                      final bubbleColor = isMe ? AppColors.midTeal : (_isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0));

                      // Resolve live latest avatar:
                      // For current user: always use current live profile avatar _myCurrentAvatarBase64
                      // For other members: use live member avatar from group member record
                      final liveAvatar = isMe
                          ? (_myCurrentAvatarBase64 ?? msg.avatarBase64)
                          : (memberAvatarMap[msg.senderUid] ?? msg.avatarBase64);

                      // Messenger-style Date Header Check (reverse: true -> i+1 is previous chronologically)
                      final bool isFirstInDay = i == messages.length - 1 || !_isSameDay(messages[i].createdAt, messages[i + 1].createdAt);

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isFirstInDay)
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 14),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatMessageDateHeader(msg.createdAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: _isDarkMode ? Colors.white70 : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          GestureDetector(
                            onLongPress: isMe ? () => _showMessageOptions(msg) : null,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 6, left: isMe ? 48 : 0, right: isMe ? 0 : 48),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isMe) ...[
                                    DeenMateAvatar(name: msg.senderName, photoUrl: msg.photoUrl, avatarBase64: liveAvatar, radius: 13),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (!isMe)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4, bottom: 2),
                                            child: Text(msg.senderName, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                                          ),
                                        ClipRRect(
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                                          ),
                                          child: Container(
                                            color: bubbleColor,
                                            child: _buildChatMediaContent(msg, isMe, textColor),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (msg.edited == true)
                                                Text('edited · ', style: GoogleFonts.inter(fontSize: 8, color: Colors.grey)),
                                              Text(DateFormat('hh:mm a').format(msg.createdAt), style: GoogleFonts.inter(fontSize: 8.5, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    DeenMateAvatar(name: msg.senderName, photoUrl: QurbaniRepository.currentPhotoUrl(), avatarBase64: liveAvatar, radius: 13),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(
            color: cardBg,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Attach Image, Video or PDF',
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.midTeal, size: 26),
                onPressed: _showChatAttachmentOptions,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _chatMsgCtrl,
                    style: GoogleFonts.inter(fontSize: 13, color: textColor),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Aa',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: _isDarkMode ? Colors.white38 : Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: () async {
                  final text = _chatMsgCtrl.text.trim();
                  if (text.isEmpty) return;
                  _chatMsgCtrl.clear();
                  if (_editingMessageId != null) {
                    await _repo!.editMessage(_editingMessageId!, text);
                    setState(() => _editingMessageId = null);
                  } else {
                    await _repo!.sendMessage(text);
                  }
                },
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                style: IconButton.styleFrom(backgroundColor: AppColors.midTeal, padding: const EdgeInsets.all(10)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMessageOptions(QChatMessage msg) {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final isTextMsg = msg.text.isNotEmpty && (msg.mediaType.isEmpty || msg.mediaType == 'text');
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
          if (isTextMsg)
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.midTeal),
              title: Text('Edit Message', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _editingMessageId = msg.id;
                  _chatMsgCtrl.text = msg.text;
                });
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            title: Text('Delete Message', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await _repo!.deleteMessage(msg.id);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.close_rounded, color: Colors.grey),
            title: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
            onTap: () => Navigator.pop(ctx),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<void> _openVideoNative(QChatMessage msg) async {
    if (msg.mediaData != null && msg.mediaData!.isNotEmpty && !msg.mediaData!.startsWith('data:')) {
      final file = File(msg.mediaData!);
      if (await file.exists()) {
        try {
          final res = await OpenFilex.open(msg.mediaData!);
          if (res.type == ResultType.done) return;
        } catch (_) {}
      }
    }
    _openVideoPreview(msg);
  }

  Future<void> _openDocumentNative(QChatMessage msg) async {
    if (msg.mediaData != null && msg.mediaData!.isNotEmpty && !msg.mediaData!.startsWith('doc_file')) {
      final file = File(msg.mediaData!);
      if (await file.exists()) {
        try {
          final res = await OpenFilex.open(msg.mediaData!);
          if (res.type == ResultType.done) return;
        } catch (_) {}
      }
    }
    _openDocumentPreview(msg);
  }

  Widget _buildChatMediaContent(QChatMessage msg, bool isMe, Color textColor) {
    final contentColor = isMe ? Colors.white : textColor;

    // --- IMAGE ---
    if (msg.mediaType == 'image' && msg.mediaData != null && msg.mediaData!.isNotEmpty) {
      try {
        final bytes = base64Decode(msg.mediaData!);
        return GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              child: InteractiveViewer(
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes, fit: BoxFit.contain)),
              ),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240, maxHeight: 220, minWidth: 80),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        );
      } catch (_) {
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Text('[Image]', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: contentColor.withValues(alpha: 0.7))),
        );
      }
    }

    // --- VIDEO ---
    if (msg.mediaType == 'video') {
      return GestureDetector(
        onTap: () => _openVideoNative(msg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: isMe ? 0.3 : 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg.fileName ?? 'Video', overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: contentColor)),
                    Text('Tap to play', style: GoogleFonts.inter(fontSize: 10, color: contentColor.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- DOCUMENT / PDF ---
    if (msg.mediaType == 'document') {
      return GestureDetector(
        onTap: () => _openDocumentNative(msg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: isMe ? 0.3 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg.fileName ?? 'Document.pdf', overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: contentColor)),
                    Text('Tap to open', style: GoogleFonts.inter(fontSize: 10, color: contentColor.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- TEXT ---
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (msg.text.isNotEmpty)
            Text(msg.text, style: GoogleFonts.inter(fontSize: 14, color: contentColor, height: 1.35)),
        ],
      ),
    );
  }

  void _showChatAttachmentOptions() {
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send Attachment',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 14),
              // Camera photo
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.midTeal.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.midTeal),
                ),
                title: Text('Take a photo',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
                subtitle: Text('Use camera',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: textColor.withValues(alpha: .55))),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final file = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 70,
                      maxWidth: 1024);
                  if (file != null) {
                    final bytes = await file.readAsBytes();
                    final b64 = base64Encode(bytes);
                    await _repo!.sendMediaMessage(
                        mediaType: 'image', mediaData: b64, fileName: file.name);
                  }
                },
              ),
              // Gallery image
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: Colors.purple),
                ),
                title: Text('Choose from gallery',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
                subtitle: Text('JPG, PNG, GIF…',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: textColor.withValues(alpha: .55))),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final file = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                      maxWidth: 1024);
                  if (file != null) {
                    final bytes = await file.readAsBytes();
                    final b64 = base64Encode(bytes);
                    await _repo!.sendMediaMessage(
                        mediaType: 'image', mediaData: b64, fileName: file.name);
                  }
                },
              ),
              // Document / PDF
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insert_drive_file_rounded,
                      color: Colors.orange),
                ),
                title: Text('Send document',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
                subtitle: Text('PDF, DOCX, TXT, XLSX…',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: textColor.withValues(alpha: .55))),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: [
                        'pdf',
                        'doc',
                        'docx',
                        'txt',
                        'xlsx',
                        'xls',
                        'ppt',
                        'pptx'
                      ],
                      withData: true,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      final file = result.files.first;
                      String? base64Str;
                      if (file.bytes != null) {
                        base64Str = base64Encode(file.bytes!);
                      } else if (file.path != null) {
                        base64Str =
                            base64Encode(await File(file.path!).readAsBytes());
                      }
                      await _repo!.sendMediaMessage(
                          mediaType: 'document',
                          mediaData: base64Str ?? 'doc_file',
                          fileName: file.name);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sent: ${file.name}')));
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Could not attach file: $e')));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  




  void _openVideoPreview(QChatMessage msg) {
    final dialogBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.videocam_rounded, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(msg.fileName ?? 'Video Attachment', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: textColor))),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 48),
                    const SizedBox(height: 8),
                    Text('Video Player Preview', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                    Text('Uploaded by ${msg.senderName}', style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal, foregroundColor: Colors.white),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDocumentPreview(QChatMessage msg) {
    final dialogBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor = _isDarkMode ? Colors.white70 : Colors.grey[600];

    final hasImageBytes = msg.mediaData != null && msg.mediaData!.isNotEmpty && msg.mediaData != 'doc_file';
    Uint8List? imageBytes;
    if (hasImageBytes) {
      try {
        imageBytes = base64Decode(msg.mediaData!);
      } catch (e) {
        imageBytes = null;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      msg.fileName ?? 'Document / Receipt.pdf',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.midTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppColors.midTeal, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Verified Qurbani Receipt / Document',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text('Sent by: ${msg.senderName}', style: GoogleFonts.inter(fontSize: 11.5, color: subtextColor)),
              Text('Date: ${DateFormat('MMM dd, yyyy · hh:mm a').format(msg.createdAt)}', style: GoogleFonts.inter(fontSize: 10.5, color: subtextColor)),
              if (imageBytes != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    imageBytes,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 90,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 32),
                            const SizedBox(height: 4),
                            Text('PDF Document Attached', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white70 : Colors.red[800])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          if (imageBytes != null) {
                            final tempDir = Directory.systemTemp;
                            final fileName = msg.fileName ?? 'qurbani_doc.pdf';
                            final file = File('${tempDir.path}/$fileName');
                            await file.writeAsBytes(imageBytes);
                            final openResult = await OpenFilex.open(file.path);
                            if (openResult.type != ResultType.done) {
                              final pdf = pw.Document();
                              pdf.addPage(
                                pw.Page(
                                  build: (pw.Context pCtx) => pw.Center(
                                    child: pw.Column(
                                      mainAxisAlignment: pw.MainAxisAlignment.center,
                                      children: [
                                        pw.Text(msg.fileName ?? 'Qurbani Receipt Document', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                                        pw.SizedBox(height: 10),
                                        pw.Text('Shared by: ${msg.senderName}', style: const pw.TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: fileName);
                            }
                          } else {
                            final pdf = pw.Document();
                            pdf.addPage(
                              pw.Page(
                                build: (pw.Context pCtx) => pw.Center(
                                  child: pw.Column(
                                    mainAxisAlignment: pw.MainAxisAlignment.center,
                                    children: [
                                      pw.Text(msg.fileName ?? 'Qurbani Receipt Document', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                                      pw.SizedBox(height: 12),
                                      pw.Text('Shared by: ${msg.senderName}', style: const pw.TextStyle(fontSize: 13)),
                                      pw.Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(msg.createdAt)}', style: const pw.TextStyle(fontSize: 11)),
                                      pw.SizedBox(height: 20),
                                      pw.Text('Verified Official Qurbani Document / Receipt', style: pw.TextStyle(fontSize: 12, color: PdfColors.teal)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: msg.fileName ?? 'Qurbani_Document.pdf');
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text('Open File App', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                    child: Text('Close', style: GoogleFonts.inter(color: textColor, fontSize: 11.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareBoardTab(NumberFormat fmt) {
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final myUid = QurbaniRepository.currentUid();

    return StreamBuilder<List<QurbaniSharePost>>(
      stream: QShareBoardRepository.watchPosts(),
      builder: (context, snap) {
        final posts = snap.data ?? [];

        final myUidForFilter = QurbaniRepository.currentUid();
        final filteredPosts = posts.where((post) {
          final isOwnerOfPost = post.posterUid == myUidForFilter;

          // 1. Hide post for user if they have already joined this post's group
          if (!isOwnerOfPost && _repo != null && post.planId != null && _repo!.planId == post.planId) {
            return false;
          }

          // 2. For non-poster viewers: hide posts that are closed/matched/filled
          if (!isOwnerOfPost) {
            if (post.status == 'closed' ||
                post.status == 'matched' ||
                post.availableShares <= 0) {
              return false;
            }
          }

          // 3. Real-Time Proximity Filter (Nearby Discovery)
          if (isOwnerOfPost) return true;
          if (_selectedMaxDistanceKm >= 9990) return true;
          if (_currentUserPosition == null) return true;
          final distMeters = Geolocator.distanceBetween(
            _currentUserPosition!.latitude,
            _currentUserPosition!.longitude,
            post.latitude,
            post.longitude,
          );
          return (distMeters / 1000.0) <= _selectedMaxDistanceKm;
        }).toList();

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qurbani Share Board', style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 15.5)),
                      Text('Connect with people nearby looking to share Qurbani animals.',
                          style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 11.5)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (_repo == null) {
                      final shouldCreate = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: Row(
                            children: [
                              const Icon(Icons.group_add_rounded, color: AppColors.midTeal, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Qurbani Group Required',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          content: Text(
                            'You need an active Qurbani planning group before posting a share offer. This allows interested users to receive your group code and join your group once you accept them.\n\nWould you like to create your Qurbani group now?',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.45,
                              color: _isDarkMode ? Colors.white70 : Colors.grey[700],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  color: _isDarkMode ? Colors.white60 : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.midTeal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Create Group Now'),
                            ),
                          ],
                        ),
                      );
                      if (shouldCreate == true) {
                        try {
                          final newRepo = await QurbaniRepository.createGroup();
                          if (mounted) {
                            setState(() => _repo = newRepo);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('🎉 Qurbani group created! Now you can publish your share post.')),
                            );
                            _showCreatePostSheet();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not create group: $e')),
                            );
                          }
                        }
                      }
                    } else {
                      _showCreatePostSheet();
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: Text('Post', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.near_me_rounded, color: AppColors.midTeal, size: 16),
                      const SizedBox(width: 6),
                      Text('Proximity Filter', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          _selectedMaxDistanceKm >= 9999 ? 'All Distance' : '< ${_selectedMaxDistanceKm.round()} km',
                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _distanceChip('< 5 km', 5.0),
                        const SizedBox(width: 6),
                        _distanceChip('< 10 km', 10.0),
                        const SizedBox(width: 6),
                        _distanceChip('< 25 km', 25.0),
                        const SizedBox(width: 6),
                        _distanceChip('< 50 km', 50.0),
                        const SizedBox(width: 6),
                        _distanceChip('All', 9999.0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (filteredPosts.isEmpty)
              _emptyState('No share posts found nearby for the selected range. Be the first to post a share request!')
            else
              ...filteredPosts.map((post) => _sharePostCard(post, myUid, fmt)),
          ],
        );
      },
    );
  }

  Widget _distanceChip(String label, double km) {
    final active = _selectedMaxDistanceKm == km;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: active ? Colors.white : (_isDarkMode ? Colors.white70 : Colors.black87))),
      selected: active,
      selectedColor: AppColors.midTeal,
      backgroundColor: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[200],
      onSelected: (_) => setState(() => _selectedMaxDistanceKm = km),
    );
  }

  Widget _sharePostCard(QurbaniSharePost post, String myUid, NumberFormat fmt) {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final isMyPost = post.posterUid == myUid;

    String distanceLabel = 'Distance unknown';
    if (_currentUserPosition != null) {
      final meters = Geolocator.distanceBetween(
        _currentUserPosition!.latitude,
        _currentUserPosition!.longitude,
        post.latitude,
        post.longitude,
      );
      final km = meters / 1000.0;
      distanceLabel = km < 1.0 ? '${meters.round()} meters away' : '${km.toStringAsFixed(1)} km away';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: post.status == 'matched' || post.status == 'closed' ? Colors.grey : AppColors.midTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DeenMateAvatar(name: post.posterName, photoUrl: post.photoUrl, avatarBase64: post.avatarBase64, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.posterName.isNotEmpty ? post.posterName : 'Share Poster',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: AppColors.midTeal),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '${post.locationName} · $distanceLabel',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: GoogleFonts.inter(fontSize: 10.5, color: _isDarkMode ? Colors.white60 : Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: post.status == 'matched' || post.status == 'closed' ? Colors.grey.withValues(alpha: 0.2) : AppColors.midTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  post.animalType.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: post.status == 'matched' || post.status == 'closed' ? Colors.grey : AppColors.midTeal),
                ),
              ),
              if (isMyPost) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Delete Post?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
                        content: Text(
                          'This will permanently remove your share post and all responses to it. This cannot be undone.',
                          style: GoogleFonts.inter(fontSize: 13, color: _isDarkMode ? Colors.white70 : Colors.grey[700]),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try {
                        await QShareBoardRepository.deletePost(post.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Post deleted.')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not delete: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 16),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(post.description.isNotEmpty ? post.description : 'Looking for Qurbani share partners.',
              style: GoogleFonts.inter(fontSize: 12, color: textColor, height: 1.35)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Available: ${post.availableShares} / ${post.totalShares} Share(s)',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _isDarkMode ? Colors.white70 : Colors.grey[700])),
              Text('৳${fmt.format(post.costPerShare)} / share',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
            ],
          ),
          const SizedBox(height: 12),
          if (isMyPost) ...[
            StreamBuilder<List<QShareResponse>>(
              stream: QShareBoardRepository.watchResponses(post.id),
              builder: (ctx, rSnap) {
                final responses = rSnap.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text('Interested Responses (${responses.length}):',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11.5, color: textColor)),
                    const SizedBox(height: 6),
                    if (responses.isEmpty)
                      Text('No responses yet.', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey))
                    else
                      ...responses.map((resp) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _isDarkMode ? Colors.white12 : Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                DeenMateAvatar(name: resp.responderName, photoUrl: resp.photoUrl, avatarBase64: resp.avatarBase64, radius: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${resp.responderName} (${resp.sharesRequested} share${resp.sharesRequested > 1 ? "s" : ""})',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                                      ),
                                      if (resp.note.isNotEmpty)
                                        Text(resp.note, style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                if (resp.status == 'accepted')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                                    child: Text('Accepted', style: GoogleFonts.inter(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                  )
                                else if (resp.status == 'joined')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                    child: Text('Joined Group', style: GoogleFonts.inter(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                                  )
                                else if (resp.status == 'rejected')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                    child: Text('Declined', style: GoogleFonts.inter(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                                  )
                                else if (resp.status == 'filled' || post.availableShares <= 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.block_rounded, color: Colors.orange, size: 11),
                                        const SizedBox(width: 3),
                                        Text('Group Full', style: GoogleFonts.inter(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (resp.status == 'pending' && post.availableShares > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Reject Button
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      String selectedReason = 'Group shares are already filled';
                                      final customReasonCtrl = TextEditingController();

                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogCtx) => StatefulBuilder(
                                          builder: (dialogCtx, setDialogState) => AlertDialog(
                                            backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                            title: Text(
                                              'Decline Request?',
                                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Select a reason for declining ${resp.responderName}\'s request:',
                                                  style: GoogleFonts.inter(fontSize: 12.5, color: _isDarkMode ? Colors.white70 : Colors.grey[700]),
                                                ),
                                                const SizedBox(height: 12),
                                                DropdownButtonFormField<String>(
                                                  value: selectedReason,
                                                  isExpanded: true,
                                                  dropdownColor: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                                                  style: GoogleFonts.inter(color: textColor, fontSize: 12),
                                                  decoration: InputDecoration(
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  ),
                                                  items: const [
                                                    DropdownMenuItem(value: 'Group shares are already filled', child: Text('Shares already filled')),
                                                    DropdownMenuItem(value: 'Location is too far', child: Text('Location is too far')),
                                                    DropdownMenuItem(value: 'Requested share count mismatch', child: Text('Requested share count mismatch')),
                                                    DropdownMenuItem(value: 'Other reason', child: Text('Other reason')),
                                                  ],
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setDialogState(() => selectedReason = val);
                                                    }
                                                  },
                                                ),
                                                if (selectedReason == 'Other reason') ...[
                                                  const SizedBox(height: 10),
                                                  TextField(
                                                    controller: customReasonCtrl,
                                                    style: GoogleFonts.inter(color: textColor, fontSize: 12),
                                                    decoration: InputDecoration(
                                                      hintText: 'Type reason here...',
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(dialogCtx, false),
                                                child: Text('Cancel', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(dialogCtx, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                child: const Text('Decline'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );

                                      if (confirmed == true) {
                                        final reason = selectedReason == 'Other reason' && customReasonCtrl.text.trim().isNotEmpty
                                            ? customReasonCtrl.text.trim()
                                            : selectedReason;
                                        try {
                                          await QShareBoardRepository.rejectResponse(
                                            postId: post.id,
                                            responseId: resp.id,
                                            reason: reason,
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Declined request from ${resp.responderName}.')),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Could not decline request: $e')),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                                    label: const Text('Decline', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(0, 30),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Accept Button with Explicit Confirmation Dialog
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      if (_repo == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please create or load your Qurbani group first.')),
                                        );
                                        return;
                                      }

                                      // Confirmation Dialog
                                      final shouldAccept = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                          title: Text(
                                            'Add DeenMate User?',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Are you sure you want to add this DeenMate user in your Qurbani planning group?',
                                                style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: _isDarkMode ? Colors.white70 : Colors.grey[800]),
                                              ),
                                              const SizedBox(height: 10),
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: AppColors.midTeal.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.25)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    DeenMateAvatar(name: resp.responderName, photoUrl: resp.photoUrl, avatarBase64: resp.avatarBase64, radius: 14),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(resp.responderName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: textColor)),
                                                          Text('${resp.sharesRequested} share(s) requested', style: GoogleFonts.inter(fontSize: 11, color: AppColors.midTeal)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text('Cancel', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.midTeal,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              child: const Text('Yes, Add & Share Code'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (shouldAccept == true) {
                                        try {
                                          // Validate group capacity
                                          final pSnap = await _repo!.participantsRef.get();
                                          final currentAssigned = pSnap.docs.fold<int>(0, (total, d) => total + ((d.data()['shares'] as num?)?.toInt() ?? 0));
                                          final planDoc = await _repo!.planRef.get();
                                          final animalType = (planDoc.data()?['animalType'] as String?) ?? 'cow';
                                          final cap = QurbaniRepository._animalShareCaps[animalType] ?? 7;

                                          if (currentAssigned + resp.sharesRequested > cap) {
                                            final remaining = math.max(0, cap - currentAssigned);
                                            throw Exception('Cannot accept: Only $remaining share(s) remaining in your group (Maximum $cap shares for $animalType).');
                                          }

                                          // Get or generate invite code
                                          final code = await _repo!.getInviteCode() ?? await _repo!.createInviteCode();

                                          // Automatically add responder as a participant in the owner's group
                                          await _repo!.addParticipantUser(
                                            name: resp.responderName,
                                            shares: resp.sharesRequested,
                                            isDeenMateUser: true,
                                            uid: resp.responderUid,
                                            photoUrl: resp.photoUrl,
                                            avatarBase64: resp.avatarBase64,
                                          );

                                          // Send code to responder and update post remaining shares
                                          await QShareBoardRepository.acceptAndSendCode(
                                            post: post,
                                            response: resp,
                                            inviteCode: code,
                                          );

                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('🎉 Accepted! ${resp.responderName} added to your group and invite code shared.')),
                                            );
                                          }
                                        } catch (err) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Could not accept: $err')),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.check_circle_rounded, size: 14),
                                    label: const Text('Accept & Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.midTeal,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(0, 30),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      )),
                  ],
                );
              },
            ),
          ] else ...[
            // Check if current user already responded
            StreamBuilder<List<QShareResponse>>(
              stream: QShareBoardRepository.watchResponses(post.id),
              builder: (ctx, rSnap) {
                final responses = rSnap.data ?? [];
                final myUidLocal = QurbaniRepository.currentUid();
                final alreadyResponded = responses.any((r) => r.responderUid == myUidLocal);
                final myResponse = alreadyResponded ? responses.firstWhere((r) => r.responderUid == myUidLocal) : null;
                if (alreadyResponded) {
                  final status = myResponse?.status ?? 'pending';
                  if (status == 'joined') {
                    return const SizedBox.shrink();
                  }
                  final isAccepted = status == 'accepted';
                  final isFilled = status == 'filled';
                  final isRejected = status == 'rejected';

                  final bgColor = isAccepted
                      ? Colors.green.withValues(alpha: 0.1)
                      : (isFilled
                          ? Colors.orange.withValues(alpha: 0.1)
                          : (isRejected
                              ? Colors.red.withValues(alpha: 0.1)
                              : (_isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100])));

                  final borderColor = isAccepted
                      ? Colors.green.withValues(alpha: 0.4)
                      : (isFilled
                          ? Colors.orange.withValues(alpha: 0.4)
                          : (isRejected
                              ? Colors.red.withValues(alpha: 0.4)
                              : Colors.grey.withValues(alpha: 0.3)));

                  final iconData = isAccepted
                      ? Icons.check_circle_rounded
                      : (isFilled
                          ? Icons.info_outline_rounded
                          : (isRejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded));

                  final iconColor = isAccepted
                      ? Colors.green
                      : (isFilled
                          ? Colors.orange
                          : (isRejected ? Colors.red : AppColors.midTeal));

                  final statusMessage = isAccepted
                      ? '🎉 Accepted for ${myResponse?.sharesRequested} share(s)! Tap below to join the group.'
                      : (isFilled
                          ? 'Group Shares Filled — The poster allocated the remaining shares.'
                          : (isRejected
                              ? 'Request Declined: ${myResponse?.rejectReason ?? "Poster declined your request."}'
                              : 'Request sent (${myResponse?.sharesRequested} share${myResponse?.sharesRequested != 1 ? "s" : ""}) — waiting for poster to accept.'));

                  final inviteCode = myResponse?.inviteCode;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(iconData, color: iconColor, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusMessage,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: isAccepted ? FontWeight.w600 : FontWeight.normal,
                                  color: isAccepted
                                      ? (_isDarkMode ? Colors.green[300] : Colors.green[800])
                                      : (isFilled
                                          ? (_isDarkMode ? Colors.orange[300] : Colors.orange[900])
                                          : (isRejected
                                              ? (_isDarkMode ? Colors.red[300] : Colors.red[800])
                                              : (_isDarkMode ? Colors.white70 : Colors.grey[700]))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isAccepted && inviteCode != null && inviteCode.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.midTeal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Group Invite Code', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      inviteCode,
                                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.midTeal, letterSpacing: 2),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: inviteCode));
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!')));
                                    },
                                    icon: const Icon(Icons.copy_rounded, color: AppColors.midTeal, size: 18),
                                    tooltip: 'Copy code',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final repo = await QurbaniRepository.joinByCode(inviteCode, myResponse!.sharesRequested);
                                      if (mounted) setState(() => _repo = repo);
                                      await QShareBoardRepository.markResponseJoined(post.id, myResponse.id);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('🎉 Joined the Qurbani group!')),
                                        );
                                        setState(() => _tab = 2);
                                      }
                                    } catch (e) {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not join: $e')));
                                    }
                                  },
                                  icon: const Icon(Icons.group_add_rounded, size: 15),
                                  label: Text('Join Group Now', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.midTeal,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(36),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                }
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: post.status == 'matched' || post.status == 'closed' || post.availableShares <= 0 ? null : () => _showRespondSheet(post),
                    icon: const Icon(Icons.handshake_rounded, size: 16),
                    label: Text(post.status == 'matched' || post.status == 'closed' || post.availableShares <= 0 ? 'Share Completed' : 'Respond / Request Share'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(38)),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showCreatePostSheet() {
    String animal = 'cow';
    int totalShares = 7;
    int availShares = 2;
    final costCtrl = TextEditingController(text: '20000');
    // Pre-fill location from GPS reverse geocoding or leave empty for user to type specific area
    final locCtrl = TextEditingController(text: '');
    final descCtrl = TextEditingController(text: 'Looking for 2 share partners for a healthy cow Qurbani.');
    // Reverse geocode current location to pre-fill
    if (_currentUserPosition != null) {
      _reverseGeocodeToArea(_currentUserPosition!.latitude, _currentUserPosition!.longitude).then((area) {
        if (locCtrl.text.isEmpty) locCtrl.text = area;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Post Qurbani Share Request / Offer', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Animal Type: ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white70 : Colors.black87)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: animal,
                    dropdownColor: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                    style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.black87, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'cow', child: Text('Cow (7 shares max)')),
                      DropdownMenuItem(value: 'camel', child: Text('Camel (7 shares max)')),
                      DropdownMenuItem(value: 'buffalo', child: Text('Buffalo (7 shares max)')),
                      DropdownMenuItem(value: 'goat', child: Text('Goat (1 share max)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setD(() {
                          animal = val;
                          totalShares = val == 'goat' ? 1 : 7;
                          availShares = 1;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Available Shares to Fill:', style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white70 : Colors.black87)),
                  Row(
                    children: [
                      IconButton(onPressed: availShares > 1 ? () => setD(() => availShares--) : null, icon: const Icon(Icons.remove)),
                      Text('$availShares', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87)),
                      IconButton(onPressed: availShares < totalShares ? () => setD(() => availShares++) : null, icon: const Icon(Icons.add)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.black87),
                decoration: const InputDecoration(labelText: 'Estimated Cost Per Share (BDT)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locCtrl,
                style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.black87),
                decoration: const InputDecoration(labelText: 'Location / Area Name (e.g. Dhanmondi, Dhaka)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.black87),
                decoration: const InputDecoration(labelText: 'Description / Notes'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final cost = double.tryParse(costCtrl.text) ?? 0.0;
                    if (cost <= 0) return;
                    final lat = _currentUserPosition?.latitude ?? 23.8103;
                    final lng = _currentUserPosition?.longitude ?? 90.4125;
                    try {
                      await QShareBoardRepository.createPost(
                        animalType: animal,
                        totalShares: totalShares,
                        availableShares: availShares,
                        costPerShare: cost,
                        locationName: locCtrl.text.trim(),
                        latitude: lat,
                        longitude: lng,
                        description: descCtrl.text.trim(),
                        planId: _repo?.planId,
                        planOwnerUid: _repo?.ownerUid,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share Post published nearby!')));
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Could not post: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal, foregroundColor: Colors.white),
                  child: const Text('Publish Share Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRespondSheet(QurbaniSharePost post) {
    int requestedShares = 1;
    final noteCtrl = TextEditingController();
    bool isSubmitting = false; // UI guard: prevent double-tap

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Respond to ${post.posterName}\'s Post', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Shares Requested:', style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white70 : Colors.black87)),
                  Row(
                    children: [
                      IconButton(onPressed: (!isSubmitting && requestedShares > 1) ? () => setD(() => requestedShares--) : null, icon: const Icon(Icons.remove)),
                      Text('$requestedShares', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87)),
                      IconButton(onPressed: (!isSubmitting && requestedShares < post.availableShares) ? () => setD(() => requestedShares++) : null, icon: const Icon(Icons.add)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                enabled: !isSubmitting,
                style: GoogleFonts.inter(color: _isDarkMode ? Colors.white : Colors.black87),
                decoration: const InputDecoration(labelText: 'Message to poster (optional)'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    setD(() => isSubmitting = true); // Disable button immediately
                    try {
                      await QShareBoardRepository.respondToPost(
                        postId: post.id,
                        sharesRequested: requestedShares,
                        note: noteCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response sent to poster!')));
                    } catch (e) {
                      // Re-enable on error so user can correct and retry
                      if (ctx.mounted) {
                        setD(() => isSubmitting = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString().contains('already responded')
                            ? 'You have already responded to this post.'
                            : 'Could not send response: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal, foregroundColor: Colors.white),
                  child: isSubmitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send Response'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editParticipantDirect(QParticipant p) {
    final nameCtrl = TextEditingController(text: p.name);
    int shares = p.shares;

    final dialogBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final inputBg = _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50];
    final borderSide = BorderSide(color: _isDarkMode ? Colors.white24 : Colors.grey[300]!);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.person_outline_rounded, color: AppColors.midTeal, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Edit Participant', style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.bold, color: textColor))),
                  ],
                ),
                const SizedBox(height: 16),
                Text('NAME', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.inter(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.midTeal, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                Text('SHARES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: shares > 1 ? () => setD(() => shares--) : null,
                      icon: Icon(Icons.remove_circle_outline_rounded, color: shares > 1 ? AppColors.midTeal : Colors.grey),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _isDarkMode ? Colors.white24 : Colors.grey[300]!)),
                      child: Text('$shares share(s)', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    IconButton(
                      onPressed: shares < 7 ? () => setD(() => shares++) : null,
                      icon: Icon(Icons.add_circle_outline_rounded, color: shares < 7 ? AppColors.midTeal : Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(side: borderSide, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text('Cancel', style: GoogleFonts.inter(color: textColor, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        try {
                          await _repo!.updateParticipantDirect(p.id, name: name, shares: shares);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (error) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Could not save: $error')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editExpenseDirect(QExpense e) {
    final categoryCtrl = TextEditingController(text: e.category);
    final amountCtrl = TextEditingController(text: e.amount.toStringAsFixed(0));
    final notesCtrl = TextEditingController(text: e.notes);

    final dialogBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final inputBg = _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50];
    final borderSide = BorderSide(color: _isDarkMode ? Colors.white24 : Colors.grey[300]!);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.midTeal, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Edit Expense', style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.bold, color: textColor))),
                ],
              ),
              const SizedBox(height: 16),
              Text('CATEGORY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              TextField(
                controller: categoryCtrl,
                style: GoogleFonts.inter(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.midTeal, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Text('AMOUNT (BDT)', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.midTeal, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Text('NOTES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                style: GoogleFonts.inter(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.midTeal, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(side: borderSide, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: Text('Cancel', style: GoogleFonts.inter(color: textColor, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final category = categoryCtrl.text.trim();
                      final amount = double.tryParse(amountCtrl.text) ?? e.amount;
                      if (category.isEmpty || amount <= 0) return;
                      try {
                        await _repo!.expensesRef.doc(e.id).update({
                          'category': category,
                          'amount': amount,
                          'notes': notesCtrl.text.trim(),
                        });
                        await _repo!.recalcAndSyncBalances();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (error) {
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Could not save: $error')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.midTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _requestParticipantEdit(QParticipant p) {
    final nameCtrl = TextEditingController(text: p.name);
    final reasonCtrl = TextEditingController();
    int shares = p.shares;

    final dialogBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor = _isDarkMode ? Colors.white70 : Colors.grey[600];
    final inputBg = _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50];
    final borderSide = BorderSide(color: _isDarkMode ? Colors.white24 : Colors.grey[300]!);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.edit_note_rounded, color: AppColors.midTeal, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Request Edit', style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.bold, color: textColor))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Only ${p.ownerName} can edit this directly. Propose your changes below.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: subtextColor, height: 1.3),
                ),
                const SizedBox(height: 16),
                Text('PROPOSED NAME', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.inter(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.midTeal, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('PROPOSED SHARES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: shares > 1 ? () => setD(() => shares--) : null,
                      icon: Icon(Icons.remove_circle_outline_rounded, color: shares > 1 ? AppColors.midTeal : Colors.grey),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _isDarkMode ? Colors.white24 : Colors.grey[300]!)),
                      child: Text('$shares share(s)', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    IconButton(
                      onPressed: shares < 7 ? () => setD(() => shares++) : null,
                      icon: Icon(Icons.add_circle_outline_rounded, color: shares < 7 ? AppColors.midTeal : Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('REASON (REQUIRED)', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  style: GoogleFonts.inter(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputBg,
                    hintText: 'Explain why this edit is needed...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.midTeal, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(side: borderSide, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text('Cancel', style: GoogleFonts.inter(color: textColor, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        if (reasonCtrl.text.trim().isEmpty) return;
                        try {
                          await _repo!.submitEditRequest(
                            type: QEditTargetType.participant,
                            targetId: p.id,
                            targetLabel: p.name,
                            reason: reasonCtrl.text.trim(),
                            proposedChanges: {'name': nameCtrl.text.trim(), 'shares': shares},
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (error) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Could not send request: $error')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text('Send request', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Expenses -------------------------------------------------------------
  Widget _buildExpensesSection(NumberFormat fmt) {
    final myUid = QurbaniRepository.currentUid();
    return StreamBuilder<List<QParticipant>>(
      stream: _repo!.watchParticipants(),
      builder: (context, pSnap) {
        final participants = pSnap.data ?? [];
        return StreamBuilder<List<QExpense>>(
          stream: _repo!.watchExpenses(),
          builder: (context, eSnap) {
            final expenses = eSnap.data ?? [];
            final total = expenses.fold<double>(0, (s, e) => s + e.amount);
            return ListView(
              controller: widget.scrollController,
              padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).padding.bottom + 90),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expenses', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15.5)),
                          Text(
                            "Every contribution or cost is logged here. If more than one person paid for the same thing — even unequally — add each as a payer on one entry. The person who logs it owns it; others can request an edit.",
                            style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.navyBlue, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total logged', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                      Text('৳${fmt.format(total)}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (participants.isEmpty)
                  _emptyState('Add participants first, then log expenses against them.')
                else if (expenses.isEmpty)
                  _emptyState('No expenses logged yet.')
                else
                  ...expenses.map((e) => _expenseCard(e, participants, myUid, fmt)),
                const SizedBox(height: 16),
                if (participants.isNotEmpty) _addExpenseCard(participants),
                const SizedBox(height: 20),
                _buildYearlyExpenseArchiveSection(fmt, expenses),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildYearlyExpenseArchiveSection(NumberFormat fmt, List<QExpense> currentExpenses) {
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final currentYear = DateTime.now().year;
    final isOwner = _repo!.ownerUid == QurbaniRepository.currentUid();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: AppColors.midTeal, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Yearly Expense Archive',
                  style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            if (!isOwner)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (_isDarkMode ? Colors.white10 : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Owner only', style: GoogleFonts.inter(fontSize: 10, color: _isDarkMode ? Colors.white54 : Colors.grey[600])),
              ),
            if (isOwner)
            ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Archive $currentYear Qurbani Expenses?'),
                    content: Text(
                      'This will save a permanent snapshot of your $currentYear Qurbani costs and breakdown to your history archive.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal, foregroundColor: Colors.white),
                        child: const Text('Archive Year'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final total = currentExpenses.fold<double>(0, (s, e) => s + e.amount);
                  final animal = await _repo!.getAnimalType();
                  final shares = await _repo!.getTotalShares();
                  final perShare = shares > 0 ? total / shares : 0.0;
                  try {
                    await _repo!.archiveCurrentYear(
                      year: currentYear,
                      totalCost: total,
                      animalType: animal,
                      totalShares: shares,
                      costPerShare: perShare,
                      expenses: currentExpenses,
                    );
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$currentYear Qurbani expenses archived!')));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not archive: $e')));
                  }
                }
              },
              icon: const Icon(Icons.bookmark_add_rounded, size: 14),
              label: Text('Archive $currentYear', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _repo!.watchYearlyArchive(),
          builder: (ctx, snap) {
            final archives = snap.data ?? [];
            if (archives.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Text('No archived years yet. Tap "Archive $currentYear" above to save this year\'s expenses to history!',
                    style: GoogleFonts.inter(fontSize: 11.5, color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
              );
            }
            return Column(
              children: archives.map((arc) {
                final yr = arc['year'] ?? 2026;
                final totalCost = (arc['totalCost'] as num?)?.toDouble() ?? 0.0;
                final animalType = (arc['animalType'] as String?) ?? 'cow';
                final totalShares = (arc['totalShares'] as num?)?.toInt() ?? 7;
                final costPerShare = (arc['costPerShare'] as num?)?.toDouble() ?? 0.0;
                final expList = (arc['expenses'] as List<dynamic>?) ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.navyBlue, borderRadius: BorderRadius.circular(6)),
                                child: Text('Qurbani $yr', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                              Text('${animalType.toString().toUpperCase()} ($totalShares shares)',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11.5, color: textColor)),
                            ],
                          ),
                          Text('৳${fmt.format(totalCost)}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.coralOrange)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Cost per share: ৳${fmt.format(costPerShare)}',
                          style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
                      if (expList.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        ...expList.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('• ${item['category']}', style: GoogleFonts.inter(fontSize: 11, color: textColor)),
                                  Text('৳${fmt.format(item['amount'])}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.midTeal)),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _expenseCard(QExpense e, List<QParticipant> participants, String myUid, NumberFormat fmt) {
    final isOwner = e.ownerId == myUid;
    String payerNames = e.payers.map((p) {
      final match = participants.where((x) => x.id == p.participantId);
      final name = match.isEmpty ? 'Unknown' : match.first.name;
      return e.payers.length > 1 ? '$name (৳${fmt.format(p.amount)})' : name;
    }).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.payment, color: AppColors.midTeal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.category, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _isDarkMode ? Colors.white : null)),
                Text('Paid by: $payerNames', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white54 : Colors.grey[600], fontSize: 10)),
                if (e.notes.isNotEmpty) Text(e.notes, style: GoogleFonts.inter(color: _isDarkMode ? Colors.white38 : Colors.grey[500], fontSize: 10)),
                Text('logged by ${e.ownerId == _repo?.ownerUid ? "Owner" : (isOwner ? "you" : e.ownerName)}', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white38 : Colors.grey[400], fontSize: 9)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('৳${fmt.format(e.amount)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : null)),
              if (isOwner)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.edit_rounded, color: AppColors.midTeal, size: 18),
                      onPressed: () => _editExpenseDirect(e),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                      onPressed: () => _repo!.deleteExpense(e.id),
                    ),
                  ],
                )
              else
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.edit_note_rounded, color: AppColors.coralOrange, size: 18),
                  tooltip: 'Request an edit',
                  onPressed: () => _requestExpenseEdit(e),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addExpenseCard(List<QParticipant> participants) {
    // Selected payer -> controller for that payer's contribution amount.
    final selectedPayers = <String>{if (participants.isNotEmpty) participants.first.id};
    final payerAmountCtrls = <String, TextEditingController>{};

    return StatefulBuilder(
      builder: (context, setD) {
        for (final p in participants) {
          payerAmountCtrls.putIfAbsent(p.id, () => TextEditingController());
        }
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('＋ Add Expense', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _isDarkMode ? Colors.white : null)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _expCategoryCtrl,
                      style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : null),
                      decoration: InputDecoration(
                        hintText: 'Category (e.g. Transport)',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white38 : null),
                        contentPadding: const EdgeInsets.all(8),
                        fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : null,
                        filled: _isDarkMode,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _expAmountCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : null),
                      decoration: InputDecoration(
                        hintText: 'Total Amount (BDT)',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white38 : null),
                        contentPadding: const EdgeInsets.all(8),
                        fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : null,
                        filled: _isDarkMode,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _expNotesCtrl,
                style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : null),
                decoration: InputDecoration(
                  hintText: 'Notes',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white38 : null),
                  contentPadding: const EdgeInsets.all(8),
                  fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : null,
                  filled: _isDarkMode,
                ),
              ),
              const SizedBox(height: 10),
              Text('Who paid? Select everyone who contributed to this cost.',
                  style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: participants.map((p) {
                  final sel = selectedPayers.contains(p.id);
                  return GestureDetector(
                    onTap: () => setD(() => sel ? selectedPayers.remove(p.id) : selectedPayers.add(p.id)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.midTeal : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(p.name, style: TextStyle(color: sel ? Colors.white : (_isDarkMode ? Colors.white70 : Colors.black87), fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
              if (selectedPayers.length > 1) ...[
                const SizedBox(height: 8),
                Text('Multiple payers — enter each person\'s share of the total:',
                    style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
                const SizedBox(height: 6),
                ...selectedPayers.map((id) {
                  final name = participants.firstWhere((p) => p.id == id).name;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 90, child: Text(name, style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : null))),
                        Expanded(
                          child: TextField(
                            controller: payerAmountCtrls[id],
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : null),
                            decoration: InputDecoration(
                              hintText: '৳ amount',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : null,
                              filled: _isDarkMode,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final category = _expCategoryCtrl.text.trim();
                  final total = double.tryParse(_expAmountCtrl.text) ?? 0.0;
                  if (category.isEmpty || total <= 0 || selectedPayers.isEmpty) return;

                  List<QPayer> payers;
                  if (selectedPayers.length == 1) {
                    payers = [QPayer(participantId: selectedPayers.first, amount: total)];
                  } else {
                    payers = selectedPayers
                        .map((id) => QPayer(participantId: id, amount: double.tryParse(payerAmountCtrls[id]?.text ?? '') ?? 0))
                        .toList();
                   }

                   final payerSum = payers.fold<double>(0, (s, p) => s + p.amount);
                   if ((payerSum - total).abs() > 0.5) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('Payers\' amounts (৳${payerSum.toStringAsFixed(0)}) must sum to the total (৳${total.toStringAsFixed(0)}).')),
                     );
                     return;
                   }

                   await _repo!.addExpense(category: category, amount: total, notes: _expNotesCtrl.text.trim(), payers: payers);
                  _expCategoryCtrl.clear();
                  _expAmountCtrl.clear();
                  _expNotesCtrl.clear();
                  for (final c in payerAmountCtrls.values) {
                    c.clear();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyBlue,
                  minimumSize: const Size(double.infinity, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Add Expense', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _requestExpenseEdit(QExpense e) {
    final categoryCtrl = TextEditingController(text: e.category);
    final amountCtrl = TextEditingController(text: e.amount.toStringAsFixed(0));
    final reasonCtrl = TextEditingController();

    final dialogBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor = _isDarkMode ? Colors.white70 : Colors.grey[600];
    final inputBg = _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50];
    final borderSide = BorderSide(color: _isDarkMode ? Colors.white24 : Colors.grey[300]!);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.edit_note_rounded, color: AppColors.midTeal, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Request Edit', style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.bold, color: textColor))),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Only ${e.ownerName} can edit this directly. Propose your changes below.',
                style: GoogleFonts.inter(fontSize: 11.5, color: subtextColor, height: 1.3),
              ),
              const SizedBox(height: 16),
              Text('PROPOSED CATEGORY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              TextField(
                controller: categoryCtrl,
                style: GoogleFonts.inter(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.midTeal, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Text('PROPOSED AMOUNT (BDT)', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.midTeal, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Text('REASON (REQUIRED)', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                style: GoogleFonts.inter(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputBg,
                  hintText: 'Explain why this edit is needed...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white38 : Colors.grey[400]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: borderSide),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.midTeal, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(side: borderSide, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: Text('Cancel', style: GoogleFonts.inter(color: textColor, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      if (reasonCtrl.text.trim().isEmpty) return;
                      await _repo!.submitEditRequest(
                        type: QEditTargetType.expense,
                        targetId: e.id,
                        targetLabel: e.category,
                        reason: reasonCtrl.text.trim(),
                        proposedChanges: {
                          'category': categoryCtrl.text.trim(),
                          'amount': double.tryParse(amountCtrl.text) ?? e.amount,
                        },
                      );
                      if (mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.midTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text('Send request', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Settlements & Reminders ----------------------------------------------
  Widget _buildSettlementsSection(NumberFormat fmt) {
    return StreamBuilder<List<QParticipant>>(
      stream: _repo!.watchParticipants(),
      builder: (context, pSnap) {
        final participants = pSnap.data ?? [];
        return StreamBuilder<List<QExpense>>(
          stream: _repo!.watchExpenses(),
          builder: (context, eSnap) {
            final expenses = eSnap.data ?? [];
            return StreamBuilder<List<QSettlement>>(
              stream: _repo!.watchSettlements(),
              builder: (context, sSnap) {
                final settlements = sSnap.data ?? [];
                final myUid = QurbaniRepository.currentUid();
                final pendingSettlements = settlements.where((s) => !s.confirmed).toList();
                final balances = SettlementEngine.computeBalances(participants: participants, expenses: expenses, settlements: settlements);
                final suggestions = SettlementEngine.suggestPayments(balances);

                return ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    Text('Settlements & Reminders', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15.5)),
                    const SizedBox(height: 4),
                    Text(
                      "The simplest set of payments that would settle every remaining balance — recalculated automatically after any confirmed payment, however people actually chose to pay each other.",
                      style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    Text('Balances (after confirmed settlements)',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                    const SizedBox(height: 8),
                    if (participants.isEmpty)
                      _emptyState('Add participants and log expenses to see balances.')
                    else
                      _balancesTable(balances, fmt),

                    const SizedBox(height: 20),
                    Text('Suggested — who pays whom',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                    const SizedBox(height: 8),
                    if (participants.isNotEmpty && suggestions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          const Icon(Icons.check_circle, color: AppColors.midTeal),
                          const SizedBox(width: 10),
                          Text('Everyone is settled.', style: GoogleFonts.inter(color: AppColors.midTeal, fontWeight: FontWeight.bold)),
                        ]),
                      )
                    else
                      ...suggestions.map((s) => _suggestedPaymentTile(s, myUid, pendingSettlements, fmt)),

                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: participants.length < 2 ? null : () => _showRecordPaymentDialog(participants),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Record a different payment'),
                    ),

                    if (pendingSettlements.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('⏳ Pending confirmations',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                      const SizedBox(height: 8),
                      ...pendingSettlements.map((s) => _pendingSettlementTile(s, myUid, fmt)),
                    ],

                    const SizedBox(height: 20),
                    Text('🔔 Reminders', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    _buildReminderTile(
                      type: 'Eid',
                      title: 'Qurbani Day Reminder',
                      desc: 'Get notified on Eid Al-Adha morning (10th Dhul Hijjah) to prepare for Qurbani.',
                      reminderTitle: '🐏 Qurbani Eid Day Reminder',
                      reminderBody: 'Assalamu alaikum! Eid Mubarak. Today is Qurbani day. Ensure animal requirements and health conditions are verified.',
                      timeOffset: const Duration(seconds: 15),
                    ),
                    _buildReminderTile(
                      type: 'Payment',
                      title: 'Qurbani Share Payment Reminder',
                      desc: 'Reminder to pay the share cost to the primary host before buying the animal.',
                      reminderTitle: '💰 Qurbani Payment Reminder',
                      reminderBody: 'Reminder: Make sure all Qurbani share payments are completed and participants have agreed on their shares.',
                      timeOffset: const Duration(seconds: 30),
                    ),
                    _buildReminderTile(
                      type: 'Collection',
                      title: 'Animal Collection / Haat Reminder',
                      desc: 'Get notified to visit the animal market (Haat) or collect your pre-booked animal.',
                      reminderTitle: '🐄 Animal Collection Reminder',
                      reminderBody: 'Time to collect your animal. Double check the age (2+ yrs for cow, 1+ for goat) and health status.',
                      timeOffset: const Duration(seconds: 45),
                    ),
                    _buildReminderTile(
                      type: 'Distribution',
                      title: 'Meat Distribution Reminder',
                      desc: 'Get notified 2 hours after Eid Prayer to begin packaging and distribution of meat.',
                      reminderTitle: '⚖ Meat Distribution Reminder',
                      reminderBody: 'Time to divide meat into three equal portions (Family, Relatives, and Needy) as per Sunnah.',
                      timeOffset: const Duration(seconds: 60),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _balancesTable(List<QBalanceRow> balances, NumberFormat fmt) {
    return Container(
      decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 32, child: Text('Member', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white60 : Colors.grey[600]))),
                Expanded(flex: 18, child: Text('Shares', textAlign: TextAlign.center, maxLines: 1, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white60 : Colors.grey[600]))),
                Expanded(flex: 25, child: Text('Owes', textAlign: TextAlign.end, maxLines: 1, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white60 : Colors.grey[600]))),
                Expanded(flex: 25, child: Text('Paid', textAlign: TextAlign.end, maxLines: 1, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white60 : Colors.grey[600]))),
                Expanded(flex: 28, child: Text('Balance', textAlign: TextAlign.end, maxLines: 1, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white60 : Colors.grey[600]))),
              ],
            ),
          ),
          const Divider(height: 1),
          ...balances.map((b) {
            final balColor = b.effectiveBalance > 0.5
                ? AppColors.midTeal
                : (b.effectiveBalance < -0.5 ? AppColors.coralOrange : Colors.grey);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 32, child: Text(b.participant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _isDarkMode ? Colors.white : Colors.black87))),
                  Expanded(flex: 18, child: Text('${b.participant.shares}', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.5, color: _isDarkMode ? Colors.white70 : Colors.grey[700]))),
                  Expanded(flex: 25, child: Text('৳${fmt.format(b.shareOfCost)}', textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white70 : Colors.grey[700]))),
                  Expanded(flex: 25, child: Text('৳${fmt.format(b.totalPaid)}', textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white70 : Colors.grey[700]))),
                  Expanded(
                    flex: 28,
                    child: Text(
                      '${b.effectiveBalance >= 0 ? '+' : '-'}৳${fmt.format(b.effectiveBalance.abs())}',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: balColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _suggestedPaymentTile(SuggestedPayment s, String myUid, List<QSettlement> pendingSettlements, NumberFormat fmt) {
    // Only the creditor (the person who is OWED the money) gets the Bell icon to send payment reminder
    final isCreditor = myUid == s.to.uid || myUid == s.to.ownerId || myUid == s.to.id || (myUid == _repo!.ownerUid);

    // Only parties involved in this payment or the plan owner can record it
    final isPartyInvolved = myUid == s.from.uid || myUid == s.from.ownerId || myUid == s.from.id || isCreditor;

    final hasPending = pendingSettlements.any((ps) =>
        (ps.fromId == s.from.id || ps.fromName == s.from.name) &&
        (ps.toId == s.to.id || ps.toName == s.to.name));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDarkMode ? Colors.white12 : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 13, color: _isDarkMode ? Colors.white : Colors.black87),
                children: [
                  TextSpan(text: s.from.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' pays '),
                  TextSpan(text: s.to.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Text('৳${fmt.format(s.amount)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
          if (isCreditor) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.notifications_active_rounded, color: AppColors.coralOrange, size: 20),
              tooltip: 'Send payment reminder',
              onPressed: () => _notifySettlement(s),
            ),
          ],
          if (hasPending) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: AppColors.coralOrange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Text('⏳ In Progress', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
            ),
          ] else if (isPartyInvolved) ...[
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: () async {
                await _repo!.recordSettlement(from: s.from, to: s.to, amount: s.amount, confirmed: false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Record', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  void _notifySettlement(SuggestedPayment s) {
    NotificationService.instance.scheduleCustomNotification(
      id: 4000 + s.from.id.hashCode % 1000,
      title: 'Qurbani Payment Reminder',
      body: '${s.from.name}, please pay ৳${s.amount.toStringAsFixed(0)} to ${s.to.name} to settle your Qurbani shares.',
      scheduledTime: DateTime.now().add(const Duration(seconds: 5)),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🔔 Reminder scheduled for ${s.from.name} to pay ${s.to.name}.')),
      );
    }
  }

  Widget _pendingSettlementTile(QSettlement s, String myUid, NumberFormat fmt) {
    final isReceiver = s.toId == myUid || myUid == _repo!.ownerUid;
    final isPayer = s.fromId == myUid;
    final statusText = isReceiver
        ? 'Tap Confirm if you received this payment'
        : (isPayer ? 'Waiting for receiver to confirm' : 'Pending confirmation');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.coralOrange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions_rounded, size: 18, color: AppColors.coralOrange),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(fontSize: 13, color: _isDarkMode ? Colors.white70 : Colors.grey[800]),
                    children: [
                      TextSpan(text: s.fromName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
                      const TextSpan(text: ' → '),
                      TextSpan(text: s.toName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                    ],
                  ),
                ),
              ),
              Text('৳${fmt.format(s.amount)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.coralOrange)),
            ],
          ),
          const SizedBox(height: 6),
          Text(statusText, style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
          if (isReceiver) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await _repo!.confirmSettlement(s.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment confirmed.')));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not confirm: $e')));
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                    label: Text('Confirm', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.midTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await _repo!.disputeSettlement(s.id, s.confirmed);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment disputed.')));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not dispute: $e')));
                        }
                      }
                    },
                    icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 16),
                    label: Text('Dispute', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(List<QParticipant> participants) {
    String fromId = participants.first.id;
    String toId = participants.last.id;
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Record a payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: fromId,
                decoration: const InputDecoration(labelText: 'From (payer)'),
                items: participants.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) => setD(() => fromId = v!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: toId,
                decoration: const InputDecoration(labelText: 'To (receiver)'),
                items: participants.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) => setD(() => toId = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (BDT)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                if (amt <= 0 || fromId == toId) return;
                final from = participants.firstWhere((p) => p.id == fromId);
                final to = participants.firstWhere((p) => p.id == toId);
                await _repo!.recordSettlement(from: from, to: to, amount: amt, confirmed: false);
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderTile({
    required String type,
    required String title,
    required String desc,
    required String reminderTitle,
    required String reminderBody,
    required Duration timeOffset,
  }) {
    bool active = _activeReminders[type] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _isDarkMode ? Colors.white : null)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.inter(color: _isDarkMode ? Colors.white54 : Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          Switch(
            value: active,
            activeThumbColor: AppColors.navyBlue,
            onChanged: (val) => _toggleReminder(type, reminderTitle, reminderBody, DateTime.now().add(timeOffset)),
          ),
        ],
      ),
    );
  }

  // ---- Edit Requests ----------------------------------------------------------
  Widget _buildEditRequestsSection() {
    final myUid = QurbaniRepository.currentUid();
    return StreamBuilder<List<QEditRequest>>(
      stream: _repo!.watchEditRequests(),
      builder: (context, snap) {
        final requests = snap.data ?? [];
        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: AppColors.midTeal, size: 22),
                const SizedBox(width: 8),
                Text('Edit Requests', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15.5)),
              ],
            ),
            const SizedBox(height: 4),
            Text("Edit requests are sent to the creator of the expense/participant. The requester can cancel a request anytime, and the creator can accept or reject it.",
                style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 12, height: 1.4)),
            const SizedBox(height: 14),
            if (requests.isEmpty)
              _emptyState('No edit requests submitted yet.')
            else
              ...requests.map((r) => _editRequestCard(r, myUid)),
          ],
        );
      },
    );
  }

  Widget _editRequestCard(QEditRequest r, String myUid) {
    final changeText = r.proposedChanges.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    final isRequester = myUid == r.requestedById;
    final isTargetOwner = myUid == r.targetOwnerId || (r.targetOwnerId.isEmpty && myUid == _repo!.ownerUid);

    Color statusColor = Colors.amber[700]!;
    String statusText = 'PENDING';
    if (r.status == 'approved') {
      statusColor = Colors.green;
      statusText = 'APPROVED';
    } else if (r.status == 'rejected') {
      statusColor = Colors.red;
      statusText = 'REJECTED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _isDarkMode ? Colors.white12 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.targetType == QEditTargetType.participant ? Icons.person_outline_rounded : Icons.payment_outlined,
                size: 18,
                color: AppColors.coralOrange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${r.targetType == QEditTargetType.participant ? "Participant" : "Expense"}: ${r.targetLabel}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(statusText, style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isRequester ? 'Requested by you' : 'Requested by ${r.requestedByName}',
            style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white54 : Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text('Proposed: $changeText', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _isDarkMode ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 4),
          Text('Reason: "${r.reason}"', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: _isDarkMode ? Colors.white60 : Colors.grey[700])),
          const SizedBox(height: 10),

          if (r.status == 'pending') ...[
            if (isRequester)
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await _repo!.deleteEditRequest(r.id);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit request cancelled.')));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                  label: const Text('Cancel Request', style: TextStyle(color: Colors.red, fontSize: 11)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                ),
              )
            else if (isTargetOwner)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await _repo!.rejectEditRequest(r.id);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit request rejected.')));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not reject: $e')));
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _isDarkMode ? Colors.white24 : Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text('Reject', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white70 : Colors.grey[800], fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _repo!.approveEditRequest(r);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit request accepted & applied!')));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not accept: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.midTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text('Accept Change', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              )
            else
              Text('Waiting for item owner to review.', style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white54 : Colors.grey[600])),
          ],
        ],
      ),
    );
  }

  Widget _emptyState(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: GoogleFonts.inter(color: _isDarkMode ? Colors.white54 : Colors.grey[500], fontSize: 12)),
    );
  }

  // ===========================================================================
  // TASKS TAB — Activities Checklist / Rules & Verses
  // ===========================================================================
  Widget _buildTasksTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              Expanded(child: _subTabChip('Checklist', 0, _tasksSubTab, (i) => setState(() => _tasksSubTab = i))),
              const SizedBox(width: 8),
              Expanded(child: _subTabChip('Rules & Verses', 1, _tasksSubTab, (i) => setState(() => _tasksSubTab = i))),
            ],
          ),
        ),
        Expanded(child: _tasksSubTab == 0 ? _buildActivitiesChecklist() : _buildRulesAndVerses()),
      ],
    );
  }

  Widget _subTabChip(String label, int index, int active, void Function(int) onTap) {
    final isActive = active == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppColors.navyBlue : (_isDarkMode ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppColors.navyBlue : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : (_isDarkMode ? Colors.white70 : Colors.grey[700]))),
      ),
    );
  }

  Widget _buildActivitiesChecklist() {
    final repo = _repo;
    // If we have a group, stream checklist state from Firestore.
    // Otherwise fall back to local in-memory state so the checklist
    // is always visible regardless of whether a group is active.
    if (repo != null) {
      return StreamBuilder<Map<String, bool>>(
        stream: repo.watchChecklistState(),
        builder: (context, snap) {
          final state = snap.data ?? {};
          return _checklistListView(
            state: state,
            onToggle: (id, val) => repo.setChecklistDone(id, val),
          );
        },
      );
    }
    // No group — use local state
    return _checklistListView(
      state: _localChecklistState,
      onToggle: (id, val) => setState(() => _localChecklistState[id] = val),
      isLocal: true,
    );
  }

  Widget _checklistListView({
    required Map<String, bool> state,
    required void Function(String id, bool val) onToggle,
    bool isLocal = false,
  }) {
    final doneCount = kQurbaniChecklist.where((i) => state[i.id] == true).length;
    final total = kQurbaniChecklist.length;
    final pct = total == 0 ? 0.0 : doneCount / total;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        Text('Activities Checklist',
            style: GoogleFonts.poppins(
                color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                fontWeight: FontWeight.bold,
                fontSize: 15.5)),
        const SizedBox(height: 4),
        Text(
          'A step-by-step guide from preparation through distribution. Check items off as your household completes them.',
          style: GoogleFonts.inter(
              color: _isDarkMode ? Colors.white60 : Colors.grey[600],
              fontSize: 12,
              height: 1.4),
        ),
        if (isLocal) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.midTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.midTeal, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Saved locally on this device. Join or create a group to sync across members.',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _isDarkMode ? Colors.white70 : Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$doneCount of $total complete',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
            Text('${(pct * 100).round()}%',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.midTeal)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: _isDarkMode ? Colors.white12 : Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.midTeal),
          ),
        ),
        const SizedBox(height: 16),
        for (final section in ['before', 'day', 'after']) ...[
          Text(
            _sectionTitles[section]!,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _isDarkMode ? Colors.white : AppColors.navyBlue),
          ),
          const SizedBox(height: 4),
          ...kQurbaniChecklist.where((i) => i.section == section).map((item) {
            final done = state[item.id] == true;
            return CheckboxListTile(
              value: done,
              title: Text(
                item.title,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: done
                        ? (_isDarkMode ? Colors.white38 : Colors.grey[500])
                        : (_isDarkMode ? Colors.white : Colors.black87),
                    decoration: done ? TextDecoration.lineThrough : null,
                    height: 1.3),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.midTeal,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => onToggle(item.id, val ?? false),
            );
          }),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildRulesAndVerses() {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        Text('Rules & Verses', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15.5)),
        const SizedBox(height: 4),
        Text("The Qur'anic basis and general fiqh guidelines for Qurbani.",
            style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 13, height: 1.4)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber[200]!)),
          child: Text(
            "Details of fiqh vary between schools of thought (madhabs) and local fatwa councils. This is a general, non-sectarian summary for planning purposes — please confirm specific rulings with a qualified local scholar.",
            style: GoogleFonts.inter(color: Colors.amber[900], fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: 20),

        Text("From the Qur'an", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
        const SizedBox(height: 8),
        ...kQuranVerses.map((v) => _verseCard(v)),

        const SizedBox(height: 20),
        Text('Conditions on the animal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
        const SizedBox(height: 8),
        _ruleBullet('Must be from grazing livestock: goat/sheep, cow/buffalo, or camel — no other animals qualify.'),
        _ruleBullet('Must have reached the minimum age: sheep/goat ≈ 1 lunar year (a young sheep of ~6 months may qualify if it looks like a 1-year-old per some scholars), cow/buffalo ≈ 2 lunar years, camel ≈ 5 lunar years.'),
        _ruleBullet('Must be free of the four major defects agreed upon in hadith: clearly one-eyed/blind, clearly sick, clearly lame, and emaciated with no marrow in its bones.'),
        _ruleBullet('One goat or sheep counts as one full sacrifice for one person/household. One cow, buffalo, or camel can be shared between up to 7 people, each owning one share.'),

        const SizedBox(height: 20),
        Text('Timing', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
        const SizedBox(height: 8),
        _ruleBullet('The valid window is from after Eid al-Adha prayer on 10 Dhul Hijjah until sunset on 13 Dhul Hijjah (three days after Eid, by the majority view).'),
        _ruleBullet('Sacrificing before the Eid prayer (where applicable) is not counted as Qurbani — it is treated as ordinary charity, and the animal should be replaced.'),
        _ruleBullet('If a person genuinely intends to sacrifice and it is within the first ten days of Dhul Hijjah, many scholars recommend they avoid cutting their hair and nails until after the sacrifice, based on hadith guidance — this is recommended, not obligatory, and applies to the person sacrificing, not to those merely giving them money.'),

        const SizedBox(height: 20),
        Text('Distribution of meat', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
        const SizedBox(height: 8),
        _ruleBullet('A commonly followed guideline (not a strict Qur\'anic obligation) is to divide the meat roughly into three: one third for the household, one third for relatives/friends, and one third for those in need.'),
        _ruleBullet("Distributing at least some portion to those less fortunate is strongly encouraged, in the same spirit as the general command to feed 'the needy and the poor' mentioned in Surah Al-Hajj 22:28 and 22:36."),
        _ruleBullet('The exact split is flexible and depends on local custom, household size, and need — the point is not the fraction, but that some is eaten, some is shared, and some reaches the poor.'),
      ],
    );
  }

  Widget _verseCard(VerseEntry v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v.reference, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.midTeal)),
          const SizedBox(height: 6),
          Text(v.text, style: GoogleFonts.inter(fontSize: 13, color: _isDarkMode ? Colors.white70 : Colors.grey[800], height: 1.5)),
        ],
      ),
    );
  }

  Widget _ruleBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(Icons.brightness_1, size: 6, color: _isDarkMode ? AppColors.midTeal : AppColors.navyBlue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(color: _isDarkMode ? Colors.white70 : Colors.grey[800], fontSize: 13, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// QURBANI PLANNER FULL SCREEN PAGE
// =============================================================================
class QurbaniPlannerPage extends StatefulWidget {
  const QurbaniPlannerPage({super.key});

  @override
  State<QurbaniPlannerPage> createState() => _QurbaniPlannerPageState();
}

class _QurbaniPlannerPageState extends State<QurbaniPlannerPage> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('is_dark_mode') ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _isDarkMode ? const Color(0xFF000000) : const Color(0xFFE8E8E8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
            body: SafeArea(
              top: false,
              bottom: false,
              child: QurbaniPlannerSheet(scrollController: ScrollController(), isPage: true),
            ),
          ),
        ),
      ),
    );
  }
}

