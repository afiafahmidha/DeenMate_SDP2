import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/auth_header.dart';
import '../services/notification_service.dart';

// =============================================================================
// MODELS
// =============================================================================

// Matches users/{ownerUid}/qurbaniPlans/{planId}/participants/{participantId}
// from the app-wide Firestore schema. amountDue / amountPaid / paymentStatus
// are kept as denormalized fields (recomputed and written back after every
// balance calculation) so other screens/teammates reading this schema see
// up-to-date numbers without needing to run the settlement engine themselves.
// ownerId / ownerName are additions on top of the base schema, needed for the
// "whoever adds it owns it" edit-request rule.
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
      );
}

// A single payer contribution on an expense entry (supports unequal
// multi-payer contributions on one line item).
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
  final DateTime createdAt;

  QExpense({
    required this.id,
    required this.category,
    required this.amount,
    required this.notes,
    required this.payers,
    required this.ownerId,
    required this.ownerName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'category': category,
        'amount': amount,
        'notes': notes,
        'payers': payers.map((p) => p.toMap()).toList(),
        'ownerId': ownerId,
        'ownerName': ownerName,
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

  static const _prefsOwnerKey = 'qurbani_plan_owner_uid';
  static const _prefsPlanKey = 'qurbani_plan_id';

  /// Loads the locally-remembered plan (created or joined earlier). If none
  /// exists yet, creates a brand-new plan owned by the current user under
  /// users/{uid}/qurbaniPlans/{newId}, matching the existing schema shape.
  static Future<QurbaniRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOwner = prefs.getString(_prefsOwnerKey);
    final savedPlan = prefs.getString(_prefsPlanKey);
    if (savedOwner != null && savedPlan != null) {
      return QurbaniRepository._(savedOwner, savedPlan);
    }
    return _createNewPlan();
  }

  static Future<QurbaniRepository> _createNewPlan() async {
    final uid = currentUid();
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('qurbaniPlans').doc();
    final now = FieldValue.serverTimestamp();
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
    await _persist(uid, docRef.id);
    return QurbaniRepository._(uid, docRef.id);
  }

  static Future<void> _persist(String ownerUid, String planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsOwnerKey, ownerUid);
    await prefs.setString(_prefsPlanKey, planId);
  }

  /// Generates a shareable code, using the same local-code pattern as the SOS
  /// emergency group feature.
  Future<String> createInviteCode() async {
    final code = await _newUnusedInviteCode();
    await FirebaseFirestore.instance.collection('qurbaniPlanInvites').doc(code).set({
      'ownerUid': ownerUid,
      'planId': planId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  static Future<String> _newUnusedInviteCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final suffix = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
      final code = 'QRB-$suffix';
      final existing = await FirebaseFirestore.instance.collection('qurbaniPlanInvites').doc(code).get();
      if (!existing.exists) return code;
    }
    throw StateError('Could not create a unique invite code. Please try again.');
  }

  /// Joins an existing household plan by its invite code: looks up the
  /// (ownerUid, planId) pair, adds the current user to memberIds, and
  /// switches local storage to point at that plan from now on.
  Future<void> joinCurrentUserWithShares(int shares) async {
    final uid = currentUid();
    final name = currentDisplayName();
    await planRef.collection('members').doc(uid).set({
      'name': name, 'shares': shares,
      'joinedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await participantsRef.doc(uid).set({
      'name': name, 'phone': null, 'shares': shares, 'amountDue': 0.0,
      'amountPaid': 0.0, 'paymentStatus': 'unpaid', 'ownerId': uid, 'ownerName': name,
    }, SetOptions(merge: true));
  }

  static Future<QurbaniRepository> joinByCode(String code, int shares) async {
    final inviteDoc = await FirebaseFirestore.instance.collection('qurbaniPlanInvites').doc(code.trim().toUpperCase()).get();
    if (!inviteDoc.exists) {
      throw Exception('Invite code not found');
    }
    final data = inviteDoc.data()!;
    final targetOwner = data['ownerUid'] as String;
    final targetPlan = data['planId'] as String;

    await _persist(targetOwner, targetPlan);
    final repository = QurbaniRepository._(targetOwner, targetPlan);
    await repository.joinCurrentUserWithShares(shares);
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

  static String currentUid() => FirebaseAuth.instance.currentUser?.uid ?? 'local_device';
  static String currentDisplayName() =>
      FirebaseAuth.instance.currentUser?.displayName ??
      FirebaseAuth.instance.currentUser?.email?.split('@').first ??
      'Me';

  Stream<List<QParticipant>> watchParticipants() =>
      participantsRef.orderBy('name').snapshots().map((s) => s.docs.map(QParticipant.fromDoc).toList());

  Stream<List<QExpense>> watchExpenses() =>
      expensesRef.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(QExpense.fromDoc).toList());

  Stream<List<QEditRequest>> watchEditRequests() =>
      editRequestsRef.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(QEditRequest.fromDoc).toList());

  Stream<List<QSettlement>> watchSettlements() =>
      settlementsRef.orderBy('date', descending: true).snapshots().map((s) => s.docs.map(QSettlement.fromDoc).toList());

  Future<void> addParticipant(String name, int shares, {String? phone}) async {
    await participantsRef.add(
      QParticipant(
        id: '',
        name: name,
        phone: phone,
        shares: shares,
        ownerId: currentUid(),
        ownerName: currentDisplayName(),
      ).toMap(),
    );
    await _recalcAndSyncBalances();
  }

  Future<void> updateParticipantDirect(String id, {String? name, int? shares}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (shares != null) data['shares'] = shares;
    await participantsRef.doc(id).update(data);
    await _recalcAndSyncBalances();
  }

  Future<void> deleteParticipant(String id) async {
    await participantsRef.doc(id).delete();
    await _recalcAndSyncBalances();
  }

  Future<void> addExpense({
    required String category,
    required double amount,
    required String notes,
    required List<QPayer> payers,
  }) async {
    await expensesRef.add(
      QExpense(
        id: '',
        category: category,
        amount: amount,
        notes: notes,
        payers: payers,
        ownerId: currentUid(),
        ownerName: currentDisplayName(),
        createdAt: DateTime.now(),
      ).toMap(),
    );
    await _recalcAndSyncBalances();
  }

  Future<void> deleteExpense(String id) async {
    await expensesRef.doc(id).delete();
    await _recalcAndSyncBalances();
  }

  Future<void> submitEditRequest({
    required QEditTargetType type,
    required String targetId,
    required String targetLabel,
    required String reason,
    required Map<String, dynamic> proposedChanges,
  }) =>
      editRequestsRef.add(
        QEditRequest(
          id: '',
          targetType: type,
          targetId: targetId,
          targetLabel: targetLabel,
          requestedById: currentUid(),
          requestedByName: currentDisplayName(),
          reason: reason,
          proposedChanges: proposedChanges,
          status: 'pending',
          createdAt: DateTime.now(),
        ).toMap(),
      );

  Future<void> approveEditRequest(QEditRequest req) async {
    if (req.targetType == QEditTargetType.participant) {
      await participantsRef.doc(req.targetId).update(req.proposedChanges);
    } else {
      await expensesRef.doc(req.targetId).update(req.proposedChanges);
    }
    await editRequestsRef.doc(req.id).update({'status': 'approved'});
    await _recalcAndSyncBalances();
  }

  Future<void> rejectEditRequest(String id) => editRequestsRef.doc(id).update({'status': 'rejected'});

  Future<void> recordSettlement({
    required QParticipant from,
    required QParticipant to,
    required double amount,
    bool confirmed = true,
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
    await _recalcAndSyncBalances();
  }

  /// Reads participants/expenses/settlements once, recomputes balances via
  /// [SettlementEngine], and writes amountDue/amountPaid/paymentStatus back
  /// onto each participant doc. Called automatically after any mutation that
  /// affects balances so the denormalized fields never go stale.
  Future<void> _recalcAndSyncBalances() async {
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

  /// Writes the freshly-computed balances back onto each participant doc's
  /// amountDue / amountPaid / paymentStatus fields, so any other screen
  /// reading the base schema (e.g. a dashboard your teammates already built
  /// against qurbaniPlans/participants) sees current numbers without having
  /// to run the settlement engine itself. Call this after any change to
  /// expenses or settlements.
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

class QurbaniPlannerSheet extends StatefulWidget {
  final ScrollController scrollController;
  final bool isPage;
  const QurbaniPlannerSheet({super.key, required this.scrollController, this.isPage = false});

  @override
  State<QurbaniPlannerSheet> createState() => _QurbaniPlannerSheetState();
}

class _QurbaniPlannerSheetState extends State<QurbaniPlannerSheet> {
  int _tab = 0;
  static const _tabLabels = ['Eligibility', 'Calculators', 'Shares', 'Distribution', 'Tasks'];
  static const _tabIcons = [
    Icons.check_circle_rounded,
    Icons.calculate_rounded,
    Icons.people_alt_rounded,
    Icons.restaurant_menu_rounded,
    Icons.task_rounded,
  ];

  bool _isDarkMode = false;
  QurbaniRepository? _repo;
  String? _repositoryError;

  // Eligibility
  final TextEditingController _savingsCtrl = TextEditingController(text: '0');
  final TextEditingController _metalsCtrl = TextEditingController(text: '0');
  final TextEditingController _cashCtrl = TextEditingController(text: '0');
  final TextEditingController _debtsCtrl = TextEditingController(text: '0');
  bool _hasCheckedEligibility = false;
  bool _isEligible = false;
  double _netAssets = 0.0;
  String _eligibilityReason = '';

  // Calculators
  String _selectedAnimal = 'Cow';
  String _selectedLocation = 'Dhaka';
  int _selectedShares = 1;
  double _estimatedCost = 0.0;
  String _aqiqahBabyGender = 'Boy';
  int _aqiqahQuantity = 2;
  double _aqiqahEstimatedCost = 0.0;
  final List<Map<String, dynamic>> _aqiqahChecklist = [
    {'title': "Name baby on 7th day", 'done': false},
    {'title': "Shave baby's hair & give charity in silver weight equivalent", 'done': false},
    {'title': "Purchase Aqiqah animals", 'done': false},
    {'title': "Arrange food/distribution of meat", 'done': false},
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

  // Shares sub-tabs: 0 Participants, 1 Expenses, 2 Settlements, 3 Edit Requests
  int _sharesSubTab = 0;
  // Tasks sub-tabs: 0 Checklist, 1 Rules & Verses
  int _tasksSubTab = 0;

  final TextEditingController _participantNameCtrl = TextEditingController();
  int _newParticipantShares = 1;
  final TextEditingController _expCategoryCtrl = TextEditingController();
  final TextEditingController _expAmountCtrl = TextEditingController();
  final TextEditingController _expNotesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _calculateCosts();
    _calculateAqiqahCosts();
    _loadRepository();
  }

  Future<void> _loadRepository() async {
    setState(() {
      _repo = null;
      _repositoryError = null;
    });

    if (FirebaseAuth.instance.currentUser == null) {
      if (mounted) {
        setState(() => _repositoryError = 'Please sign in before using the Qurbani Planner.');
      }
      return;
    }

    try {
      final repository = await QurbaniRepository.load();
      if (mounted) setState(() => _repo = repository);
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() => _repositoryError = error.code == 'permission-denied'
            ? 'The Qurbani Planner is not permitted by Firestore yet. Deploy the updated Firestore rules, then try again.'
            : 'Could not load your Qurbani plan: ${error.message ?? error.code}');
      }
    } catch (error) {
      if (mounted) setState(() => _repositoryError = 'Could not load your Qurbani plan: $error');
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

    if (_repo == null) {
      if (_repositoryError != null) {
        return Container(
          color: containerBg,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.orange),
              const SizedBox(height: 12),
              Text(_repositoryError!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: textColor)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadRepository,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        );
      }
      return Container(
        color: containerBg,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

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
                        Text('Qurbani & Aqiqah Planner',
                            style: GoogleFonts.poppins(color: textColor, fontSize: 15.5, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: _showHouseholdSharingSheet,
                          child: Text('Share plan with household  ·  tap here',
                              style: GoogleFonts.inter(color: subtextColor, fontSize: 11)),
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.navyBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.pets_rounded, color: AppColors.navyBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Qurbani & Aqiqah Planner',
                            style: GoogleFonts.poppins(color: AppColors.navyBlue, fontSize: 18, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: _showHouseholdSharingSheet,
                          child: Text('Share plan with household  ·  tap here',
                              style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    style: IconButton.styleFrom(backgroundColor: Colors.grey[200], padding: const EdgeInsets.all(8)),
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

  // Lets the plan owner generate an invite code to share with household
  // members, or lets any user enter someone else's code to join their plan
  // instead (switching this device to point at that shared Firestore path).
  void _showHouseholdSharingSheet() {
    final joinCtrl = TextEditingController();
    String? generatedCode;
    bool generating = false;
    bool joining = false;
    String? error;
    int shares = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share this plan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 6),
              Text(
                'Generate a code so household members see the same participants, expenses and settlements — or enter someone else\'s code to join their plan instead.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], height: 1.4),
              ),
              const SizedBox(height: 20),

              Text('My shares', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
              Row(children: [
                IconButton(onPressed: shares > 1 ? () => setD(() => shares--) : null, icon: const Icon(Icons.remove_circle_outline)),
                Text('$shares', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: shares < 7 ? () => setD(() => shares++) : null, icon: const Icon(Icons.add_circle_outline)),
                Expanded(child: Text('Choose your own shares before creating or joining.', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]))),
              ]),

              Text('Invite others', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              if (generatedCode != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(generatedCode!, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2, color: AppColors.midTeal)),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: generating
                      ? null
                      : () async {
                          setD(() => generating = true);
                          try {
                            await _repo!.joinCurrentUserWithShares(shares);
                            final code = await _repo!.createInviteCode();
                            setD(() {
                              generatedCode = code;
                              generating = false;
                            });
                          } catch (_) {
                            setD(() {
                              error = 'Could not generate an invite code. Please try again.';
                              generating = false;
                            });
                          }
                        },
                  icon: generating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.qr_code_rounded, size: 18),
                  label: const Text('Generate invite code'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
                ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              Text('Join a household plan instead', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: joinCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter invite code (e.g. QRB-AB12CD)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  errorText: error,
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
                          final r = await QurbaniRepository.joinByCode(joinCtrl.text, shares);
                          if (mounted) {
                            setState(() => _repo = r);
                            Navigator.pop(ctx);
                          }
                        } catch (_) {
                          setD(() {
                            joining = false;
                            error = 'Code not found. Double-check and try again.';
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
    );
  }

  Widget _buildTabBar() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
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
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.navyBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(_tabIcons[i],
                        size: 16,
                        color: active ? Colors.white : (_isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4))),
                    const SizedBox(height: 2),
                    Text(_tabLabels[i],
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : (_isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4)))),
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
        return _buildMeatDistributionTab();
      case 4:
        return _buildTasksTab();
      default:
        return _buildEligibilityTab(fmt);
    }
  }

  // ===========================================================================
  // ELIGIBILITY TAB (unchanged logic from previous version)
  // ===========================================================================
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
                    style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 14)),
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
            style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
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
                _buildInputRow(icon: Icons.savings_outlined, label: 'Annual Savings', controller: _savingsCtrl),
                _buildInputRow(icon: Icons.storefront_outlined, label: 'Gold / Silver (value in BDT)', controller: _metalsCtrl),
                _buildInputRow(icon: Icons.monetization_on_outlined, label: 'Available Cash', controller: _cashCtrl),
                _buildInputRow(icon: Icons.money_off_csred_outlined, label: 'Debts & Liabilities', controller: _debtsCtrl),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _checkEligibility,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Evaluate Eligibility', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
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

        // General Rules & Guidelines -- quick-reference summary. The full
        // Qur'anic verses + detailed fiqh notes live in Tasks > Rules & Verses;
        // this is the short version kept right where eligibility is checked.
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
                    _tab = 4;
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

        // Eligibility / Nisab reminder -- separate from the Settlements-tab
        // reminders since this one is about re-checking Nisab as Dhul Hijjah
        // approaches, not about payments or the animal.
        Text('\ud83d\udd14 Eligibility Reminder', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
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
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _isDarkMode ? Colors.white : null)),
                    const SizedBox(height: 4),
                    Text('Get a nudge a few days before Eid to re-check your assets against the current Nisab value, since gold/silver prices change.',
                        style: GoogleFonts.inter(color: _isDarkMode ? Colors.white54 : Colors.grey, fontSize: 10)),
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
  Widget _buildCalculatorsTab(NumberFormat fmt) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Text('Qurbani Cost Planner',
            style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16)),
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
                      Text('$_selectedShares Share(s)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: _isDarkMode ? Colors.white : null)),
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
                  decoration: BoxDecoration(color: AppColors.navyBlue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Estimated Cost:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                      Text('৳${fmt.format(_estimatedCost)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.coralOrange, fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('🍼 Aqiqah Planner', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16)),
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
                  decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Aqiqah Estimated Cost:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                      Text('৳${fmt.format(_aqiqahEstimatedCost)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.midTeal, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Aqiqah Checklist', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontSize: 13)),
                const SizedBox(height: 8),
                Column(
                  children: _aqiqahChecklist.map((item) {
                    return CheckboxListTile(
                      value: item['done'],
                      title: Text(item['title'], style: GoogleFonts.inter(fontSize: 13, color: _isDarkMode ? Colors.white : Colors.black87)),
                      checkColor: _isDarkMode ? Colors.black : Colors.white,
                      activeColor: AppColors.midTeal,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => item['done'] = val),
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
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Text('⚖ Meat Distribution Planner', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        Text('Set your total meat quantity to plan the Sunnah-based 3-way distribution.',
            style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 16),
        Card(
          color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
                      Text('Total Meat Amount (in kg)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : null)),
                      Text('Adjust slider or enter below', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white54 : Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87),
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
          activeColor: AppColors.navyBlue,
          inactiveColor: Colors.grey[300],
          label: '${_totalMeatKg.round()} kg',
          onChanged: (val) => setState(() => _totalMeatKg = val),
        ),
        const SizedBox(height: 16),
        Text('Suggested Distribution Split', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
        const SizedBox(height: 8),
        Container(
          height: 35,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.grey[200]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Expanded(child: Container(color: AppColors.navyBlue, alignment: Alignment.center, child: Text('Family (1/3)', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                Container(width: 1.5, color: Colors.white),
                Expanded(child: Container(color: AppColors.midTeal, alignment: Alignment.center, child: Text('Relatives (1/3)', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                Container(width: 1.5, color: Colors.white),
                Expanded(child: Container(color: AppColors.coralOrange, alignment: Alignment.center, child: Text('Poor (1/3)', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          _buildDistributionCard('Family Portion', familyQty, AppColors.navyBlue),
          const SizedBox(width: 10),
          _buildDistributionCard('Relatives Portion', relativesQty, AppColors.midTeal),
          const SizedBox(width: 10),
          _buildDistributionCard('Poor / Needy', poorQty, AppColors.coralOrange),
        ]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber[200]!)),
          child: Text(
            '💡 Note: The 1/3 meat distribution rule is a highly recommended (Mustahabb) Sunnah based on traditional Islamic practices to encourage sharing and charity, but it is not a binding compulsory requirement. You may distribute more to charity or retain more based on family size and needs.',
            style: GoogleFonts.inter(color: Colors.amber[900], fontSize: 11, height: 1.4),
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

  // ===========================================================================
  // SHARES TAB — Participants / Expenses / Settlements / Edit Requests
  // ===========================================================================
  Widget _buildSharesTab(NumberFormat fmt) {
    final subLabels = ['Participants', 'Expenses', 'Settlements', 'Requests'];
    final subIcons = [Icons.people_alt_rounded, Icons.payments_rounded, Icons.handshake_rounded, Icons.edit_note_rounded];
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Column(
      children: [
        // Segmented sub-tab bar, styled to match the main tab bar above it so
        // it reads as one connected navigation system rather than a loose
        // row of pills.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: List.generate(subLabels.length, (i) {
                final active = _sharesSubTab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _sharesSubTab = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: active ? AppColors.midTeal : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(subIcons[i],
                              size: 16,
                              color: active ? Colors.white : (_isDarkMode ? Colors.white54 : Colors.grey[500])),
                          const SizedBox(height: 3),
                          Text(subLabels[i],
                              style: GoogleFonts.inter(
                                  fontSize: 10.5,
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
              default:
                return _buildEditRequestsSection();
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
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Text('Participants', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text("Each participant joins with the household code and chooses their own share count.",
                style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 12, height: 1.4)),
            const SizedBox(height: 12),
            _householdGroupCard(),
            const SizedBox(height: 16),
            if (!snap.hasData)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
            else if (participants.isEmpty)
              _emptyState('No participants yet. Add the first one below.')
            else
              ...participants.map((p) => _participantCard(p, myUid)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _householdGroupCard() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final isOwner = _repo!.ownerUid == QurbaniRepository.currentUid();

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.midTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_rounded, color: AppColors.midTeal, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Household share group',
                    style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isOwner
                ? 'Create a code here, then share it with people you want to add to this plan.'
                : 'Enter a household code here to join the shared Qurbani plan.',
            style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 11.5, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showHouseholdSharingSheet,
              icon: Icon(isOwner ? Icons.add_link_rounded : Icons.login_rounded, size: 18),
              label: Text(isOwner ? 'Create or join group' : 'Join household group'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(42),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _participantCard(QParticipant p, String myUid) {
    final isOwner = p.ownerId == myUid;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: AppColors.navyBlue.withValues(alpha: 0.1), child: const Icon(Icons.person, color: AppColors.navyBlue)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : null)),
                Text('${p.shares} Share(s) · added by ${isOwner ? "you" : p.ownerName}',
                    style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white60 : Colors.grey[600])),
              ],
            ),
          ),
          const Icon(Icons.verified_user_rounded, color: AppColors.midTeal, size: 20),
        ],
      ),
    );
  }

  Widget _addParticipantCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('＋ Add Participant', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : null)),
          const SizedBox(height: 8),
          TextField(
            controller: _participantNameCtrl,
            style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : null),
            decoration: InputDecoration(
              hintText: 'Participant Name',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white54 : null),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : null,
              filled: _isDarkMode,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Shares:', style: GoogleFonts.inter(fontSize: 13, color: _isDarkMode ? Colors.white : null)),
              Row(
                children: [
                  IconButton(onPressed: _newParticipantShares > 1 ? () => setState(() => _newParticipantShares--) : null, icon: const Icon(Icons.remove)),
                  Text('$_newParticipantShares', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : null)),
                  IconButton(onPressed: _newParticipantShares < 7 ? () => setState(() => _newParticipantShares++) : null, icon: const Icon(Icons.add)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final name = _participantNameCtrl.text.trim();
              if (name.isEmpty) return;
              await _repo!.addParticipant(name, _newParticipantShares);
              _participantNameCtrl.clear();
              setState(() => _newParticipantShares = 1);
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

  void _editParticipantDirect(QParticipant p) {
    final nameCtrl = TextEditingController(text: p.name);
    int shares = p.shares;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Edit participant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(onPressed: shares > 1 ? () => setD(() => shares--) : null, icon: const Icon(Icons.remove)),
                  Text('$shares share(s)'),
                  IconButton(onPressed: shares < 7 ? () => setD(() => shares++) : null, icon: const Icon(Icons.add)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await _repo!.updateParticipantDirect(p.id, name: nameCtrl.text.trim(), shares: shares);
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _requestParticipantEdit(QParticipant p) {
    final nameCtrl = TextEditingController(text: p.name);
    final reasonCtrl = TextEditingController();
    int shares = p.shares;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Request edit — ${p.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Only ${p.ownerName} can edit this directly. Propose a change and explain why.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Proposed name')),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(onPressed: shares > 1 ? () => setD(() => shares--) : null, icon: const Icon(Icons.remove)),
                  Text('$shares share(s)'),
                  IconButton(onPressed: shares < 7 ? () => setD(() => shares++) : null, icon: const Icon(Icons.add)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason (required)'), maxLines: 2),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (reasonCtrl.text.trim().isEmpty) return;
                await _repo!.submitEditRequest(
                  type: QEditTargetType.participant,
                  targetId: p.id,
                  targetLabel: p.name,
                  reason: reasonCtrl.text.trim(),
                  proposedChanges: {'name': nameCtrl.text.trim(), 'shares': shares},
                );
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Send request'),
            ),
          ],
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expenses', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16)),
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
                else if (!eSnap.hasData)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
                else if (expenses.isEmpty)
                  _emptyState('No expenses logged yet.')
                else
                  ...expenses.map((e) => _expenseCard(e, participants, myUid, fmt)),
                const SizedBox(height: 16),
                if (participants.isNotEmpty) _addExpenseCard(participants),
              ],
            );
          },
        );
      },
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
                Text('logged by ${isOwner ? "you" : e.ownerName}', style: GoogleFonts.inter(color: _isDarkMode ? Colors.white38 : Colors.grey[400], fontSize: 9)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('৳${fmt.format(e.amount)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : null)),
              if (isOwner)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                  onPressed: () => _repo!.deleteExpense(e.id),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request edit — ${e.category}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Only ${e.ownerName} can edit this directly. Propose a change and explain why.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 12),
            TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Proposed category')),
            const SizedBox(height: 8),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Proposed amount')),
            const SizedBox(height: 8),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason (required)'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              await _repo!.submitEditRequest(
                type: QEditTargetType.expense,
                targetId: e.id,
                targetLabel: e.category,
                reason: reasonCtrl.text.trim(),
                proposedChanges: {'category': categoryCtrl.text.trim(), 'amount': double.tryParse(amountCtrl.text) ?? e.amount},
              );
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Send request'),
          ),
        ],
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
                final balances = SettlementEngine.computeBalances(participants: participants, expenses: expenses, settlements: settlements);
                final suggestions = SettlementEngine.suggestPayments(balances);

                return ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    Text('Settlements & Reminders', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16)),
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
                      ...suggestions.map((s) => _suggestedPaymentTile(s, fmt)),

                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: participants.length < 2 ? null : () => _showRecordPaymentDialog(participants),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Record a different payment'),
                    ),

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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Participant', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(flex: 2, child: Text('Shares', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(flex: 3, child: Text('Owes', textAlign: TextAlign.end, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(flex: 3, child: Text('Paid', textAlign: TextAlign.end, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(flex: 3, child: Text('Balance', textAlign: TextAlign.end, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
              ],
            ),
          ),
          const Divider(height: 1),
          ...balances.map((b) {
            final balColor = b.effectiveBalance > 0.5
                ? AppColors.midTeal
                : (b.effectiveBalance < -0.5 ? AppColors.coralOrange : Colors.grey);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(b.participant.name, style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : Colors.black87))),
                  Expanded(flex: 2, child: Text('${b.participant.shares}', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white70 : Colors.grey[700]))),
                  Expanded(flex: 3, child: Text('৳${fmt.format(b.shareOfCost)}', textAlign: TextAlign.end, style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white70 : Colors.grey[700]))),
                  Expanded(flex: 3, child: Text('৳${fmt.format(b.totalPaid)}', textAlign: TextAlign.end, style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white70 : Colors.grey[700]))),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${b.effectiveBalance >= 0 ? '+' : '-'}৳${fmt.format(b.effectiveBalance.abs())}',
                      textAlign: TextAlign.end,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: balColor),
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

  Widget _suggestedPaymentTile(SuggestedPayment s, NumberFormat fmt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12)),
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
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              await _repo!.recordSettlement(from: s.from, to: s.to, amount: s.amount, confirmed: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.midTeal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
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
                await _repo!.recordSettlement(from: from, to: to, amount: amt, confirmed: true);
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
        final requests = (snap.data ?? []).where((r) => r.status == 'pending').toList();
        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Text('Edit Requests', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text("Only the person who added an entry can edit it directly. Anyone else can propose a change here, with a required reason.",
                style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 12, height: 1.4)),
            const SizedBox(height: 12),
            if (!snap.hasData)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
            else if (requests.isEmpty)
              _emptyState('No edit requests yet.')
            else
              ...requests.map((r) => _editRequestCard(r, myUid)),
          ],
        );
      },
    );
  }

  Widget _editRequestCard(QEditRequest r, String myUid) {
    final changeText = r.proposedChanges.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(r.targetType == QEditTargetType.participant ? Icons.person_outline : Icons.payment_outlined, size: 18, color: AppColors.coralOrange),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${r.targetType == QEditTargetType.participant ? "Participant" : "Expense"}: ${r.targetLabel}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : null)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Requested by ${r.requestedByName}', style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.white54 : Colors.grey[600])),
          const SizedBox(height: 4),
          Text('Proposed: $changeText', style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 4),
          Text('Reason: "${r.reason}"', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: _isDarkMode ? Colors.white60 : Colors.grey[700])),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(onPressed: () => _repo!.rejectEditRequest(r.id), child: const Text('Reject')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _repo!.approveEditRequest(r),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal, foregroundColor: Colors.white),
                child: const Text('Approve'),
              ),
            ],
          ),
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
    return StreamBuilder<Map<String, bool>>(
      stream: _repo!.watchChecklistState(),
      builder: (context, snap) {
        final state = snap.data ?? {};
        final doneCount = kQurbaniChecklist.where((i) => state[i.id] == true).length;
        final total = kQurbaniChecklist.length;
        final pct = total == 0 ? 0.0 : doneCount / total;

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Text('Activities Checklist', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('A step-by-step guide from preparation through distribution. Check items off as your household completes them.',
                style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 12, height: 1.4)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$doneCount of $total complete', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                Text('${(pct * 100).round()}%', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.midTeal)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.midTeal),
              ),
            ),
            const SizedBox(height: 16),
            for (final section in ['before', 'day', 'after']) ...[
              Text(_sectionTitles[section]!,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
              const SizedBox(height: 4),
              ...kQurbaniChecklist.where((i) => i.section == section).map((item) {
                final done = state[item.id] == true;
                return CheckboxListTile(
                  value: done,
                  title: Text(item.title, style: GoogleFonts.inter(fontSize: 12.5, color: _isDarkMode ? Colors.white : Colors.black87, height: 1.3)),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.midTeal,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => _repo!.setChecklistDone(item.id, val ?? false),
                );
              }),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRulesAndVerses() {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        Text('Rules & Verses', style: GoogleFonts.poppins(color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text("The Qur'anic basis and general fiqh guidelines for Qurbani.",
            style: GoogleFonts.inter(color: _isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 12, height: 1.4)),
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

        Text("From the Qur'an", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
        const SizedBox(height: 8),
        ...kQuranVerses.map((v) => _verseCard(v)),

        const SizedBox(height: 20),
        Text('Conditions on the animal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
        const SizedBox(height: 8),
        _ruleBullet('Must be from grazing livestock: goat/sheep, cow/buffalo, or camel — no other animals qualify.'),
        _ruleBullet('Must have reached the minimum age: sheep/goat ≈ 1 lunar year (a young sheep of ~6 months may qualify if it looks like a 1-year-old per some scholars), cow/buffalo ≈ 2 lunar years, camel ≈ 5 lunar years.'),
        _ruleBullet('Must be free of the four major defects agreed upon in hadith: clearly one-eyed/blind, clearly sick, clearly lame, and emaciated with no marrow in its bones.'),
        _ruleBullet('One goat or sheep counts as one full sacrifice for one person/household. One cow, buffalo, or camel can be shared between up to 7 people, each owning one share.'),

        const SizedBox(height: 20),
        Text('Timing', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
        const SizedBox(height: 8),
        _ruleBullet('The valid window is from after Eid al-Adha prayer on 10 Dhul Hijjah until sunset on 13 Dhul Hijjah (three days after Eid, by the majority view).'),
        _ruleBullet('Sacrificing before the Eid prayer (where applicable) is not counted as Qurbani — it is treated as ordinary charity, and the animal should be replaced.'),
        _ruleBullet('If a person genuinely intends to sacrifice and it is within the first ten days of Dhul Hijjah, many scholars recommend they avoid cutting their hair and nails until after the sacrifice, based on hadith guidance — this is recommended, not obligatory, and applies to the person sacrificing, not to those merely giving them money.'),

        const SizedBox(height: 20),
        Text('Distribution of meat', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
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
