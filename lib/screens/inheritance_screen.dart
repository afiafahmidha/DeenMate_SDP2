import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../widgets/auth_header.dart'; // AppColors

const Color kLinkGreen = Color(0xFF6FE6A8);


// ENTRY POINT
// ============================================================
class InheritanceGuideScreen extends StatelessWidget {
  const InheritanceGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => const InheritanceScreen();
}


// MODELS
// ============================================================
enum Gender { male, female }

class RelativeNode {
  final String id;
  final String label;
  final String? customName;
  final Gender gender;
  final int level;
  final String relationKey;
  final String? parentId; // nephew→brother, son/daughter→wife

  RelativeNode({
    required this.id,
    required this.label,
    this.customName,
    required this.gender,
    required this.level,
    required this.relationKey,
    this.parentId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'customName': customName,
        'gender': gender == Gender.male ? 'male' : 'female',
        'level': level,
        'relationKey': relationKey,
        'parentId': parentId,
      };

  factory RelativeNode.fromJson(Map<String, dynamic> json) => RelativeNode(
        id: json['id'] as String,
        label: json['label'] as String,
        customName: json['customName'] as String?,
        gender: json['gender'] == 'male' ? Gender.male : Gender.female,
        level: json['level'] as int,
        relationKey: json['relationKey'] as String,
        parentId: json['parentId'] as String?,
      );
}

class FaraidShareResult {
  final String heirKey;
  final String label;
  final double fraction;
  final String fractionReadable;
  final double percentage;
  final String note;
  final bool excluded;
  final int level;

  FaraidShareResult({
    required this.heirKey,
    required this.label,
    required this.fraction,
    required this.fractionReadable,
    required this.percentage,
    required this.note,
    this.excluded = false,
    this.level = 0,
  });
}


// FARAID ENGINE (Hanafi-style, with exclusion notes)
// ============================================================
class FaraidEngine {
  static const Map<String, int> heirLevel = {
    'husband': 0, 'wife': 0,
    'son': 1, 'daughter': 1, 'grandson': 2, 'granddaughter': 2,
    'father': -1, 'mother': -1,
    'pGrandfather': -2, 'pGrandmother': -2, 'mGrandmother': -2,
    'fullBrother': 0, 'fullSister': 0, 'paternalBrother': 0,
    'paternalSister': 0, 'maternalSibling': 0,
    'fullNephew': 1, 'paternalNephew': 1,
    'fullUncle': -1, 'paternalUncle': -1,
    'fullCousin': 0, 'paternalCousin': 0,
  };

  static const Map<String, int> displayOrder = {
    'pGrandfather': 0, 'pGrandmother': 1, 'mGrandmother': 2,
    'father': 3, 'mother': 4, 'husband': 5, 'wife': 6,
    'fullBrother': 7, 'fullSister': 8, 'paternalBrother': 9,
    'paternalSister': 10, 'maternalSibling': 11,
    'fullUncle': 12, 'paternalUncle': 13, 'fullCousin': 14, 'paternalCousin': 15,
    'son': 16, 'daughter': 17, 'grandson': 18, 'granddaughter': 19,
    'fullNephew': 20, 'paternalNephew': 21,
  };

  static List<FaraidShareResult> calculate({
    required Gender meGender,
    required Map<String, int> heirCounts,
  }) {
    final results = <FaraidShareResult>[];
    int cnt(String k) => heirCounts[k] ?? 0;
    String plural(int n, String one, String many) => n > 1 ? '$n $many' : one;

    final sons = cnt('son');
    final daughters = cnt('daughter');
    final grandsons = cnt('grandson');
    final granddaughters = cnt('granddaughter');
    final father = cnt('father') > 0;
    final mother = cnt('mother') > 0;
    final pgf = cnt('pGrandfather') > 0;
    final pgm = cnt('pGrandmother') > 0;
    final mgm = cnt('mGrandmother') > 0;
    final wives = cnt('wife');
    final husband = cnt('husband') > 0;
    final fb = cnt('fullBrother');
    final fs = cnt('fullSister');
    final pb = cnt('paternalBrother');
    final ps = cnt('paternalSister');
    final ms = cnt('maternalSibling');
    final fn = cnt('fullNephew');
    final pn = cnt('paternalNephew');
    final fu = cnt('fullUncle');
    final pu = cnt('paternalUncle');
    final fcz = cnt('fullCousin');
    final pcz = cnt('paternalCousin');

    final hasMaleDesc = sons > 0 || grandsons > 0;
    final hasFemDesc = daughters > 0 || granddaughters > 0;
    final hasDesc = hasMaleDesc || hasFemDesc;
    final gfActs = !father && pgf;
    final sibTotal = fb + fs + pb + ps + ms;

    void add(String key, String label, double f, String note) {
      results.add(FaraidShareResult(
        heirKey: key,
        label: label,
        fraction: f,
        fractionReadable: _toReadableFraction(f),
        percentage: f * 100,
        note: note,
        level: heirLevel[key] ?? 0,
      ));
    }

    void exclude(String key, String label, String note) {
      results.add(FaraidShareResult(
        heirKey: key,
        label: label,
        fraction: 0,
        fractionReadable: '0',
        percentage: 0,
        note: note,
        excluded: true,
        level: heirLevel[key] ?? 0,
      ));
    }

    bool has(String key) => results.any((r) => r.heirKey == key);
    double used() =>
        results.where((r) => !r.excluded).fold(0.0, (s, r) => s + r.fraction);

    void boost(String key, double extra, String note) {
      final i = results.indexWhere((r) => r.heirKey == key && !r.excluded);
      if (i == -1) return;
      final e = results[i];
      final nf = e.fraction + extra;
      results[i] = FaraidShareResult(
        heirKey: e.heirKey,
        label: e.label,
        fraction: nf,
        fractionReadable: _toReadableFraction(nf),
        percentage: nf * 100,
        note: note,
        level: e.level,
      );
    }

    // ---------- 1. SPOUSE ----------
    if (meGender == Gender.male && wives > 0) {
      final f = hasDesc ? 1 / 8 : 1 / 4;
      add(
        'wife',
        plural(wives, 'Wife', 'Wives'),
        f,
        hasDesc
            ? 'Fixed 1/8 (children exist)${wives > 1 ? ' — shared, each ${_toReadableFraction(f / wives)}' : ''}'
            : 'Fixed 1/4 (no children)${wives > 1 ? ' — shared, each ${_toReadableFraction(f / wives)}' : ''}',
      );
    }
    if (meGender == Gender.female && husband) {
      final f = hasDesc ? 1 / 4 : 1 / 2;
      add('husband', 'Husband', f,
          hasDesc ? 'Fixed 1/4 (children exist)' : 'Fixed 1/2 (no children)');
    }

    // ---------- 2. FATHER / GRANDFATHER ----------
    bool fatherResiduary = false;
    bool gfResiduary = false;

    if (father) {
      if (hasMaleDesc) {
        add('father', 'Father', 1 / 6, 'Fixed 1/6 — male descendant present');
      } else if (hasDesc) {
        add('father', 'Father', 1 / 6, 'Fixed 1/6 + remainder (daughters only)');
        fatherResiduary = true;
      } else {
        fatherResiduary = true;
      }
    }
    if (pgf) {
      if (father) {
        exclude('pGrandfather', 'Paternal Grandfather', 'Excluded — father is alive');
      } else if (hasMaleDesc) {
        add('pGrandfather', 'Paternal Grandfather', 1 / 6,
            'Fixed 1/6 — stands in for the father');
      } else if (hasDesc) {
        add('pGrandfather', 'Paternal Grandfather', 1 / 6,
            'Fixed 1/6 + remainder (in father\'s place)');
        gfResiduary = true;
      } else {
        gfResiduary = true;
      }
    }
    // ---------- 3. MOTHER & GRANDMOTHERS ----------
    if (mother) {
      final oneSixth = hasDesc || sibTotal >= 2;
      add('mother', 'Mother', oneSixth ? 1 / 6 : 1 / 3,
          oneSixth ? 'Fixed 1/6 (children or 2+ siblings)' : 'Fixed 1/3');
    }
    final pgmEligible = pgm && !father && !mother;
    final mgmEligible = mgm && !mother;
    final bothGm = pgmEligible && mgmEligible;
    if (pgm) {
      if (!pgmEligible) {
        exclude('pGrandmother', 'Paternal Grandmother',
            'Excluded — ${mother ? 'mother' : 'father'} is alive');
      } else {
        add('pGrandmother', 'Paternal Grandmother', bothGm ? 1 / 12 : 1 / 6,
            bothGm ? '1/6 shared with maternal grandmother' : 'Fixed 1/6');
      }
    }
    if (mgm) {
      if (!mgmEligible) {
        exclude('mGrandmother', 'Maternal Grandmother', 'Excluded — mother is alive');
      } else {
        add('mGrandmother', 'Maternal Grandmother', bothGm ? 1 / 12 : 1 / 6,
            bothGm ? '1/6 shared with paternal grandmother' : 'Fixed 1/6');
      }
    }
    // ---------- 4. MATERNAL SIBLINGS ----------
    if (ms > 0) {
      if (hasDesc || father || pgf) {
        exclude(
            'maternalSibling',
            plural(ms, 'Maternal Sibling', 'Maternal Siblings'),
            'Excluded — blocked by ${hasDesc ? 'a descendant' : father ? 'the father' : 'the grandfather'}');
      } else {
        add(
            'maternalSibling',
            plural(ms, 'Maternal Sibling', 'Maternal Siblings'),
            ms == 1 ? 1 / 6 : 1 / 3,
            ms == 1
                ? 'Fixed 1/6 (Kalalah case)'
                : 'Fixed 1/3 shared equally — male & female alike');
      }
    }
    // ---------- 5. DAUGHTERS / GRANDCHILDREN ----------
    if (sons == 0 && daughters > 0) {
      add('daughter', plural(daughters, 'Daughter', 'Daughters'),
          daughters == 1 ? 1 / 2 : 2 / 3,
          daughters == 1 ? 'Fixed 1/2 (only daughter)' : 'Fixed 2/3 shared');
    }
    if (sons > 0) {
      if (grandsons > 0) {
        exclude('grandson', plural(grandsons, 'Grandson', 'Grandsons'),
            'Excluded — son is alive');
      }
      if (granddaughters > 0) {
        exclude('granddaughter',
            plural(granddaughters, 'Granddaughter', 'Granddaughters'),
            'Excluded — son is alive');
      }
    } else if (grandsons == 0 && granddaughters > 0) {
      if (daughters == 0) {
        add('granddaughter',
            plural(granddaughters, 'Granddaughter', 'Granddaughters'),
            granddaughters == 1 ? 1 / 2 : 2 / 3,
            'Fixed share — stands in place of daughters');
      } else if (daughters == 1) {
        add('granddaughter',
            plural(granddaughters, 'Granddaughter', 'Granddaughters'), 1 / 6,
            'Fixed 1/6 — completes 2/3 with the daughter');
      } else {
        exclude('granddaughter',
            plural(granddaughters, 'Granddaughter', 'Granddaughters'),
            'Excluded — daughters already took the full 2/3');
      }
    }

    // ---------- 6. FULL & PATERNAL SISTERS (fard paths) ----------
    bool fsMaaGhayr = false;
    if (fs > 0 && fb == 0) {
      if (hasMaleDesc || father || gfActs) {
        exclude('fullSister', plural(fs, 'Full Sister', 'Full Sisters'),
            'Excluded — blocked by ${hasMaleDesc ? 'a son/grandson' : father ? 'the father' : 'the grandfather'}');
      } else if (hasFemDesc) {
        fsMaaGhayr = true;
      } else {
        add('fullSister', plural(fs, 'Full Sister', 'Full Sisters'),
            fs == 1 ? 1 / 2 : 2 / 3,
            fs == 1 ? 'Fixed 1/2 (Kalalah case)' : 'Fixed 2/3 shared');
      }
    }
    bool psMaaGhayr = false;
    if (ps > 0 && pb == 0) {
      if (hasMaleDesc || father || gfActs || fb > 0) {
        exclude('paternalSister', plural(ps, 'Paternal Sister', 'Paternal Sisters'),
            'Excluded — blocked by ${fb > 0 ? 'a full brother' : hasMaleDesc ? 'a son/grandson' : 'the father/grandfather'}');
      } else if (fsMaaGhayr) {
        exclude('paternalSister', plural(ps, 'Paternal Sister', 'Paternal Sisters'),
            'Excluded — full sister takes the residue with the daughters');
      } else if (fs >= 2) {
        exclude('paternalSister', plural(ps, 'Paternal Sister', 'Paternal Sisters'),
            'Excluded — full sisters completed the 2/3 maximum');
      } else if (fs == 1) {
        add('paternalSister', plural(ps, 'Paternal Sister', 'Paternal Sisters'),
            1 / 6, 'Fixed 1/6 — completes 2/3 with the full sister');
      } else if (hasFemDesc) {
        psMaaGhayr = true;
      } else {
        add('paternalSister', plural(ps, 'Paternal Sister', 'Paternal Sisters'),
            ps == 1 ? 1 / 2 : 2 / 3,
            ps == 1 ? 'Fixed 1/2 (no full siblings)' : 'Fixed 2/3 shared');
      }
    }
    // ---------- 7. RESIDUE (ASABA CHAIN) ----------
    double remainder = math.max(0.0, 1.0 - used());
    bool claimed = false;
    String blocker = '';

    if (sons > 0) {
      final units = (sons * 2 + daughters).toDouble();
      add('son', plural(sons, 'Son', 'Sons'), remainder * sons * 2 / units,
          'Residuary (Asaba) — double a daughter\'s share');
      if (daughters > 0) {
        add('daughter', plural(daughters, 'Daughter', 'Daughters'),
            remainder * daughters / units, 'Residuary with sons (2:1 ratio)');
      }
      claimed = true;
      blocker = 'son';
    } else if (grandsons > 0) {
      final units = (grandsons * 2 + granddaughters).toDouble();
      add('grandson', plural(grandsons, 'Grandson', 'Grandsons'),
          remainder * grandsons * 2 / units, 'Residuary (Asaba) — in sons\' place');
      if (granddaughters > 0) {
        add('granddaughter',
            plural(granddaughters, 'Granddaughter', 'Granddaughters'),
            remainder * granddaughters / units,
            'Residuary with grandsons (2:1 ratio)');
      }
      claimed = true;
      blocker = 'grandson';
    } else if (fatherResiduary) {
      if (has('father')) {
        boost('father', remainder, 'Fixed 1/6 + remainder (Asaba)');
      } else {
        add('father', 'Father', remainder, 'Residuary (Asaba) — no descendants');
      }
      claimed = true;
      blocker = 'father';
    } else if (gfResiduary) {
      if (has('pGrandfather')) {
        boost('pGrandfather', remainder, 'Fixed 1/6 + remainder (Asaba)');
      } else {
        add('pGrandfather', 'Paternal Grandfather', remainder,
            'Residuary (Asaba) — in father\'s place');
      }
      claimed = true;
      blocker = 'grandfather';
    } else if (fb > 0) {
      final units = (fb * 2 + fs).toDouble();
      add('fullBrother', plural(fb, 'Full Brother', 'Full Brothers'),
          remainder * fb * 2 / units, 'Residuary (Asaba)');
      if (fs > 0) {
        add('fullSister', plural(fs, 'Full Sister', 'Full Sisters'),
            remainder * fs / units, 'Residuary with brothers (2:1 ratio)');
      }
      claimed = true;
      blocker = 'full brother';
    } else if (fsMaaGhayr) {
      add('fullSister', plural(fs, 'Full Sister', 'Full Sisters'), remainder,
          'Residuary with daughters (Asaba ma\'a al-ghayr)');
      claimed = true;
      blocker = 'full sister';
    } else if (pb > 0) {
      final units = (pb * 2 + ps).toDouble();
      add('paternalBrother', plural(pb, 'Paternal Brother', 'Paternal Brothers'),
          remainder * pb * 2 / units, 'Residuary (Asaba)');
      if (ps > 0) {
        add('paternalSister', plural(ps, 'Paternal Sister', 'Paternal Sisters'),
            remainder * ps / units, 'Residuary with brothers (2:1 ratio)');
      }
      claimed = true;
      blocker = 'paternal brother';
    } else if (psMaaGhayr) {
      add('paternalSister', plural(ps, 'Paternal Sister', 'Paternal Sisters'),
          remainder, 'Residuary with daughters (Asaba ma\'a al-ghayr)');
      claimed = true;
      blocker = 'paternal sister';
    } else if (fn > 0) {
      add('fullNephew', plural(fn, 'Full Nephew', 'Full Nephews'), remainder,
          'Residuary (Asaba)');
      claimed = true;
      blocker = 'full nephew';
    } else if (pn > 0) {
      add('paternalNephew', plural(pn, 'Paternal Nephew', 'Paternal Nephews'),
          remainder, 'Residuary (Asaba)');
      claimed = true;
      blocker = 'paternal nephew';
    } else if (fu > 0) {
      add('fullUncle', plural(fu, 'Full Uncle', 'Full Uncles'), remainder,
          'Residuary (Asaba)');
      claimed = true;
      blocker = 'full uncle';
    } else if (pu > 0) {
      add('paternalUncle', plural(pu, 'Paternal Uncle', 'Paternal Uncles'),
          remainder, 'Residuary (Asaba)');
      claimed = true;
      blocker = 'paternal uncle';
    } else if (fcz > 0) {
      add('fullCousin', plural(fcz, 'Full Cousin', 'Full Cousins'), remainder,
          'Residuary (Asaba)');
      claimed = true;
      blocker = 'full cousin';
    } else if (pcz > 0) {
      add('paternalCousin', plural(pcz, 'Paternal Cousin', 'Paternal Cousins'),
          remainder, 'Residuary (Asaba)');
      claimed = true;
      blocker = 'paternal cousin';
    }

    // ---------- 8. EXCLUSION SWEEP ----------
    final sweep = <List<dynamic>>[
      ['fullBrother', fb, 'Full Brother', 'Full Brothers'],
      ['fullSister', fs, 'Full Sister', 'Full Sisters'],
      ['paternalBrother', pb, 'Paternal Brother', 'Paternal Brothers'],
      ['paternalSister', ps, 'Paternal Sister', 'Paternal Sisters'],
      ['fullNephew', fn, 'Full Nephew', 'Full Nephews'],
      ['paternalNephew', pn, 'Paternal Nephew', 'Paternal Nephews'],
      ['fullUncle', fu, 'Full Uncle', 'Full Uncles'],
      ['paternalUncle', pu, 'Paternal Uncle', 'Paternal Uncles'],
      ['fullCousin', fcz, 'Full Cousin', 'Full Cousins'],
      ['paternalCousin', pcz, 'Paternal Cousin', 'Paternal Cousins'],
    ];
    for (final s in sweep) {
      final key = s[0] as String;
      final n = s[1] as int;
      if (n > 0 && !has(key)) {
        exclude(key, plural(n, s[2] as String, s[3] as String),
            claimed
                ? 'Excluded — the $blocker is nearer in line (Asaba)'
                : 'Excluded — blocked by nearer relatives');
      }
    }

    // ---------- 9. AWL (over-subscription) ----------
    double total = used();
    if (total > 1.001) {
      final scale = 1.0 / total;
      for (int i = 0; i < results.length; i++) {
        if (results[i].excluded) continue;
        final e = results[i];
        final nf = e.fraction * scale;
        results[i] = FaraidShareResult(
          heirKey: e.heirKey,
          label: e.label,
          fraction: nf,
          fractionReadable: _toReadableFraction(nf),
          percentage: nf * 100,
          note: '${e.note} [Awl — proportionally reduced]',
          level: e.level,
        );
      }
    }
    // ---------- 10. RADD (surplus returned) ----------
    else if (!claimed) {
      total = used();
      if (total > 0 && total < 0.999) {
        final radd = 1.0 - total;
        final nonSpouse = results
            .where((r) =>
                !r.excluded && r.heirKey != 'wife' && r.heirKey != 'husband')
            .fold(0.0, (s, r) => s + r.fraction);
        if (nonSpouse > 0) {
          for (int i = 0; i < results.length; i++) {
            final e = results[i];
            if (e.excluded || e.heirKey == 'wife' || e.heirKey == 'husband') {
              continue;
            }
            final nf = e.fraction + radd * (e.fraction / nonSpouse);
            results[i] = FaraidShareResult(
              heirKey: e.heirKey,
              label: e.label,
              fraction: nf,
              fractionReadable: _toReadableFraction(nf),
              percentage: nf * 100,
              note: '${e.note} [Radd — increased]',
              level: e.level,
            );
          }
        } else {
          final i = results.indexWhere((r) =>
              !r.excluded && (r.heirKey == 'wife' || r.heirKey == 'husband'));
          if (i != -1) {
            final e = results[i];
            final nf = e.fraction + radd;
            results[i] = FaraidShareResult(
              heirKey: e.heirKey,
              label: e.label,
              fraction: nf,
              fractionReadable: _toReadableFraction(nf),
              percentage: nf * 100,
              note: 'Sole heir — remainder returned [Radd]',
              level: e.level,
            );
          }
        }
      }
    }

    results.sort((a, b) => (displayOrder[a.heirKey] ?? 99)
        .compareTo(displayOrder[b.heirKey] ?? 99));
    return results;
  }

  static String _toReadableFraction(double f) {
    if (f <= 0) return '0';
    const common = <String, double>{
      '1/2': 0.5, '1/3': 1 / 3, '2/3': 2 / 3, '1/4': 0.25, '3/4': 0.75,
      '1/6': 1 / 6, '1/8': 0.125, '1/12': 1 / 12, '1/16': 1 / 16,
      '1/24': 1 / 24, '5/24': 5 / 24, '7/24': 7 / 24,
    };
    for (final e in common.entries) {
      if ((f - e.value).abs() < 0.004) return e.key;
    }
    return '${(f * 100).toStringAsFixed(1)}%';
  }
}

// FAMILY TREE LAYOUT ENGINE

class TreeLayoutResult {
  final double width;
  final double height;
  final Map<String, Offset> centers;
  final List<List<Offset>> edges;

  TreeLayoutResult({
    required this.width,
    required this.height,
    required this.centers,
    required this.edges,
  });
}

class FamilyTreeLayout {
  static const double cardW = 128;
  static const double cardH = 46;

  static const Map<int, List<String>> _order = {
    -2: ['pGrandfather', 'pGrandmother', 'mGrandmother'],
    -1: ['fullUncle', 'paternalUncle', 'father', 'mother'],
    0: [
      'fullCousin', 'paternalCousin', 'fullBrother', 'fullSister',
      'me', 'wife', 'husband',
      'paternalBrother', 'paternalSister', 'maternalSibling',
    ],
    1: ['fullNephew', 'paternalNephew', 'son', 'daughter'],
    2: ['grandson', 'granddaughter'],
  };

  static TreeLayoutResult compute(
    List<RelativeNode> relatives,
    double minWidth, {
    Map<String, Offset>? nodeOverrides,
  }) {
    const levelY = <int, double>{-2: 80, -1: 205, 0: 330, 1: 455, 2: 575};
    const spacing = 152.0;
    const half = cardH / 2;

    final byLevel = <int, List<RelativeNode>>{-2: [], -1: [], 0: [], 1: [], 2: []};
    for (final r in relatives) {
      (byLevel[r.level] ?? byLevel[0]!).add(r);
    }
    byLevel.forEach((lvl, list) {
      final ord = _order[lvl] ?? const <String>[];
      list.sort((a, b) {
        int ia = ord.indexOf(a.relationKey);
        int ib = ord.indexOf(b.relationKey);
        if (ia < 0) ia = 99;
        if (ib < 0) ib = 99;
        return ia != ib ? ia - ib : a.id.compareTo(b.id);
      });
    });

    int maxCount = 1;
    for (final l in byLevel.values) {
      if (l.length > maxCount) maxCount = l.length;
    }
    final width = math.max(minWidth, maxCount * spacing + 90);

    final centers = <String, Offset>{};
    byLevel.forEach((lvl, list) {
      final startX = (width - list.length * spacing) / 2 + spacing / 2;
      for (int i = 0; i < list.length; i++) {
        centers[list[i].id] = Offset(startX + i * spacing, levelY[lvl]!);
      }
    });

    if (nodeOverrides != null) {
      for (final entry in nodeOverrides.entries) {
        if (centers.containsKey(entry.key)) {
          centers[entry.key] = entry.value;
        }
      }
    }

    // ---- helpers ----
    Offset? one(String key) {
      for (final r in relatives) {
        if (r.relationKey == key && centers.containsKey(r.id)) {
          return centers[r.id];
        }
      }
      return null;
    }

    List<Offset> all(String key) => [
          for (final r in relatives)
            if (r.relationKey == key && centers.containsKey(r.id))
              centers[r.id]!,
        ];

    List<RelativeNode> allNodes(String key) => [
          for (final r in relatives)
            if (r.relationKey == key && centers.containsKey(r.id)) r,
        ];

    Offset top(Offset c) => Offset(c.dx, c.dy - half);
    Offset bottom(Offset c) => Offset(c.dx, c.dy + half);

    final edges = <List<Offset>>[];

    // Where a line from `center` toward `toward` crosses the card's own
    // rectangle border — lets a link attach to ANY side of a card
    // (left/right/top/bottom), whichever faces the other end.
    Offset borderPoint(Offset center, Offset toward) {
      final dx = toward.dx - center.dx;
      final dy = toward.dy - center.dy;
      if (dx == 0 && dy == 0) return center;
      final halfW = cardW / 2;
      final halfH = cardH / 2;
      final scaleX = dx != 0 ? halfW / dx.abs() : double.infinity;
      final scaleY = dy != 0 ? halfH / dy.abs() : double.infinity;
      final scale = math.min(scaleX, scaleY);
      return Offset(center.dx + dx * scale, center.dy + dy * scale);
    }

    List<Offset> quadBezier(Offset p0, Offset p1, Offset p2, {int segments = 16}) {
      final pts = <Offset>[];
      for (int i = 0; i <= segments; i++) {
        final t = i / segments;
        final mt = 1 - t;
        final x = mt * mt * p0.dx + 2 * mt * t * p1.dx + t * t * p2.dx;
        final y = mt * mt * p0.dy + 2 * mt * t * p1.dy + t * t * p2.dy;
        pts.add(Offset(x, y));
      }
      return pts;
    }

    // Bows a link into a gentle curve whenever the two ends aren't roughly
    // aligned — this is what keeps it from slicing straight through a card
    // that's ended up sitting between them after dragging.
    List<Offset> bow(Offset start, Offset end) {
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      if (dx.abs() < 6 || dy.abs() < 6) return [start, end];
      final length = math.sqrt(dx * dx + dy * dy);
      final midX = (start.dx + end.dx) / 2;
      final midY = (start.dy + end.dy) / 2;
      final perpX = -dy / length;
      final perpY = dx / length;
      final amount = math.min(46.0, length * 0.2);
      final control = Offset(midX + perpX * amount, midY + perpY * amount);
      return quadBezier(start, control, end);
    }

    // Card-to-card link: attaches to whichever side of each card faces
    // the other, wherever that card currently is.
    List<Offset> connector(Offset aCenter, Offset bCenter) {
      final start = borderPoint(aCenter, bCenter);
      final end = borderPoint(bCenter, aCenter);
      return bow(start, end);
    }

    // Anchor-to-card link: the anchor is a plain point (e.g. the midpoint
    // of a couple's connecting bar), the other end is a real card.
    List<Offset> connectFromAnchor(Offset anchor, Offset childCenter) {
      final end = borderPoint(childCenter, anchor);
      return bow(anchor, end);
    }

    void coupleBar(Offset a, Offset b) {
      final l = a.dx < b.dx ? a : b;
      final r = a.dx < b.dx ? b : a;
      edges.add([Offset(l.dx + cardW / 2, l.dy), Offset(r.dx - cardW / 2, r.dy)]);
    }

    // ---- 1. Paternal grandparents ----
    final gpf = one('pGrandfather');
    final gpm = one('pGrandmother');
    Offset? grandAnchor;
    if (gpf != null && gpm != null) {
      coupleBar(gpf, gpm);
      grandAnchor = Offset((gpf.dx + gpm.dx) / 2, gpf.dy + half);
    } else if (gpf != null) {
      grandAnchor = bottom(gpf);
    } else if (gpm != null) {
      grandAnchor = bottom(gpm);
    }

    final f = one('father');
    final m = one('mother');
    if (grandAnchor != null && f != null) {
      edges.add(connectFromAnchor(grandAnchor, f));
    }
    for (final u in [...all('fullUncle'), ...all('paternalUncle')]) {
      if (grandAnchor != null) {
        edges.add(connectFromAnchor(grandAnchor, u));
      } else if (f != null) {
        edges.add(connector(f, u));
      }
    }

    // ---- 2. Maternal grandmother → mother ----
    final mgmC = one('mGrandmother');
    if (mgmC != null && m != null) edges.add(connector(mgmC, m));

    // ---- 3. Parents couple → me & full siblings ----
    Offset? parentAnchor;
    if (f != null && m != null) {
      coupleBar(f, m);
      parentAnchor = Offset((f.dx + m.dx) / 2, f.dy + half);
    } else if (f != null) {
      parentAnchor = bottom(f);
    } else if (m != null) {
      parentAnchor = bottom(m);
    }

    Offset meC = const Offset(0, 0);
    for (final r in relatives) {
      if (r.id == 'me') meC = centers[r.id]!;
    }
    if (parentAnchor != null) edges.add(connectFromAnchor(parentAnchor, meC));

    for (final s in [...all('fullBrother'), ...all('fullSister')]) {
      if (parentAnchor != null) {
        edges.add(connectFromAnchor(parentAnchor, s));
      } else {
        edges.add(connector(meC, s));
      }
    }
    for (final s in [...all('paternalBrother'), ...all('paternalSister')]) {
      if (f != null) {
        edges.add(connector(f, s));
      } else if (parentAnchor != null) {
        edges.add(connectFromAnchor(parentAnchor, s));
      } else {
        edges.add(connector(meC, s));
      }
    }
    for (final s in all('maternalSibling')) {
      if (m != null) {
        edges.add(connector(m, s));
      } else if (parentAnchor != null) {
        edges.add(connectFromAnchor(parentAnchor, s));
      } else {
        edges.add(connector(meC, s));
      }
    }

    // ---- 4. Me ↔ each spouse ----
    final spouseNodes = allNodes('wife') + allNodes('husband');
    final Map<String, Offset> wifeAnchors = {};
    for (final sp in spouseNodes) {
      final spC = centers[sp.id]!;
      coupleBar(meC, spC);
      wifeAnchors[sp.id] = Offset((meC.dx + spC.dx) / 2, meC.dy + half);
    }
    final Offset defaultCoupleAnchor = spouseNodes.isNotEmpty
        ? wifeAnchors[spouseNodes.first.id]!
        : bottom(meC);

    // Children: connect from specific wife midpoint or default couple anchor
    for (final child in allNodes('son') + allNodes('daughter')) {
      final childC = centers[child.id];
      if (childC == null) continue;
      Offset anchor;
      if (child.parentId != null && wifeAnchors.containsKey(child.parentId)) {
        anchor = wifeAnchors[child.parentId!]!;
      } else {
        anchor = defaultCoupleAnchor;
      }
      edges.add(connectFromAnchor(anchor, childC));
    }

    // ---- 5. Son → grandchildren ----
    final sonC = one('son');
    final grandAnchorC = sonC != null ? bottom(sonC) : bottom(meC);
    for (final g in [...all('grandson'), ...all('granddaughter')]) {
      edges.add(connectFromAnchor(grandAnchorC, g));
    }

    // ---- 6. Brothers → nephews using parentId ----
    for (final nephew in allNodes('fullNephew')) {
      final nC = centers[nephew.id];
      if (nC == null) continue;
      Offset brotherAnchor;
      if (nephew.parentId != null && centers.containsKey(nephew.parentId)) {
        brotherAnchor = bottom(centers[nephew.parentId!]!);
      } else if (one('fullBrother') != null) {
        brotherAnchor = bottom(one('fullBrother')!);
      } else {
        brotherAnchor = bottom(meC);
      }
      edges.add(connectFromAnchor(brotherAnchor, nC));
    }
    for (final nephew in allNodes('paternalNephew')) {
      final nC = centers[nephew.id];
      if (nC == null) continue;
      Offset brotherAnchor;
      if (nephew.parentId != null && centers.containsKey(nephew.parentId)) {
        brotherAnchor = bottom(centers[nephew.parentId!]!);
      } else if (one('paternalBrother') != null) {
        brotherAnchor = bottom(one('paternalBrother')!);
      } else {
        brotherAnchor = bottom(meC);
      }
      edges.add(connectFromAnchor(brotherAnchor, nC));
    }

    // ---- 7. Uncles → cousins ----
    final fuC = one('fullUncle');
    if (fuC != null) {
      for (final c in all('fullCousin')) {
        edges.add(connector(fuC, c));
      }
    }
    final puC = one('paternalUncle');
    if (puC != null) {
      for (final c in all('paternalCousin')) {
        edges.add(connector(puC, c));
      }
    }

    return TreeLayoutResult(
      width: width,
      height: 655,
      centers: centers,
      edges: edges,
    );
  }
}


// MAIN SCREEN

class InheritanceScreen extends StatefulWidget {
  const InheritanceScreen({super.key});

  @override
  State<InheritanceScreen> createState() => _InheritanceScreenState();
}

class _InheritanceScreenState extends State<InheritanceScreen>
    with TickerProviderStateMixin {
  int _tab = 0;
  static const _tabLabels = ['Family Tree', 'Calculation', 'Scenarios', 'Rules'];
  static const _tabIcons = [
    Icons.account_tree_rounded,
    Icons.calculate_rounded,
    Icons.auto_awesome_rounded,
    Icons.menu_book_rounded,
  ];
  late AnimationController _lineAnimationController;
  bool _isDarkMode = false;
  bool _boardLocked = false;
  final TransformationController _treeTransformController = TransformationController();

  // Drag-to-reposition: stores user-moved node positions
  final Map<String, Offset> _nodeOffsets = {};
  String? _draggingNodeId; // which node is currently being dragged
  Offset? _dragStartPos;
  bool _editLayoutMode = false; // when true, one-finger drag moves cards; when false, it pans the board

  Offset _clampNodePosition(Offset pos, double maxWidth, double maxHeight) {
    const margin = 40.0;
    // Extra room so nodes can be dragged well past the auto-computed
    // layout box in any direction — left of "me", above the top row,
    // below the bottom row, etc.
    const extraRoom = 700.0;
    final minX = -extraRoom + FamilyTreeLayout.cardW / 2 + margin;
    final maxX = maxWidth + extraRoom - FamilyTreeLayout.cardW / 2 - margin;
    final minY = -extraRoom + FamilyTreeLayout.cardH / 2 + margin;
    final maxY = maxHeight + extraRoom - FamilyTreeLayout.cardH / 2 - margin;
    return Offset(pos.dx.clamp(minX, maxX), pos.dy.clamp(minY, maxY));
  }

  Gender _myGender = Gender.male;
  List<RelativeNode> _familyRelatives = [];
  List<FaraidShareResult> _familyResults = [];

  final Map<String, int> _scenarioHeirCounts = {
    'husband': 0, 'wife': 0, 'son': 0, 'daughter': 0,
    'grandson': 0, 'granddaughter': 0, 'father': 0, 'mother': 0,
    'pGrandfather': 0, 'pGrandmother': 0, 'mGrandmother': 0,
    'fullBrother': 0, 'fullSister': 0, 'paternalBrother': 0,
    'paternalSister': 0, 'maternalSibling': 0, 'fullNephew': 0,
    'paternalNephew': 0, 'fullUncle': 0, 'paternalUncle': 0,
    'fullCousin': 0, 'paternalCousin': 0,
  };
  Gender _scenarioDeceasedGender = Gender.male;
  List<FaraidShareResult>? _scenarioResults;
  List<Map<String, dynamic>> _savedScenarios = [];
  String? _activeScenarioName;

  // Singleton relations — can only appear once
  static const Set<String> _singletonKeys = {
    'father', 'mother', 'pGrandfather', 'pGrandmother', 'mGrandmother', 'husband',
  };

  @override
  void initState() {
    super.initState();
    _lineAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _loadState();
  }

  @override
  void dispose() {
    _lineAnimationController.dispose();
    _treeTransformController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    });

    // Load board lock state & saved transform matrix
    _boardLocked = prefs.getBool('inheritance_board_locked') ?? false;
    final matrixJson = prefs.getString('inheritance_locked_matrix');
    if (matrixJson != null) {
      try {
        final List list = jsonDecode(matrixJson);
        final storage = List<double>.from(list.cast<double>());
        _treeTransformController.value = Matrix4.fromList(storage);
      } catch (_) {}
    }

    // Load saved family tree from prefs
    final genderStr = prefs.getString('inheritance_my_gender');
    if (genderStr != null) {
      _myGender = genderStr == 'female' ? Gender.female : Gender.male;
    }

    final treeJson = prefs.getString('inheritance_family_tree');
    if (treeJson != null) {
      try {
        final list = jsonDecode(treeJson) as List;
        final loaded = list
            .map((e) => RelativeNode.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _familyRelatives = loaded;
          _ensureMeNodeExists();
          _recalculateFamilyShares();
        });
      } catch (_) {
        // If parse fails, start fresh
        _initEmptyTree();
      }
    } else {
      // First launch — just "Me", no auto Father/Mother
      _initEmptyTree();
    }

    final jsonStr = prefs.getString('inheritance_saved_scenarios');
    if (jsonStr != null) {
      try {
        final list = jsonDecode(jsonStr) as List;
        setState(() => _savedScenarios = list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      } catch (_) {}
    }

    // Load saved node positions (for drag-to-reposition)
    final offsetsJson = prefs.getString('inheritance_node_offsets');
    if (offsetsJson != null) {
      try {
        final raw = jsonDecode(offsetsJson) as Map<String, dynamic>;
        raw.forEach((k, v) {
          final entry = v as Map<String, dynamic>;
          _nodeOffsets[k] =
              Offset((entry['x'] as num).toDouble(), (entry['y'] as num).toDouble());
        });
      } catch (_) {}
    }

    // Sync / Load with Cloud Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['inheritance'] != null) {
            final inheritanceMap = data['inheritance'] as Map<String, dynamic>;
            final remoteFamilyTree = inheritanceMap['familyTree'] as List<dynamic>?;
            final remoteMyGender = inheritanceMap['myGender'] as String?;
            final remoteNodeOffsets = inheritanceMap['nodeOffsets'] as Map<String, dynamic>?;
            final remoteSavedScenarios = inheritanceMap['savedScenarios'] as List<dynamic>?;
            final remoteBoardLocked = inheritanceMap['boardLocked'] as bool?;
            final remoteLockedMatrix = inheritanceMap['lockedMatrix'] as List<dynamic>?;

            setState(() {
              if (remoteMyGender != null) {
                _myGender = remoteMyGender == 'female' ? Gender.female : Gender.male;
              }
              if (remoteFamilyTree != null) {
                try {
                  _familyRelatives = remoteFamilyTree
                      .map((e) => RelativeNode.fromJson(Map<String, dynamic>.from(e as Map)))
                      .toList();
                  _ensureMeNodeExists();
                  _recalculateFamilyShares();
                } catch (_) {}
              }
              if (remoteNodeOffsets != null) {
                _nodeOffsets.clear();
                remoteNodeOffsets.forEach((k, v) {
                  final entry = v as Map;
                  _nodeOffsets[k] = Offset((entry['x'] as num).toDouble(), (entry['y'] as num).toDouble());
                });
              }
              if (remoteSavedScenarios != null) {
                _savedScenarios = remoteSavedScenarios
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
              }
              if (remoteBoardLocked != null) {
                _boardLocked = remoteBoardLocked;
              }
              if (remoteLockedMatrix != null) {
                try {
                  final storage = List<double>.from(remoteLockedMatrix.cast<double>());
                  _treeTransformController.value = Matrix4.fromList(storage);
                } catch (_) {}
              }
            });

            // Save to local SharedPreferences to ensure synchronization
            if (remoteFamilyTree != null) {
              await prefs.setString('inheritance_family_tree', jsonEncode(remoteFamilyTree));
            }
            if (remoteMyGender != null) {
              await prefs.setString('inheritance_my_gender', remoteMyGender);
            }
            if (remoteNodeOffsets != null) {
              await prefs.setString('inheritance_node_offsets', jsonEncode(remoteNodeOffsets));
            }
            if (remoteSavedScenarios != null) {
              await prefs.setString('inheritance_saved_scenarios', jsonEncode(remoteSavedScenarios));
            }
            if (remoteBoardLocked != null) {
              await prefs.setBool('inheritance_board_locked', remoteBoardLocked);
            }
            if (remoteLockedMatrix != null) {
              await prefs.setString('inheritance_locked_matrix', jsonEncode(remoteLockedMatrix));
            }
          } else {
            // Document exists but no inheritance data, upload local data
            await _syncToFirestore();
          }
        } else {
          // Document does not exist, upload local data
          await _syncToFirestore();
        }
      } catch (e) {
        debugPrint("Error loading inheritance from Firestore: $e");
      }
    }
  }

  void _ensureMeNodeExists() {
    final idx = _familyRelatives.indexWhere((r) => r.id == 'me');
    if (idx == -1) {
      _familyRelatives.insert(
        0,
        RelativeNode(id: 'me', label: 'Me', gender: _myGender, level: 0, relationKey: 'me'),
      );
    } else {
      final meNode = _familyRelatives[idx];
      if (meNode.gender != _myGender) {
        _familyRelatives[idx] = RelativeNode(
          id: 'me',
          label: meNode.label,
          customName: meNode.customName,
          gender: _myGender,
          level: 0,
          relationKey: 'me',
        );
      }
    }
  }

  void _resetTreeLayout() async {
    setState(() {
      _nodeOffsets.clear();
      _ensureMeNodeExists();
      _treeTransformController.value = Matrix4.identity();
      _editLayoutMode = false;
      _boardLocked = false;
      _lineAnimationController.forward(from: 0);
      _recalculateFamilyShares();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('inheritance_node_offsets');
    await prefs.remove('inheritance_locked_matrix');
    await prefs.setBool('inheritance_board_locked', false);
    await _saveFamilyTree();
    if (mounted) {
      _snack('Family Tree & "Me" box reset to center!');
    }
  }

  void _initEmptyTree() {
    setState(() {
      _familyRelatives = [
        RelativeNode(id: 'me', label: 'Me', gender: _myGender, level: 0, relationKey: 'me'),
      ];
      _recalculateFamilyShares();
    });
  }

  String _formatScenarioDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM, yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }

  Future<void> _syncToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final familyTreeStr = prefs.getString('inheritance_family_tree');
      final myGenderStr = prefs.getString('inheritance_my_gender') ?? 'male';
      final offsetsStr = prefs.getString('inheritance_node_offsets');
      final boardLocked = prefs.getBool('inheritance_board_locked') ?? false;
      final matrixStr = prefs.getString('inheritance_locked_matrix');

      List<dynamic> familyTree = [];
      if (familyTreeStr != null) {
        try {
          familyTree = jsonDecode(familyTreeStr);
        } catch (_) {}
      }

      Map<String, dynamic> offsets = {};
      if (offsetsStr != null) {
        try {
          offsets = jsonDecode(offsetsStr);
        } catch (_) {}
      }

      List<dynamic> matrix = [];
      if (matrixStr != null) {
        try {
          matrix = jsonDecode(matrixStr);
        } catch (_) {}
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'inheritance': {
          'familyTree': familyTree,
          'myGender': myGenderStr,
          'nodeOffsets': offsets,
          'savedScenarios': _savedScenarios,
          'boardLocked': boardLocked,
          'lockedMatrix': matrix,
          'lastUpdated': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error syncing inheritance to Firestore: $e");
    }
  }

  Future<void> _saveFamilyTree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'inheritance_family_tree',
        jsonEncode(_familyRelatives.map((r) => r.toJson()).toList()));
    await prefs.setString(
        'inheritance_my_gender', _myGender == Gender.male ? 'male' : 'female');
    // Save dragged node positions
    final offsetMap = _nodeOffsets.map(
        (k, v) => MapEntry(k, <String, double>{'x': v.dx, 'y': v.dy}));
    await prefs.setString('inheritance_node_offsets', jsonEncode(offsetMap));
    await _syncToFirestore();
  }

  Future<void> _saveScenariosToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inheritance_saved_scenarios', jsonEncode(_savedScenarios));
    await _syncToFirestore();
  }

  void _recalculateFamilyShares() {
    final counts = <String, int>{};
    for (final r in _familyRelatives) {
      if (r.id == 'me') continue;
      counts[r.relationKey] = (counts[r.relationKey] ?? 0) + 1;
    }
    _familyResults = FaraidEngine.calculate(meGender: _myGender, heirCounts: counts);
  }

  void _addFamilyMember(String key, String label, Gender gender, int level,
      {String? customName, String? parentId}) {
    final existing = _familyRelatives.where((r) => r.relationKey == key).length;
    if (_singletonKeys.contains(key) && existing >= 1) {
      _snack('$label is already in the tree');
      return;
    }
    if (key == 'wife' && existing >= 4) {
      _snack('Maximum 4 wives allowed in Islam');
      return;
    }
    // Generate distinct auto-label like "Wife 2" or "Full Brother 2" if no custom name
    final displayLabel = existing >= 1 ? '$label ${existing + 1}' : label;
    setState(() {
      _familyRelatives.add(RelativeNode(
        id: '${key}_${DateTime.now().millisecondsSinceEpoch}',
        label: displayLabel,
        customName: customName,
        gender: gender,
        level: level,
        relationKey: key,
        parentId: parentId,
      ));
      _lineAnimationController.forward(from: 0);
      _recalculateFamilyShares();
    });
    _saveFamilyTree();
  }

  void _removeFamilyMember(String id) {
    if (id == 'me') return;
    setState(() {
      _familyRelatives.removeWhere((r) => r.id == id);
      // Also remove children/nephews whose parentId references this node
      _familyRelatives.removeWhere(
          (r) => r.parentId == id && r.id != 'me');
      _lineAnimationController.forward(from: 0);
      _recalculateFamilyShares();
    });
    _saveFamilyTree();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 12.5)),
      backgroundColor: AppColors.coralOrange,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F7F5);
    final outerBg = _isDarkMode ? const Color(0xFF000000) : const Color(0xFFE8E8E8);

    return Container(
      color: outerBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildTabBar(),
                  Expanded(
                    child: _buildTabContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER & TABS
  // ============================================================
  Widget _buildHeader() {
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor =
        _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.55);

    return Padding(
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
            child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inheritance (Faraid)',
                    style: GoogleFonts.poppins(
                        fontSize: 15.5, fontWeight: FontWeight.bold, color: textColor)),
                Text('Estate distribution & family tree',
                    style: GoogleFonts.inter(fontSize: 11, color: subtextColor)),
              ],
            ),
          ),
        ],
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
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
                        color: active
                            ? Colors.white
                            : (_isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4))),
                    const SizedBox(height: 2),
                    Text(_tabLabels[i],
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : (_isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4)))),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _buildFamilyTreeTab();
      case 1:
        return _buildCalculationTab();
      case 2:
        return _buildScenariosTab();
      case 3:
        return _buildRulesTab();
      default:
        return _buildFamilyTreeTab();
    }
  }

  // ============================================================
  // TAB 1: FAMILY TREE
  // ============================================================
  Widget _buildFamilyTreeTab() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final hasOnlyMe = _familyRelatives.length == 1 && _familyRelatives.first.id == 'me';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clean empty-state banner (above board, never covers canvas)
          if (hasOnlyMe)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF1B2A22) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kLinkGreen.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: kLinkGreen),
                      const SizedBox(width: 8),
                      Text('How to build your Family Tree:',
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Tap "Add Family Member" below to start adding relatives.\n'
                    '• When adding children or nephews, pick which wife or brother they belong to.\n'
                    '• Touch and drag any box to move it anywhere on the board canvas.',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        height: 1.4,
                        color: _isDarkMode ? Colors.white70 : AppColors.navyBlue),
                  ),
                ],
              ),
            ),
          // Gender selector
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
            ),
            child: Row(
              children: [
                Text('My Gender:',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                const Spacer(),
                _genderChip('Male', Gender.male),
                const SizedBox(width: 8),
                _genderChip('Female', Gender.female),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── THE TREE BOARD ──
          Container(
            height: 520,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode
                    ? const [Color(0xFF10151C), Color(0xFF0C1A16)]
                    : const [Color(0xFFF0F7F3), Color(0xFFE6EFF8)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isDarkMode
                    ? kLinkGreen.withValues(alpha: 0.18)
                    : AppColors.navyBlue.withValues(alpha: 0.10),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Light dot-grid pattern (FIX: visible when close)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DotGridPainter(
                        color: _isDarkMode
                            ? Colors.white.withValues(alpha: 0.07)
                            : AppColors.navyBlue.withValues(alpha: 0.06),
                      ),
                    ),
                  ),

                  // Zoomable / pannable canvas — or static if locked
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, cons) {
                        final layout = FamilyTreeLayout.compute(
                            _familyRelatives, cons.maxWidth,
                            nodeOverrides: _nodeOffsets);
                        final canvasH = math.max(layout.height, cons.maxHeight);

                        final treeContent = SizedBox(
                          width: layout.width,
                          height: canvasH,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: _lineAnimationController,
                                  builder: (context, _) => CustomPaint(
                                    painter: FamilyTreeLinkPainter(
                                      edges: layout.edges,
                                      progress: Curves.easeOutCubic
                                          .transform(_lineAnimationController.value),
                                    ),
                                  ),
                                ),
                              ),
                              for (final node in _familyRelatives)
                                if (layout.centers.containsKey(node.id))
                                  Positioned(
                                    left: layout.centers[node.id]!.dx -
                                        FamilyTreeLayout.cardW / 2,
                                    top: layout.centers[node.id]!.dy -
                                        FamilyTreeLayout.cardH / 2,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      // In Edit Layout mode: plain one-finger drag moves the card.
                                      // Outside Edit Layout mode: long-press still works as a
                                      // quick way to nudge a single card without leaving pan/zoom mode.
                                      onPanStart: _editLayoutMode
                                          ? (_) {
                                              _dragStartPos = _nodeOffsets[node.id] ??
                                                  layout.centers[node.id]!;
                                              setState(() => _draggingNodeId = node.id);
                                            }
                                          : null,
                                      onPanUpdate: _editLayoutMode
                                          ? (details) {
                                              if (_dragStartPos == null) return;
                                              final scale = _treeTransformController
                                                  .value
                                                  .getMaxScaleOnAxis();
                                              final delta = Offset(
                                                details.delta.dx / scale,
                                                details.delta.dy / scale,
                                              );
                                              final base =
                                                  _nodeOffsets[node.id] ?? layout.centers[node.id]!;
                                              final newPos = _clampNodePosition(
                                                base + delta,
                                                layout.width,
                                                canvasH,
                                              );
                                              setState(() => _nodeOffsets[node.id] = newPos);
                                            }
                                          : null,
                                      onPanEnd: _editLayoutMode
                                          ? (_) {
                                              setState(() => _draggingNodeId = null);
                                              _dragStartPos = null;
                                              _saveFamilyTree();
                                            }
                                          : null,
                                      onLongPressStart: _editLayoutMode
                                          ? null
                                          : (_) {
                                              HapticFeedback.mediumImpact();
                                              _dragStartPos = _nodeOffsets[node.id] ??
                                                  layout.centers[node.id]!;
                                              setState(() => _draggingNodeId = node.id);
                                            },
                                      onLongPressMoveUpdate: _editLayoutMode
                                          ? null
                                          : (details) {
                                              if (_dragStartPos == null) return;
                                              final scale = _treeTransformController
                                                  .value
                                                  .getMaxScaleOnAxis();
                                              final delta = details.offsetFromOrigin / scale;
                                              final newPos = _clampNodePosition(
                                                _dragStartPos! + delta,
                                                layout.width,
                                                canvasH,
                                              );
                                              setState(() => _nodeOffsets[node.id] = newPos);
                                            },
                                      onLongPressEnd: _editLayoutMode
                                          ? null
                                          : (_) {
                                              setState(() => _draggingNodeId = null);
                                              _dragStartPos = null;
                                              _saveFamilyTree();
                                            },
                                      onLongPressCancel: _editLayoutMode
                                          ? null
                                          : () {
                                              setState(() => _draggingNodeId = null);
                                              _dragStartPos = null;
                                            },
                                      child: _buildFamilyCard(node),
                                    ),
                                  ),
                            ],
                          ),
                        );

                        // InteractiveViewer: pan disabled while dragging a node
                        return InteractiveViewer(
                          transformationController: _treeTransformController,
                          constrained: false,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          minScale: 0.2,
                          maxScale: 5,
                          panEnabled: !_boardLocked && !_editLayoutMode && _draggingNodeId == null,
                          scaleEnabled: !_boardLocked && !_editLayoutMode && _draggingNodeId == null,
                          child: treeContent,
                        );
                      },
                    ),
                  ),

                  // Decorative title
                  Positioned(
                    top: 14,
                    left: 18,
                    child: IgnorePointer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (r) => LinearGradient(
                              colors: _isDarkMode
                                  ? [kLinkGreen, AppColors.midTeal]
                                  : [AppColors.navyBlue, AppColors.midTeal],
                            ).createShader(r),
                            child: Text(
                              'My Family Tree',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 64,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [kLinkGreen, Colors.transparent]),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Lock button (top-right)
                  Positioned(
                    top: 10,
                    right: 12,
                    child: GestureDetector(
                      onTap: () async {
                        setState(() => _boardLocked = !_boardLocked);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('inheritance_board_locked', _boardLocked);
                        // Save matrix transform when locking
                        if (_boardLocked) {
                          final storage = _treeTransformController.value.storage.toList();
                          await prefs.setString('inheritance_locked_matrix', jsonEncode(storage));
                        }
                        await _syncToFirestore();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _boardLocked
                              ? kLinkGreen.withValues(alpha: 0.25)
                              : (_isDarkMode ? Colors.black38 : Colors.white38),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _boardLocked
                                ? kLinkGreen
                                : (_isDarkMode ? Colors.white24 : Colors.black12),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _boardLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                              size: 13,
                              color: _boardLocked
                                  ? kLinkGreen
                                  : (_isDarkMode ? Colors.white60 : AppColors.navyBlue.withValues(alpha: 0.6)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _boardLocked ? 'Locked' : 'Lock',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: _boardLocked
                                    ? kLinkGreen
                                    : (_isDarkMode
                                        ? Colors.white60
                                        : AppColors.navyBlue.withValues(alpha: 0.6)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),


                  // Reset Layout & Center Me button
                  Positioned(
                    top: 84,
                    right: 12,
                    child: GestureDetector(
                      onTap: _resetTreeLayout,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.black38 : Colors.white38,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isDarkMode ? Colors.white24 : Colors.black12,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restart_alt_rounded,
                              size: 13,
                              color: _isDarkMode ? Colors.white60 : AppColors.navyBlue.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reset',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: _isDarkMode ? Colors.white60 : AppColors.navyBlue.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Edit Layout toggle — lets user freely drag cards anywhere
                  Positioned(
                    top: 46,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => setState(() => _editLayoutMode = !_editLayoutMode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _editLayoutMode
                              ? kLinkGreen.withValues(alpha: 0.25)
                              : (_isDarkMode ? Colors.black38 : Colors.white38),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _editLayoutMode
                                ? kLinkGreen
                                : (_isDarkMode ? Colors.white24 : Colors.black12),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _editLayoutMode
                                  ? Icons.open_with_rounded
                                  : Icons.pan_tool_alt_outlined,
                              size: 13,
                              color: _editLayoutMode
                                  ? kLinkGreen
                                  : (_isDarkMode ? Colors.white60 : AppColors.navyBlue.withValues(alpha: 0.6)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _editLayoutMode ? 'Arranging' : 'Arrange',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: _editLayoutMode
                                    ? kLinkGreen
                                    : (_isDarkMode ? Colors.white60 : AppColors.navyBlue.withValues(alpha: 0.6)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),


                  // Manual zoom controls — easier than pinch on mobile
                  Positioned(
                    bottom: 10,
                    left: 14,
                    child: Column(
                      children: [
                        _zoomButton(Icons.add_rounded, () => _zoomBy(1.25)),
                        const SizedBox(height: 6),
                        _zoomButton(Icons.remove_rounded, () => _zoomBy(0.8)),
                        const SizedBox(height: 6),
                        _zoomButton(Icons.center_focus_strong_rounded, _resetZoom),
                      ],
                    ),
                  ),

                  // Hint text bottom — navy when unlocked, green when locked
                  Positioned(
                    bottom: 10,
                    right: 14,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (_isDarkMode ? Colors.black : Colors.white)
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: (_boardLocked ? kLinkGreen : AppColors.navyBlue)
                                  .withValues(alpha: 0.35),
                              width: 1),
                        ),
                        child: Text(
                          _boardLocked
                              ? 'Locked — tap 🔒 to pan/zoom'
                              : _editLayoutMode
                                  ? 'Drag any card to move it'
                                  : 'Pinch to zoom · drag to pan · tap Arrange to move cards',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _boardLocked
                                ? kLinkGreen
                                : AppColors.navyBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── PREMIUM ADD BUTTON ──
          _buildAddFamilyMemberButton(),
        ],
      ),
    );
  }


  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: (_isDarkMode ? Colors.black : Colors.white).withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(
              color: (_boardLocked ? kLinkGreen : AppColors.navyBlue).withValues(alpha: 0.35)),
        ),
        child: Icon(icon, size: 17, color: _boardLocked ? kLinkGreen : AppColors.navyBlue),
      ),
    );
  }

  void _zoomBy(double factor) {
    final currentScale = _treeTransformController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(0.2, 5.0);
    final adjust = targetScale / currentScale;
    final matrix = _treeTransformController.value.clone()..scale(adjust);
    setState(() => _treeTransformController.value = matrix);
  }

  void _resetZoom() {
    setState(() => _treeTransformController.value = Matrix4.identity());
  }


  // Premium gradient Add button
  Widget _buildAddFamilyMemberButton() {
    return GestureDetector(
      onTap: _showAddRelativeDialog,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF17605A), Color(0xFF1E8A4A)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: kLinkGreen.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Subtle shine overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ), // end Column
              ), // end Container
            ), // end ConstrainedBox
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Family Member',
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.6), size: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _genderChip(String label, Gender g) {
    final selected = _myGender == g;
    return GestureDetector(
      onTap: () {
        setState(() {
          _myGender = g;
          final idx = _familyRelatives.indexWhere((r) => r.id == 'me');
          if (idx != -1) {
            _familyRelatives[idx] = RelativeNode(
                id: 'me', label: 'Me', gender: g, level: 0, relationKey: 'me');
          } else {
            _familyRelatives.insert(0, RelativeNode(
                id: 'me', label: 'Me', gender: g, level: 0, relationKey: 'me'));
          }
          _familyRelatives.removeWhere(
              (r) => r.relationKey == (g == Gender.male ? 'husband' : 'wife'));
          _recalculateFamilyShares();
        });
        _saveFamilyTree();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.navyBlue
              : (_isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : (_isDarkMode ? Colors.white70 : AppColors.navyBlue),
            )),
      ),
    );
  }

  Widget _buildFamilyCard(RelativeNode node) {
    final isMe = node.id == 'me';
    const w = FamilyTreeLayout.cardW;
    const h = FamilyTreeLayout.cardH;

    final borderColor = isMe
        ? kLinkGreen
        : (_isDarkMode ? Colors.white24 : const Color(0xFF9DB8D6));
    final textColor =
        isMe ? Colors.white : (_isDarkMode ? Colors.white : AppColors.navyBlue);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _showNodeOptions(node),
          child: Container(
            width: w,
            height: h,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E3A8A), Color(0xFF17605A)],
                    )
                  : null,
              color: isMe
                  ? null
                  : (_isDarkMode ? const Color(0xFF232A26) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: isMe ? 2 : 1.2),
              boxShadow: [
                BoxShadow(
                  color: isMe
                      ? kLinkGreen.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.07),
                  blurRadius: isMe ? 10 : 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.midTeal
                        : (node.gender == Gender.female
                            ? AppColors.coralOrange
                            : AppColors.navyBlue),
                    shape: BoxShape.circle,
                  ),
                  child: CustomPaint(
                      painter: AvatarPainter(gender: node.gender, isMe: isMe)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.customName ?? node.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 10.5, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      Text(
                        isMe ? 'Self' : node.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          color: isMe
                              ? Colors.white70
                              : (_isDarkMode ? Colors.white60 : AppColors.placeholder),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isMe)
          Positioned(
            top: -10,
            right: -10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _removeFamilyMember(node.id),
              child: Container(
                padding: const EdgeInsets.all(8), // bigger invisible touch area
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showNodeOptions(RelativeNode node) {
    if (node.id == 'me') return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Manage ${node.customName ?? node.label}',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              title: Text('Remove from Family Tree',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _removeFamilyMember(node.id);
              },
            ),
          ],
        ),
      ),
    );
  }


  // REDESIGNED ADD RELATIVE DIALOG
  
  void _showAddRelativeDialog() {
    String? selectedKey;
    String? customNameInput;
    String searchQuery = '';
    String? selectedParentId; // for nephew or child-with-wife

    // Determine which singletons are already in tree
    Set<String> existingKeys = _familyRelatives.map((r) => r.relationKey).toSet();

    // Build grouped option list
    final List<Map<String, dynamic>> allOptions = [
      // --- Parents ---
      {'group': 'Parents', 'key': 'father', 'label': 'Father', 'desc': 'Biological father', 'gender': Gender.male, 'level': -1, 'singleton': true},
      {'group': 'Parents', 'key': 'mother', 'label': 'Mother', 'desc': 'Biological mother', 'gender': Gender.female, 'level': -1, 'singleton': true},
      // --- Grandparents ---
      {'group': 'Grandparents', 'key': 'pGrandfather', 'label': 'Paternal Grandfather', 'desc': 'Father\'s father', 'gender': Gender.male, 'level': -2, 'singleton': true},
      {'group': 'Grandparents', 'key': 'pGrandmother', 'label': 'Paternal Grandmother', 'desc': 'Father\'s mother', 'gender': Gender.female, 'level': -2, 'singleton': true},
      {'group': 'Grandparents', 'key': 'mGrandmother', 'label': 'Maternal Grandmother', 'desc': 'Mother\'s mother', 'gender': Gender.female, 'level': -2, 'singleton': true},
      // --- Spouse ---
      {
        'group': 'Spouse',
        'key': _myGender == Gender.male ? 'wife' : 'husband',
        'label': _myGender == Gender.male ? 'Wife' : 'Husband',
        'desc': _myGender == Gender.male ? 'Up to 4 wives allowed' : 'Husband',
        'gender': _myGender == Gender.male ? Gender.female : Gender.male,
        'level': 0,
        'singleton': _myGender == Gender.female, // husband is singleton
      },
      // --- Children ---
      {'group': 'Children', 'key': 'son', 'label': 'Son', 'desc': 'Biological son', 'gender': Gender.male, 'level': 1, 'singleton': false, 'needsWife': true},
      {'group': 'Children', 'key': 'daughter', 'label': 'Daughter', 'desc': 'Biological daughter', 'gender': Gender.female, 'level': 1, 'singleton': false, 'needsWife': true},
      {'group': 'Children', 'key': 'grandson', 'label': 'Grandson (Son\'s Son)', 'desc': 'Son\'s son', 'gender': Gender.male, 'level': 2, 'singleton': false},
      {'group': 'Children', 'key': 'granddaughter', 'label': 'Granddaughter (Son\'s Daughter)', 'desc': 'Son\'s daughter', 'gender': Gender.female, 'level': 2, 'singleton': false},
      // --- Siblings ---
      {'group': 'Siblings', 'key': 'fullBrother', 'label': 'Full Brother', 'desc': 'Same father & mother', 'gender': Gender.male, 'level': 0, 'singleton': false},
      {'group': 'Siblings', 'key': 'fullSister', 'label': 'Full Sister', 'desc': 'Same father & mother', 'gender': Gender.female, 'level': 0, 'singleton': false},
      {'group': 'Siblings', 'key': 'paternalBrother', 'label': 'Paternal Brother', 'desc': 'Same father only', 'gender': Gender.male, 'level': 0, 'singleton': false},
      {'group': 'Siblings', 'key': 'paternalSister', 'label': 'Paternal Sister', 'desc': 'Same father only', 'gender': Gender.female, 'level': 0, 'singleton': false},
      {'group': 'Siblings', 'key': 'maternalSibling', 'label': 'Maternal Sibling', 'desc': 'Same mother only', 'gender': Gender.male, 'level': 0, 'singleton': false},
      // --- Extended ---
      {'group': 'Extended', 'key': 'fullNephew', 'label': 'Full Nephew', 'desc': 'Full brother\'s son', 'gender': Gender.male, 'level': 1, 'singleton': false, 'needsBrother': 'fullBrother'},
      {'group': 'Extended', 'key': 'paternalNephew', 'label': 'Paternal Nephew', 'desc': 'Paternal brother\'s son', 'gender': Gender.male, 'level': 1, 'singleton': false, 'needsBrother': 'paternalBrother'},
      {'group': 'Extended', 'key': 'fullUncle', 'label': 'Full Paternal Uncle', 'desc': 'Father\'s full brother', 'gender': Gender.male, 'level': -1, 'singleton': false},
      {'group': 'Extended', 'key': 'paternalUncle', 'label': 'Paternal Uncle', 'desc': 'Father\'s paternal brother', 'gender': Gender.male, 'level': -1, 'singleton': false},
      {'group': 'Extended', 'key': 'fullCousin', 'label': 'Full Cousin', 'desc': 'Full uncle\'s son', 'gender': Gender.male, 'level': 0, 'singleton': false},
      {'group': 'Extended', 'key': 'paternalCousin', 'label': 'Paternal Cousin', 'desc': 'Paternal uncle\'s son', 'gender': Gender.male, 'level': 0, 'singleton': false},
    ];

    final groups = ['Parents', 'Grandparents', 'Spouse', 'Children', 'Siblings', 'Extended'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = searchQuery.isEmpty
                ? allOptions
                : allOptions
                    .where((o) => (o['label'] as String)
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()) ||
                        (o['desc'] as String)
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()))
                    .toList();

            // Brothers/wives available for parent selection
            final fullBrothers = _familyRelatives
                .where((r) => r.relationKey == 'fullBrother')
                .toList();
            final paternalBrothers = _familyRelatives
                .where((r) => r.relationKey == 'paternalBrother')
                .toList();
            final wives = _familyRelatives
                .where((r) => r.relationKey == 'wife')
                .toList();

            final needsBrother =
                selectedKey == 'fullNephew' || selectedKey == 'paternalNephew';
            // Show wife picker whenever adding son/daughter AND at least 1 wife exists
            final needsWife = (selectedKey == 'son' || selectedKey == 'daughter') &&
                wives.isNotEmpty;

            final availableBrothers = selectedKey == 'fullNephew'
                ? fullBrothers
                : paternalBrothers;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 430,
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: Container(
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                  0, 0, 0, MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1E3A8A), Color(0xFF17605A)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.person_add_alt_1_rounded,
                                  color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Text('Add Family Member',
                                style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Name input
                        TextField(
                          onChanged: (val) => customNameInput = val,
                          decoration: InputDecoration(
                            hintText: 'Enter Name (Optional, e.g. "Abbu")',
                            prefixIcon: Icon(Icons.person_outline,
                                size: 18,
                                color: _isDarkMode ? Colors.white38 : AppColors.placeholder),
                            filled: true,
                            fillColor: _isDarkMode
                                ? const Color(0xFF2C2C2C)
                                : const Color(0xFFF5F7FA),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _isDarkMode ? Colors.white : Colors.black),
                        ),
                        const SizedBox(height: 10),
                        // PROMINENT PARENT PICKER (Placed right below search bar at top)
                        if (needsBrother && availableBrothers.isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 10, bottom: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isDarkMode
                                  ? const Color(0xFF252530)
                                  : const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.midTeal.withValues(alpha: 0.4), width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Which brother is this nephew\'s father?',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                                const SizedBox(height: 8),
                                ...availableBrothers.asMap().entries.map((entry) {
                                  final br = entry.value;
                                  final isSelected = selectedParentId == br.id;
                                  final label = br.customName != null && br.customName!.isNotEmpty
                                      ? br.customName!
                                      : br.label;
                                  return GestureDetector(
                                    onTap: () =>
                                        setModalState(() => selectedParentId = br.id),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.navyBlue
                                            : (_isDarkMode
                                                ? const Color(0xFF2C2C2C)
                                                : Colors.white),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: isSelected
                                                ? AppColors.navyBlue
                                                : Colors.grey.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_rounded,
                                              size: 14,
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppColors.midTeal),
                                          const SizedBox(width: 8),
                                          Text(label,
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : (_isDarkMode
                                                          ? Colors.white
                                                          : AppColors.navyBlue))),
                                          if (isSelected) ...[
                                            const Spacer(),
                                            const Icon(Icons.check_circle_rounded,
                                                color: kLinkGreen, size: 14),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],

                        if (needsWife) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 10, bottom: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isDarkMode
                                  ? const Color(0xFF252530)
                                  : const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.midTeal.withValues(alpha: 0.4), width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Which wife is this child\'s mother?',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                                const SizedBox(height: 8),
                                ...wives.asMap().entries.map((entry) {
                                  final wife = entry.value;
                                  final isSelected = selectedParentId == wife.id;
                                  final label = wife.customName != null && wife.customName!.isNotEmpty
                                      ? wife.customName!
                                      : wife.label;
                                  return GestureDetector(
                                    onTap: () =>
                                        setModalState(() => selectedParentId = wife.id),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.navyBlue
                                            : (_isDarkMode
                                                ? const Color(0xFF2C2C2C)
                                                : Colors.white),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: isSelected
                                                ? AppColors.navyBlue
                                                : Colors.grey.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_rounded,
                                              size: 14,
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppColors.coralOrange),
                                          const SizedBox(width: 8),
                                          Text(label,
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : (_isDarkMode
                                                          ? Colors.white
                                                          : AppColors.navyBlue))),
                                          if (isSelected) ...[
                                            const Spacer(),
                                            const Icon(Icons.check_circle_rounded,
                                                color: kLinkGreen, size: 14),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        // Search bar
                        TextField(
                          onChanged: (val) =>
                              setModalState(() => searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search relation…',
                            prefixIcon: Icon(Icons.search_rounded,
                                size: 18,
                                color: _isDarkMode ? Colors.white38 : AppColors.placeholder),
                            filled: true,
                            fillColor: _isDarkMode
                                ? const Color(0xFF252525)
                                : const Color(0xFFF0F4F8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.midTeal.withValues(alpha: 0.3))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.midTeal, width: 1.5)),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          ),
                          style: GoogleFonts.inter(fontSize: 13,
                              color: _isDarkMode ? Colors.white : Colors.black),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      shrinkWrap: true,
                      children: [
                        if (searchQuery.isEmpty)
                          ...groups.map((group) {
                            final groupItems = filtered
                                .where((o) => o['group'] == group)
                                .toList();
                            if (groupItems.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 10, bottom: 6, left: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                          width: 3,
                                          height: 14,
                                          decoration: BoxDecoration(
                                              color: AppColors.midTeal,
                                              borderRadius: BorderRadius.circular(2))),
                                      const SizedBox(width: 6),
                                      Text(group,
                                          style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: _isDarkMode
                                                  ? Colors.white54
                                                  : AppColors.navyBlue
                                                      .withValues(alpha: 0.5))),
                                    ],
                                  ),
                                ),
                                ...groupItems.map((opt) =>
                                    _buildRelationCard(opt, selectedKey, existingKeys, (key) {
                                      setModalState(() {
                                        selectedKey = key;
                                        if ((key == 'son' || key == 'daughter') &&
                                            wives.isNotEmpty) {
                                          selectedParentId = wives.first.id;
                                        } else if (key == 'fullNephew' &&
                                            fullBrothers.isNotEmpty) {
                                          selectedParentId = fullBrothers.first.id;
                                        } else if (key == 'paternalNephew' &&
                                            paternalBrothers.isNotEmpty) {
                                          selectedParentId = paternalBrothers.first.id;
                                        } else {
                                          selectedParentId = null;
                                        }
                                      });
                                    })),
                              ],
                            );
                          })
                        else
                          ...filtered.map((opt) => _buildRelationCard(
                              opt, selectedKey, existingKeys, (key) {
                            setModalState(() {
                              selectedKey = key;
                              if ((key == 'son' || key == 'daughter') &&
                                  wives.isNotEmpty) {
                                selectedParentId = wives.first.id;
                              } else if (key == 'fullNephew' &&
                                  fullBrothers.isNotEmpty) {
                                selectedParentId = fullBrothers.first.id;
                              } else if (key == 'paternalNephew' &&
                                  paternalBrothers.isNotEmpty) {
                                selectedParentId = paternalBrothers.first.id;
                              } else {
                                selectedParentId = null;
                              }
                            });
                          })),


                      ],
                    ),
                  ),

                  // Add button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: GestureDetector(
                      onTap: selectedKey == null
                          ? null
                          : () {
                              final sel = allOptions
                                  .firstWhere((o) => o['key'] == selectedKey);
                              final singleton = sel['singleton'] as bool? ?? false;
                              if (singleton &&
                                  existingKeys.contains(selectedKey)) {
                                _snack(
                                    '${sel['label']} is already in the tree');
                                return;
                              }
                              _addFamilyMember(
                                sel['key'] as String,
                                sel['label'] as String,
                                sel['gender'] as Gender,
                                sel['level'] as int,
                                customName: (customNameInput?.trim().isEmpty ?? true)
                                    ? null
                                    : customNameInput!.trim(),
                                parentId: selectedParentId,
                              );
                              Navigator.pop(context);
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: selectedKey != null
                              ? const LinearGradient(
                                  colors: [Color(0xFF1E3A8A), Color(0xFF17605A)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : null,
                          color: selectedKey == null
                              ? (_isDarkMode
                                  ? const Color(0xFF2C2C2C)
                                  : const Color(0xFFE0E0E0))
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: selectedKey != null
                              ? [
                                  BoxShadow(
                                      color: kLinkGreen.withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4)),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            selectedKey == null
                                ? 'Select a Relation First'
                                : 'Add to Tree',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: selectedKey == null
                                  ? (_isDarkMode ? Colors.white38 : Colors.black38)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ), // end Column
            ), // end Container
            ), // end ConstrainedBox
          ); // end Center
          },
        );
      },
    );
  }

  Widget _buildRelationCard(
      Map<String, dynamic> opt,
      String? selectedKey,
      Set<String> existingKeys,
      void Function(String?) onSelect) {
    final key = opt['key'] as String;
    final singleton = opt['singleton'] as bool? ?? false;
    final alreadyAdded = singleton && existingKeys.contains(key);
    final isSelected = selectedKey == key;
    final gender = opt['gender'] as Gender;

    return GestureDetector(
      onTap: alreadyAdded
          ? null
          : () => onSelect(isSelected ? null : key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.navyBlue
              : alreadyAdded
                  ? (_isDarkMode
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF5F5F5))
                  : (_isDarkMode ? const Color(0xFF252525) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.navyBlue
                : alreadyAdded
                    ? Colors.grey.withValues(alpha: 0.15)
                    : (_isDarkMode
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.withValues(alpha: 0.12)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: AppColors.navyBlue.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ]
              : null,
        ),
        child: Opacity(
          opacity: alreadyAdded ? 0.4 : 1.0,
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.15)
                      : (gender == Gender.female
                              ? AppColors.coralOrange
                              : AppColors.navyBlue)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  gender == Gender.female
                      ? Icons.person_rounded
                      : Icons.person_rounded,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : (gender == Gender.female
                          ? AppColors.coralOrange
                          : AppColors.navyBlue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opt['label'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : (_isDarkMode ? Colors.white : AppColors.navyBlue),
                        )),
                    Text(alreadyAdded ? 'Already added' : opt['desc'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.75)
                              : (_isDarkMode
                                  ? Colors.white38
                                  : AppColors.placeholder),
                        )),
                  ],
                ),
              ),
              if (alreadyAdded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.midTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Added',
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.midTeal)),
                )
              else if (isSelected)
                const Icon(Icons.check_circle_rounded,
                    color: kLinkGreen, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  
  // TAB 2: CALCULATION 
  
  Widget _buildCalculationTab() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final validResults =
        _familyResults.where((r) => !r.excluded && r.fraction > 0).toList();

    // Sort breakdown high → low
    final sortedBreakdown = List<FaraidShareResult>.from(_familyResults)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estate Distribution Chart (%)',
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 14),
                if (validResults.isNotEmpty) ...[
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: FaraidDonutChartPainter(
                          results: validResults, isDarkMode: _isDarkMode),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: validResults.map((r) {
                      final colors = [
                        AppColors.navyBlue, AppColors.midTeal,
                        AppColors.coralOrange, Colors.indigo,
                        Colors.teal, Colors.amber.shade700,
                      ];
                      final c = colors[validResults.indexOf(r) % colors.length];
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('${r.label}: ${r.percentage.toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                  fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
                        ],
                      );
                    }).toList(),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                          'Add surviving relatives in Family Tree to view the chart.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.placeholder)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                  width: 4, height: 16,
                  decoration: BoxDecoration(
                      color: AppColors.midTeal, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('Distribution Breakdown',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.midTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('High → Low',
                    style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.midTeal)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sorted high → low
          ...sortedBreakdown.map(_buildPercentageResultCard),

          const SizedBox(height: 8),
          Text(
            'Based on common Hanafi Faraid rules. For an actual estate division, consult a qualified scholar.',
            style: GoogleFonts.inter(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: _isDarkMode ? Colors.white38 : AppColors.placeholder),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageResultCard(FaraidShareResult share) {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: share.excluded
            ? Border.all(color: AppColors.coralOrange.withValues(alpha: 0.3))
            : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (share.excluded ? AppColors.coralOrange : AppColors.midTeal)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              share.excluded ? '—' : share.fractionReadable,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: share.excluded ? AppColors.coralOrange : AppColors.midTeal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(share.label,
                            style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: textColor))),
                    if (!share.excluded)
                      Text('${share.percentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.midTeal)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(share.note,
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: share.excluded
                            ? AppColors.coralOrange.withValues(alpha: 0.9)
                            : (_isDarkMode
                                ? Colors.white60
                                : AppColors.navyBlue.withValues(alpha: 0.55)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 3: SCENARIOS
  // ============================================================
  Widget _buildScenariosTab() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;

    final heirDefinitions = <Map<String, dynamic>>[
      {'key': 'husband', 'label': 'Husband', 'isBool': true},
      {'key': 'wife', 'label': 'Wife / Wives', 'isBool': false, 'max': 4},
      {'key': 'son', 'label': 'Son', 'isBool': false},
      {'key': 'daughter', 'label': 'Daughter', 'isBool': false},
      {'key': 'grandson', 'label': 'Paternal Grandson', 'isBool': false},
      {'key': 'granddaughter', 'label': 'Paternal Granddaughter', 'isBool': false},
      {'key': 'father', 'label': 'Father', 'isBool': true},
      {'key': 'mother', 'label': 'Mother', 'isBool': true},
      {'key': 'pGrandfather', 'label': 'Paternal Grandfather', 'isBool': true},
      {'key': 'pGrandmother', 'label': 'Paternal Grandmother', 'isBool': true},
      {'key': 'mGrandmother', 'label': 'Maternal Grandmother', 'isBool': true},
      {'key': 'fullBrother', 'label': 'Full Brother', 'isBool': false},
      {'key': 'fullSister', 'label': 'Full Sister', 'isBool': false},
      {'key': 'paternalBrother', 'label': 'Paternal Brother', 'isBool': false},
      {'key': 'paternalSister', 'label': 'Paternal Sister', 'isBool': false},
      {'key': 'maternalSibling', 'label': 'Maternal Sibling', 'isBool': false},
      {'key': 'fullNephew', 'label': 'Full Nephew', 'isBool': false},
      {'key': 'paternalNephew', 'label': 'Paternal Nephew', 'isBool': false},
      {'key': 'fullUncle', 'label': 'Full Paternal Uncle', 'isBool': false},
      {'key': 'paternalUncle', 'label': 'Paternal Paternal Uncle', 'isBool': false},
      {'key': 'fullCousin', 'label': 'Full Cousin', 'isBool': false},
      {'key': 'paternalCousin', 'label': 'Paternal Cousin', 'isBool': false},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
                ]),
            child: Row(
              children: [
                Text('Deceased Gender:',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                const Spacer(),
                ...['Male', 'Female'].map((g) {
                  final sel = (_scenarioDeceasedGender == Gender.male && g == 'Male') ||
                      (_scenarioDeceasedGender == Gender.female && g == 'Female');
                  return GestureDetector(
                    onTap: () => setState(() {
                      _scenarioDeceasedGender =
                          g == 'Male' ? Gender.male : Gender.female;
                      if (_scenarioDeceasedGender == Gender.male) {
                        _scenarioHeirCounts['husband'] = 0;
                      } else {
                        _scenarioHeirCounts['wife'] = 0;
                      }
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: sel
                              ? AppColors.navyBlue
                              : (_isDarkMode
                                  ? const Color(0xFF2C2C2C)
                                  : const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(g,
                          style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: sel ? Colors.white : textColor,
                              fontWeight: FontWeight.bold)),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configure Scenario Heirs',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 4),
                Text('Select quantity or presence for each relative:',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _isDarkMode ? Colors.white60 : AppColors.placeholder)),
                const SizedBox(height: 12),
                ...heirDefinitions.map((def) {
                  final key = def['key'] as String;
                  final isBool = def['isBool'] as bool;
                  if (_scenarioDeceasedGender == Gender.male && key == 'husband') {
                    return const SizedBox.shrink();
                  }
                  if (_scenarioDeceasedGender == Gender.female && key == 'wife') {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(def['label'] as String,
                                style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: textColor))),
                        isBool
                            ? Switch(
                                value: (_scenarioHeirCounts[key] ?? 0) > 0,
                                onChanged: (v) =>
                                    setState(() => _scenarioHeirCounts[key] = v ? 1 : 0),
                                activeTrackColor: AppColors.midTeal,
                              )
                            : Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                                    onPressed: () {
                                      final cur = _scenarioHeirCounts[key] ?? 0;
                                      if (cur > 0) {
                                        setState(() => _scenarioHeirCounts[key] = cur - 1);
                                      }
                                    },
                                  ),
                                  Text('${_scenarioHeirCounts[key] ?? 0}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: textColor)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    onPressed: () {
                                      final cur = _scenarioHeirCounts[key] ?? 0;
                                      final maxVal = (def['max'] as int?) ?? 10;
                                      if (cur < maxVal) {
                                        setState(() => _scenarioHeirCounts[key] = cur + 1);
                                      }
                                    },
                                  ),
                                ],
                              ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() {
                _scenarioResults = FaraidEngine.calculate(
                  meGender: _scenarioDeceasedGender,
                  heirCounts: _scenarioHeirCounts,
                );
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Calculate Scenario Shares',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 16),

          if (_scenarioResults != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Scenario Distribution Result',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                ElevatedButton.icon(
                  onPressed: _promptSaveScenario,
                  icon: const Icon(Icons.bookmark_add_rounded, size: 16, color: Colors.white),
                  label: Text('Save',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...(_scenarioResults!
                .toList()
                ..sort((a, b) => b.percentage.compareTo(a.percentage)))
                .map(_buildPercentageResultCard),
            Text(
              'Based on common Hanafi Faraid rules. Consult a qualified scholar for a real estate division.',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: _isDarkMode ? Colors.white38 : AppColors.placeholder),
            ),
          ],

          if (_savedScenarios.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Saved Scenario Snapshots',
                style: GoogleFonts.poppins(
                    fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            ..._savedScenarios.map((sc) {
              final isLoaded = _activeScenarioName == sc['name'];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: isLoaded ? AppColors.midTeal.withValues(alpha: 0.08) : cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isLoaded ? AppColors.midTeal : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)
                    ]),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _loadSavedScenario(sc),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            isLoaded ? Icons.bookmark_added_rounded : Icons.bookmark_rounded,
                            color: AppColors.midTeal,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sc['name'] ?? 'Unnamed Scenario',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: textColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (sc['date'] != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatScenarioDate(sc['date'] as String?),
                                        style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            color: AppColors.placeholder,
                                            fontWeight: FontWeight.normal),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  isLoaded ? 'Active calculation displayed above' : 'Tap to load & view calculation results',
                                  style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      color: isLoaded ? AppColors.midTeal : AppColors.placeholder,
                                      fontWeight: isLoaded ? FontWeight.bold : FontWeight.normal),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.redAccent),
                            onPressed: () => setState(() {
                              if (_activeScenarioName == sc['name']) {
                                _activeScenarioName = null;
                              }
                              _savedScenarios.remove(sc);
                              _saveScenariosToPrefs();
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _loadSavedScenario(Map<String, dynamic> sc) {
    setState(() {
      _activeScenarioName = sc['name'];

      if (sc['gender'] != null) {
        _scenarioDeceasedGender =
            sc['gender'] == 'male' ? Gender.male : Gender.female;
      }

      if (sc['heirCounts'] != null) {
        final Map<String, dynamic> rawCounts =
            Map<String, dynamic>.from(sc['heirCounts'] as Map);
        _scenarioHeirCounts.clear();
        rawCounts.forEach((k, v) {
          if (v is num) {
            _scenarioHeirCounts[k] = v.toInt();
          }
        });
      }

      _scenarioResults = FaraidEngine.calculate(
        meGender: _scenarioDeceasedGender,
        heirCounts: _scenarioHeirCounts,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded & calculated scenario: ${sc['name']}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _promptSaveScenario() {
    String name = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Save Scenario Snapshot',
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
        content: TextField(
          onChanged: (val) => name = val,
          decoration: const InputDecoration(hintText: 'e.g. Grandpa\'s Estate'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (name.trim().isNotEmpty) {
                setState(() {
                  _savedScenarios.add({
                    'name': name.trim(),
                    'date': DateTime.now().toIso8601String(),
                    'gender':
                        _scenarioDeceasedGender == Gender.male ? 'male' : 'female',
                    'heirCounts': Map<String, int>.from(_scenarioHeirCounts),
                  });
                  _activeScenarioName = name.trim();
                  _saveScenariosToPrefs();
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  
  // TAB 4: RULES 
  
  Widget _buildRulesTab() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;

    // Awl / Radd explanation card
    final principlesCard = _buildPrinciplesCard(cardBg, textColor);

    final rules = _ruleData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intro banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3A8A), Color(0xFF17605A)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Faraid Rules Reference',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('22 heirs · Fixed shares, Residue & Exclusion · Hanafi School',
                    style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white70)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: // AFTER
                     Text(
                        'وَلِكُلٍّ جَعَلْنَا مَوَالِيَ مِمَّا تَرَكَ الْوَالِدَانِ وَالْأَقْرَبُونَ',
                        textAlign: TextAlign.center,
                         style: GoogleFonts.amiri(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.9,
                          fontWeight: FontWeight.w600,
                                                ),
                          ),
                ),
                const SizedBox(height: 6),
                Text(
                  '"And for all, We have appointed heirs to what is left by parents and relatives." — An-Nisa 4:33',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: Colors.white70, fontStyle: FontStyle.italic, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          principlesCard,
          const SizedBox(height: 12),
          ...rules.map((r) => _buildRuleCard(r, cardBg, textColor)),
          const SizedBox(height: 4),
          Text(
            'This reference summarizes common Hanafi positions. For an actual estate division, consult a qualified scholar.',
            style: GoogleFonts.inter(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: _isDarkMode ? Colors.white38 : AppColors.placeholder),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinciplesCard(Color cardBg, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppColors.midTeal,
          collapsedIconColor: _isDarkMode ? Colors.white38 : AppColors.placeholder,
          title: Text('Key Principles: Awl & Radd',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          subtitle: Text('Over-subscription & Surplus return',
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.midTeal, fontWeight: FontWeight.w600)),
          children: [
            _sectionBlock(
              'Awl (عَوْل) — Proportional Reduction',
              'When the sum of all fixed Quranic shares exceeds 100%, each heir\'s share is reduced proportionally so the total remains exactly 100%. '
              'This applies, for example, when a husband (1/2), two daughters (2/3), and a mother (1/6) all survive — their shares total more than 1.\n\n'
              'Classical example: Husband (1/2) + two daughters (2/3) + mother (1/6) → sum = 9/6. Under Awl each is scaled by 6/9.',
              textColor,
            ),
            const SizedBox(height: 10),
            _sectionBlock(
              'Radd (رَدّ) — Surplus Returned',
              'When no residuary (Asaba) heir exists and the fixed shares do not exhaust the estate, the surplus is returned to the fixed-share heirs '
              'in proportion to their shares (excluding the spouse). '
              'If the spouse is the only heir, the entire estate goes to them.\n\n'
              'Example: Mother alone (1/3) → Radd gives her the remaining 2/3, so she inherits the full estate.',
              textColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionBlock(String title, String body, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.midTeal)),
        const SizedBox(height: 4),
        Text(body,
            style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.5,
                color: _isDarkMode
                    ? Colors.white70
                    : AppColors.navyBlue.withValues(alpha: 0.75))),
      ],
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule, Color cardBg, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppColors.midTeal,
          collapsedIconColor: _isDarkMode ? Colors.white38 : AppColors.placeholder,
          title: Text(rule['heir'] as String,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(rule['refShort'] as String,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.midTeal)),
          ),
          children: [
            // Quran reference
            if ((rule['quranAyat'] as String).isNotEmpty) ...[
              _labeledSection('Quranic Reference', AppColors.midTeal, textColor),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isDarkMode
                        ? [const Color(0xFF0D1B14), const Color(0xFF0A1520)]
                        : [const Color(0xFFEFFAF4), const Color(0xFFEAF3FF)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.midTeal.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(rule['quranAyat'] as String,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.amiri(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                        height: 1.9)),
                    const SizedBox(height: 6),
                    Text(rule['quranTranslation'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                            color: _isDarkMode
                                ? Colors.white70
                                : AppColors.navyBlue.withValues(alpha: 0.7))),
                    const SizedBox(height: 4),
                    Text('— ${rule['quranRef'] as String}',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.midTeal)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],


            // Hadith reference
            if ((rule['hadith'] as String).isNotEmpty) ...[
              _labeledSection('Hadith Reference', const Color(0xFFD4A017), textColor),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? const Color(0xFF1A1600)
                      : const Color(0xFFFDF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFD4A017).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('"${rule['hadith'] as String}"',
                        style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                            color: _isDarkMode
                                ? Colors.white70
                                : AppColors.navyBlue.withValues(alpha: 0.75))),
                    const SizedBox(height: 4),
                    Text('— ${rule['hadithRef'] as String}',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD4A017))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Details
            _textRow('Who qualifies', rule['eligibility'] as String, textColor),
            _textRow('Share', rule['share'] as String, textColor),
            _textRow('How it changes', rule['changes'] as String, textColor),
            _textRow('Exclusion', rule['exclusion'] as String, textColor,
                labelColor: AppColors.coralOrange),
            _textRow('In short', rule['explanation'] as String, textColor),

            if ((rule['awlNote'] as String).isNotEmpty)
              _textRow('Awl effect', rule['awlNote'] as String, textColor,
                  labelColor: const Color(0xFF2196F3)),
            if ((rule['raddNote'] as String).isNotEmpty)
              _textRow('Radd effect', rule['raddNote'] as String, textColor,
                  labelColor: const Color(0xFF2196F3)),
          ],
        ),
      ),
    );
  }

  Widget _labeledSection(String label, Color color, Color textColor) {
    return Row(
      children: [
        Container(
            width: 3, height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _textRow(String title, String value, Color textColor,
      {Color? labelColor}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: RichText(
          textAlign: TextAlign.left,
          text: TextSpan(
            children: [
              TextSpan(
                  text: '$title:  ',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                       color: labelColor ?? (_isDarkMode ? AppColors.midTeal : AppColors.navyBlue))),
              TextSpan(
                  text: value,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.4,
                      color: _isDarkMode
                          ? Colors.white70
                          : AppColors.navyBlue.withValues(alpha: 0.85))),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RULE DATA with Quran + Hadith references
  // ============================================================
  List<Map<String, dynamic>> _ruleData() => [
    {
      'heir': 'Husband',
      'refShort': 'Surah An-Nisa 4:12',
      'quranAyat': 'وَلَكُمْ نِصْفُ مَا تَرَكَ أَزْوَاجُكُمْ إِن لَّمْ يَكُن لَّهُنَّ وَلَدٌ ۚ فَإِن كَانَ لَهُنَّ وَلَدٌ فَلَكُمُ الرُّبُعُ مِمَّا تَرَكْنَ',
      'quranTranslation': '"And for you is half of what your wives leave if they have no child. But if they have a child, then for you is one fourth of what they leave."',
      'quranRef': 'Surah An-Nisa (4:12)',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Surviving husband of the deceased wife.',
      'share': '1/2 if no descendants; 1/4 if any child or grandchild exists.',
      'changes': 'Reduces from 1/2 to 1/4 the moment any descendant exists.',
      'exclusion': 'Never excluded.',
      'explanation': 'The husband is a fixed-share (Fard) heir; only descendants change his portion.',
      'awlNote': 'If total shares exceed 1, husband\'s share is reduced proportionally alongside others.',
      'raddNote': 'If husband is the sole heir and no residuary exists, the surplus is returned to him.',
    },
    {
      'heir': 'Wife / Wives',
      'refShort': 'Surah An-Nisa 4:12',
      'quranAyat': 'وَلَهُنَّ الرُّبُعُ مِمَّا تَرَكْتُمْ إِن لَّمْ يَكُن لَّكُمْ وَلَدٌ ۚ فَإِن كَانَ لَكُمْ وَلَدٌ فَلَهُنَّ الثُّمُنُ مِمَّا تَرَكْتُم',
      'quranTranslation': '"And for the wives is one fourth of what you leave if you have no child. But if you have a child, then for them is an eighth of what you leave."',
      'quranRef': 'Surah An-Nisa (4:12)',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Surviving wife (or up to 4 wives) of the deceased husband.',
      'share': '1/4 if no descendants; 1/8 if descendants exist — divided equally among all wives.',
      'changes': 'Multiple wives share the single 1/4 or 1/8 equally.',
      'exclusion': 'Never excluded.',
      'explanation': 'The wives\' portion is one collective Quranic share, not one share per wife.',
      'awlNote': 'Under Awl, the collective wife share is reduced proportionally.',
      'raddNote': 'Wives do not receive Radd; any surplus goes to other heirs first.',
    },
    {
      'heir': 'Son',
      'refShort': 'Surah An-Nisa 4:11',
      'quranAyat': 'يُوصِيكُمُ اللَّهُ فِي أَوْلَادِكُمْ ۖ لِلذَّكَرِ مِثْلُ حَظِّ الْأُنثَيَيْنِ',
      'quranTranslation': '"Allah instructs you concerning your children: for the male, what is equal to the share of two females."',
      'quranRef': 'Surah An-Nisa (4:11)',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Biological son of the deceased.',
      'share': 'Residuary (Asaba) — takes all that remains after fixed shares, at double each daughter\'s share.',
      'changes': 'Shares the residue with daughters at a 2:1 ratio.',
      'exclusion': 'Never excluded.',
      'explanation': 'The son is the strongest residuary; he blocks grandchildren, all siblings, nephews, uncles and cousins.',
      'awlNote': '',
      'raddNote': '',
    },
    {
      'heir': 'Daughter',
      'refShort': 'Surah An-Nisa 4:11',
      'quranAyat': 'فَإِن كُنَّ نِسَاءً فَوْقَ اثْنَتَيْنِ فَلَهُنَّ ثُلُثَا مَا تَرَكَ ۖ وَإِن كَانَتْ وَاحِدَةً فَلَهَا النِّصْفُ',
      'quranTranslation': '"If there are more than two daughters, they shall have two thirds of what he left. If there is only one, she shall have half."',
      'quranRef': 'Surah An-Nisa (4:11)',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Biological daughter of the deceased.',
      'share': '1/2 if alone; 2/3 shared if two or more; residuary with a son (2:1).',
      'changes': 'Turns from fixed-share heir into residuary whenever a son exists.',
      'exclusion': 'Never excluded.',
      'explanation': 'A brother converts her Quranic share into a proportional residuary share.',
      'awlNote': 'Under Awl, daughters\' share is reduced proportionally.',
      'raddNote': 'Daughters receive Radd when no residuary heir and estate is not fully distributed.',
    },
    {
      'heir': 'Paternal Grandson (Son\'s Son)',
      'refShort': 'Surah An-Nisa 4:11 (by analogy)',
      'quranAyat': 'يُوصِيكُمُ اللَّهُ فِي أَوْلَادِكُمْ',
      'quranTranslation': '"Allah instructs you concerning your children." — Scholars extend this by analogy to grandchildren through sons.',
      'quranRef': 'Surah An-Nisa (4:11) — extended by scholarly consensus (Ijma\')',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Son of the deceased\'s son.',
      'share': 'Residuary — stands fully in the son\'s place when no son is alive.',
      'changes': 'Takes 2:1 with granddaughters, exactly as sons do with daughters.',
      'exclusion': 'Fully excluded by a living son.',
      'explanation': 'Descendants through sons substitute for their fathers, generation by generation.',
      'awlNote': '',
      'raddNote': '',
    },
    {
      'heir': 'Paternal Granddaughter (Son\'s Daughter)',
      'refShort': 'Surah An-Nisa 4:11 (by analogy)',
      'quranAyat': 'فَإِن كُنَّ نِسَاءً فَوْقَ اثْنَتَيْنِ فَلَهُنَّ ثُلُثَا مَا تَرَكَ',
      'quranTranslation': '"If there are more than two daughters, they shall have two thirds of what he left." — Extended to granddaughters by analogy.',
      'quranRef': 'Surah An-Nisa (4:11) — extended by scholarly consensus',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Daughter of the deceased\'s son.',
      'share': '1/2 alone or 2/3 shared if no daughters; 1/6 alongside one daughter (completing 2/3).',
      'changes': 'Becomes residuary with a grandson; drops to 1/6 with one daughter.',
      'exclusion': 'Excluded by a son, or by two or more daughters (unless a grandson exists).',
      'explanation': 'She fills whatever room is left of the daughters\' collective 2/3 maximum.',
      'awlNote': '',
      'raddNote': 'May receive Radd if she is the only surviving heir.',
    },
    {
      'heir': 'Father',
      'refShort': 'Surah An-Nisa 4:11',
      'quranAyat': 'وَلِأَبَوَيْهِ لِكُلِّ وَاحِدٍ مِّنْهُمَا السُّدُسُ مِمَّا تَرَكَ إِن كَانَ لَهُ وَلَدٌ',
      'quranTranslation': '"And for one\'s parents, to each of them is a sixth of what he left if he had a child."',
      'quranRef': 'Surah An-Nisa (4:11)',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Biological father of the deceased.',
      'share': '1/6 fixed with a male descendant; 1/6 + remainder with only female descendants; pure residuary with no descendants.',
      'changes': 'His role shifts between fixed-share and residuary depending on descendants.',
      'exclusion': 'Never excluded.',
      'explanation': 'The father is unique — he can inherit as Fard, as Asaba, or as both at once.',
      'awlNote': 'Under Awl his 1/6 is reduced proportionally.',
      'raddNote': 'Father receives Radd when there are no other residuary heirs.',
    },
    {
      'heir': 'Mother',
      'refShort': 'Surah An-Nisa 4:11',
      'quranAyat': 'فَإِن لَّمْ يَكُن لَّهُ وَلَدٌ وَوَرِثَهُ أَبَوَاهُ فَلِأُمِّهِ الثُّلُثُ ۚ فَإِن كَانَ لَهُ إِخْوَةٌ فَلِأُمِّهِ السُّدُسُ',
      'quranTranslation': '"If he had no child and his parents are his heirs, then for his mother is one third. But if he had brothers, then for his mother is one sixth."',
      'quranRef': 'Surah An-Nisa (4:11)',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Biological mother of the deceased.',
      'share': '1/3 if no children and fewer than two siblings; 1/6 otherwise.',
      'changes': 'Even siblings who are themselves blocked still reduce her to 1/6.',
      'exclusion': 'Never excluded.',
      'explanation': 'The mother always inherits; only the size of her fixed share changes.',
      'awlNote': 'Under Awl her share is reduced proportionally with others.',
      'raddNote': 'Mother receives Radd when there are no residuary heirs.',
    },
    {
      'heir': 'Paternal Grandfather',
      'refShort': 'Surah An-Nisa 4:11 (by analogy)',
      'quranAyat': 'وَلِأَبَوَيْهِ لِكُلِّ وَاحِدٍ مِّنْهُمَا السُّدُسُ',
      'quranTranslation': '"And for one\'s parents, to each of them is one sixth." — Extended by scholars to the grandfather in the father\'s absence.',
      'quranRef': 'Surah An-Nisa (4:11) — Hanafi extension by analogy',
      'hadith': 'The Prophet (ﷺ) granted the grandfather a sixth when he stood in for the father.',
      'hadithRef': 'Sunan Abi Dawud, Book of Inheritance (hadith on grandfather\'s share)',
      'eligibility': 'Father\'s father, when the father has already passed away.',
      'share': 'Acts exactly like the father: 1/6, 1/6 + remainder, or full residuary.',
      'changes': 'Also blocks maternal siblings, like the father does.',
      'exclusion': 'Fully excluded by a living father.',
      'explanation': 'Under Hanafi fiqh the grandfather steps into the father\'s position.',
      'awlNote': '',
      'raddNote': '',
    },
    {
      'heir': 'Paternal Grandmother',
      'refShort': 'Sunnah — Hadith ruling',
      'quranAyat': '',
      'quranTranslation': '',
      'quranRef': '',
      'hadith': 'The Messenger of Allah (ﷺ) gave the grandmother one sixth when there was no mother.',
      'hadithRef': 'Sunan Abi Dawud, Kitab al-Fara\'id, No. 2894; Jami\' al-Tirmidhi, No. 2100 (authenticated)',
      'eligibility': 'Father\'s mother.',
      'share': '1/6 — shared equally (1/12 each) if the maternal grandmother also inherits.',
      'changes': 'Splits the 1/6 whenever both grandmothers qualify.',
      'exclusion': 'Excluded by the mother AND by the father.',
      'explanation': 'The grandmothers\' 1/6 comes from the Sunnah, not directly from the Quran.',
      'awlNote': '',
      'raddNote': 'Paternal grandmother may receive Radd if she is the sole heir.',
    },
    {
      'heir': 'Maternal Grandmother',
      'refShort': 'Sunnah — Hadith ruling',
      'quranAyat': '',
      'quranTranslation': '',
      'quranRef': '',
      'hadith': 'The Prophet (ﷺ) assigned the grandmother one sixth, and when two grandmothers were present they shared it equally.',
      'hadithRef': 'Sunan Abi Dawud, Kitab al-Fara\'id, No. 2894; authenticated by al-Albani',
      'eligibility': 'Mother\'s mother.',
      'share': '1/6 — shared equally with the paternal grandmother if both qualify.',
      'changes': 'Splits the 1/6 when both grandmothers inherit.',
      'exclusion': 'Excluded only by the mother.',
      'explanation': 'She is blocked by her own daughter (the mother) but not by the father.',
      'awlNote': '',
      'raddNote': 'May receive Radd if sole surviving heir.',
    },
    {
      'heir': 'Full Brother',
      'refShort': 'Surah An-Nisa 4:176',
      'quranAyat': 'وَهُوَ يَرِثُهَا إِن لَّمْ يَكُن لَّهَا وَلَدٌ ۚ فَإِن كَانَتَا اثْنَتَيْنِ فَلَهُمَا الثُّلُثَانِ مِمَّا تَرَكَ',
      'quranTranslation': '"And he inherits from her if she has no child. But if there are two sisters, they have two thirds of what he left." (Kalalah verse — applied to siblings by scholars)',
      'quranRef': 'Surah An-Nisa (4:176)',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Brother sharing both parents, in a Kalalah case (no male descendant, no father).',
      'share': 'Residuary (Asaba) — takes the remainder, double each full sister\'s share.',
      'changes': 'Shares 2:1 with full sisters.',
      'exclusion': 'Excluded by a son, grandson, father, or (Hanafi) grandfather.',
      'explanation': 'Full siblings only inherit when the deceased leaves neither a male descendant nor a father.',
      'awlNote': '',
      'raddNote': '',
    },
    {
      'heir': 'Full Sister',
      'refShort': 'Surah An-Nisa 4:176',
      'quranAyat': 'إِنِ امْرُؤٌ هَلَكَ لَيْسَ لَهُ وَلَدٌ وَلَهُ أُخْتٌ فَلَهَا نِصْفُ مَا تَرَكَ',
      'quranTranslation': '"If a man dies, leaving no child but a sister, she will have half of what he left."',
      'quranRef': 'Surah An-Nisa (4:176)',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Sister sharing both parents, in a Kalalah case.',
      'share': '1/2 alone; 2/3 if two or more; residuary with a full brother (2:1) or with daughters.',
      'changes': 'With daughters she becomes Asaba ma\'a al-ghayr and takes the remainder.',
      'exclusion': 'Excluded by a son, grandson, father, or grandfather.',
      'explanation': 'Her three possible roles — Fard, Asaba with brothers, Asaba with daughters.',
      'awlNote': 'Under Awl her fixed share is reduced proportionally.',
      'raddNote': 'Full sister may receive Radd when no residuary heir exists.',
    },
    {
      'heir': 'Paternal Brother',
      'refShort': 'Surah An-Nisa 4:176 (by analogy)',
      'quranAyat': 'يَسْتَفْتُونَكَ قُلِ اللَّهُ يُفْتِيكُمْ فِي الْكَلَالَةِ',
      'quranTranslation': '"They ask you for a ruling. Say: Allah gives you a ruling concerning Kalalah (one with no lineal heirs)."',
      'quranRef': 'Surah An-Nisa (4:176)',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Brother through the father only.',
      'share': 'Residuary (Asaba), double each paternal sister\'s share.',
      'changes': 'Only inherits when no full brother (or full sister taking the residue) exists.',
      'exclusion': 'Excluded by descendants (male), father, grandfather, and full brother.',
      'explanation': 'He ranks one step below full siblings in the residuary chain.',
      'awlNote': '',
      'raddNote': '',
    },
    {
      'heir': 'Paternal Sister',
      'refShort': 'Surah An-Nisa 4:176 (by analogy)',
      'quranAyat': 'يَسْتَفْتُونَكَ قُلِ اللَّهُ يُفْتِيكُمْ فِي الْكَلَالَةِ',
      'quranTranslation': '"They ask you for a ruling. Say: Allah gives you a ruling concerning Kalalah."',
      'quranRef': 'Surah An-Nisa (4:176)',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Sister through the father only.',
      'share': '1/2 alone or 2/3 shared if no full sisters; 1/6 completing 2/3 alongside one full sister.',
      'changes': 'Residuary with a paternal brother (2:1) or with daughters.',
      'exclusion': 'Excluded by male descendants, father, grandfather, a full brother, or two+ full sisters (unless a paternal brother exists).',
      'explanation': 'She mirrors the full sister\'s roles, one tier lower in priority.',
      'awlNote': '',
      'raddNote': '',
    },
    {
      'heir': 'Maternal Sibling',
      'refShort': 'Surah An-Nisa 4:12',
      'quranAyat': 'وَإِن كَانَ رَجُلٌ يُورَثُ كَلَالَةً أَوِ امْرَأَةٌ وَلَهُ أَخٌ أَوْ أُخْتٌ فَلِكُلِّ وَاحِدٍ مِّنْهُمَا السُّدُسُ',
      'quranTranslation': '"And if a man or woman leaves neither parents nor children, but has a brother or sister (maternal), then each one of them shall have a sixth."',
      'quranRef': 'Surah An-Nisa (4:12)',
      'hadith': '',
      'hadithRef': '',
      'eligibility': 'Brother or sister through the mother only, in a Kalalah case.',
      'share': '1/6 if one; 1/3 shared equally if two or more.',
      'changes': 'Unique rule: males and females take perfectly equal parts — no 2:1 ratio.',
      'exclusion': 'Excluded by any descendant, the father, or the grandfather.',
      'explanation': 'Maternal siblings are the only heirs whose gender never affects their share.',
      'awlNote': 'Under Awl their share is reduced proportionally.',
      'raddNote': 'They may receive Radd if no other heir exists.',
    },
    {
      'heir': 'Full Nephew (Full Brother\'s Son)',
      'refShort': 'Asaba chain — Fiqh consensus',
      'quranAyat': '',
      'quranTranslation': '',
      'quranRef': '',
      'hadith': 'The Prophet (ﷺ) said: "Give the obligatory shares to those entitled, and whatever is left is for the nearest male agnate (Asaba)."',
      'hadithRef': 'Sahih al-Bukhari, Kitab al-Fara\'id, No. 6732; Sahih Muslim, No. 1615',
      'eligibility': 'Son of the deceased\'s full brother.',
      'share': 'Residuary — takes the entire remainder when he is the nearest agnate.',
      'changes': 'Multiple nephews split the residue equally.',
      'exclusion': 'Excluded by descendants, father, grandfather, and any brother or residuary sister.',
      'explanation': 'The residuary line passes from brothers down to their sons before moving to uncles.',
      'awlNote': '',
      'raddNote': '',
    },
    {
      'heir': 'Paternal Nephew',
      'refShort': 'Asaba chain — Fiqh consensus',
      'quranAyat': '',
      'quranTranslation': '',
      'quranRef': '',
      'hadith': '"Give the obligatory shares to those entitled, and whatever is left is for the nearest male agnate."',
      'hadithRef': 'Sahih al-Bukhari, Kitab al-Fara\'id, No. 6732',
      'eligibility': 'Son of the deceased\'s paternal half-brother.',
      'share': 'Residuary — same rule as the full nephew, one tier lower.',
      'changes': 'Multiple nephews split the residue equally.',
      'exclusion': 'Excluded by everyone above, including the full nephew.',
      'explanation': 'Within each degree, full-blood relatives always outrank half-blood ones.',
      'awlNote': '',
      'raddNote': '',
    },
    {
      'heir': 'Full Paternal Uncle',
      'refShort': 'Asaba chain — Fiqh consensus',
      'quranAyat': '',
      'quranTranslation': '',
      'quranRef': '',
      'hadith': '"Give the obligatory shares to those entitled, and whatever is left is for the nearest male agnate."',
      'hadithRef': 'Sahih al-Bukhari, Kitab al-Fara\'id, No. 6732',
      'eligibility': 'Full brother of the deceased\'s father.',
      'share': 'Residuary — takes the remainder when no nearer agnate exists.',
      'changes': 'Multiple uncles split the residue equally.',
      'exclusion': 'Excluded by descendants, father, grandfather, brothers, and nephews.',
      'explanation': 'Uncles inherit only after the deceased\'s own line and the brothers\' line are exhausted.',
      'awlNote': '',
      'raddNote': '',
    },
    {
      'heir': 'Paternal Uncle',
      'refShort': 'Asaba chain — Fiqh consensus',
      'quranAyat': '',
      'quranTranslation': '',
      'quranRef': '',
      'hadith': '"Give the obligatory shares to those entitled, and whatever is left is for the nearest male agnate."',
      'hadithRef': 'Sahih al-Bukhari, Kitab al-Fara\'id, No. 6732',
      'eligibility': 'Paternal half-brother of the deceased\'s father.',
      'share': 'Residuary — same as the full uncle, one tier lower.',
      'changes': 'Multiple uncles split the residue equally.',
      'exclusion': 'Excluded by everyone above, including the full uncle.',
      'explanation': 'Again, full blood outranks half blood at the same degree.',
      'awlNote': '',
      'raddNote': '',
    },
    {
      'heir': 'Full Cousin (Full Uncle\'s Son)',
      'refShort': 'Asaba chain — Fiqh consensus',
      'quranAyat': '',
      'quranTranslation': '',
      'quranRef': '',
      'hadith': '"Give the obligatory shares to those entitled, and whatever is left is for the nearest male agnate."',
      'hadithRef': 'Sahih al-Bukhari, Kitab al-Fara\'id, No. 6732',
      'eligibility': 'Son of the deceased\'s full paternal uncle.',
      'share': 'Residuary — inherits the remainder when he is the nearest surviving agnate.',
      'changes': 'Multiple cousins split the residue equally.',
      'exclusion': 'Excluded by all nearer agnates, including both uncles.',
      'explanation': 'Cousins sit near the end of the Asaba chain and rarely inherit in practice.',
      'awlNote': '',
      'raddNote': '',
    },
    {
      'heir': 'Paternal Cousin',
      'refShort': 'Asaba chain — Fiqh consensus',
      'quranAyat': '',
      'quranTranslation': '',
      'quranRef': '',
      'hadith': '"Give the obligatory shares to those entitled, and whatever is left is for the nearest male agnate."',
      'hadithRef': 'Sahih al-Bukhari, Kitab al-Fara\'id, No. 6732',
      'eligibility': 'Son of the deceased\'s paternal half-uncle.',
      'share': 'Residuary — the last male agnate in the standard chain.',
      'changes': 'Multiple cousins split the residue equally.',
      'exclusion': 'Excluded by everyone above, including the full cousin.',
      'explanation': 'If even he is absent, the surplus returns to fixed-share heirs (Radd) or the treasury.',
      'awlNote': '',
      'raddNote': 'If he is the only heir and estate is not fully distributed, Radd may apply.',
    },
  ];
}

// ============================================================
// PAINTERS
// ============================================================

/// Subtle dot-grid pattern for the tree background.
class DotGridPainter extends CustomPainter {
  final Color color;
  DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const step = 24.0;
    const dotRadius = 1.1;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter old) => old.color != color;
}

/// Draws the animated family-tree connector lines.
class FamilyTreeLinkPainter extends CustomPainter {
  final List<List<Offset>> edges;
  final double progress;
  FamilyTreeLinkPainter({required this.edges, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kLinkGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final pts in edges) {
      if (pts.length < 2) continue;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      if (progress >= 1.0) {
        canvas.drawPath(path, paint);
      } else {
        for (final metric in path.computeMetrics()) {
          canvas.drawPath(
              metric.extractPath(0, metric.length * progress), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant FamilyTreeLinkPainter old) =>
      old.progress != progress || old.edges != edges;
}

/// Minimal person silhouette inside the card avatar circle.
class AvatarPainter extends CustomPainter {
  final Gender gender;
  final bool isMe;
  AvatarPainter({required this.gender, required this.isMe});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = Colors.white;
    final cx = size.width / 2;

    canvas.drawCircle(Offset(cx, size.height * 0.36), size.width * 0.16, fill);
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(cx, size.height * 0.86), radius: size.width * 0.28),
      math.pi,
      math.pi,
      true,
      fill,
    );

    if (gender == Gender.female) {
      final stroke = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(cx, size.height * 0.37), radius: size.width * 0.23),
        math.pi * 0.8,
        math.pi * 1.4,
        false,
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AvatarPainter old) =>
      old.gender != gender || old.isMe != isMe;
}

/// Donut chart for the estate distribution.
class FaraidDonutChartPainter extends CustomPainter {
  final List<FaraidShareResult> results;
  final bool isDarkMode;
  FaraidDonutChartPainter({required this.results, required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final colors = <Color>[
      AppColors.navyBlue,
      AppColors.midTeal,
      AppColors.coralOrange,
      Colors.indigo,
      Colors.teal,
      Colors.amber.shade700,
    ];

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const stroke = 30.0;
    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);

    final total = results.fold(0.0, (s, r) => s + r.fraction);
    if (total <= 0) return;

    double start = -math.pi / 2;
    for (int i = 0; i < results.length; i++) {
      final sweep = results[i].fraction / total * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      canvas.drawArc(rect, start, math.max(0.0, sweep - 0.03), false, paint);

      if (sweep > 0.45) {
        final mid = start + sweep / 2;
        final labelPos = Offset(
          center.dx + (radius - stroke / 2) * math.cos(mid),
          center.dy + (radius - stroke / 2) * math.sin(mid),
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '${results[i].percentage.toStringAsFixed(0)}%',
            style: const TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
      }
      start += sweep;
    }

    final centerTp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${results.length}\n',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.navyBlue),
          ),
          TextSpan(
            text: results.length == 1 ? 'Heir' : 'Heirs',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white54 : Colors.black45),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    centerTp.paint(canvas, center - Offset(centerTp.width / 2, centerTp.height / 2));
  }

  @override
  bool shouldRepaint(covariant FaraidDonutChartPainter old) =>
      old.results != results || old.isDarkMode != isDarkMode;
}

