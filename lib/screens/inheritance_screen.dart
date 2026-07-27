import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/auth_header.dart'; // AppColors

// Exact green used by the Hajj & Umrah ritual road.
const Color kLinkGreen = Color(0xFF6FE6A8);

// ============================================================
// ENTRY POINT
// ============================================================
class InheritanceGuideScreen extends StatelessWidget {
  const InheritanceGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => const InheritanceScreen();
}

// ============================================================
// MODELS
// ============================================================
enum Gender { male, female }

class RelativeNode {
  final String id;
  final String label;
  final String? customName;
  final Gender gender;
  final int level; // -2 grandparents ... 2 grandchildren
  final String relationKey;

  RelativeNode({
    required this.id,
    required this.label,
    this.customName,
    required this.gender,
    required this.level,
    required this.relationKey,
  });
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

// ============================================================
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

  // Display order: elders first — grandpa, grandma, father, mother, spouse,
  // siblings, uncles, cousins, then descendants.
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
    final gfActs = !father && pgf; // grandfather stands in for the father
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
        fsMaaGhayr = true; // residuary with daughters
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

    // ---------- 8. EXCLUSION SWEEP for present-but-blocked agnates ----------
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
          note: '${e.note} (Awl — proportionally reduced)',
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
              note: '${e.note} (Radd — increased)',
              level: e.level,
            );
          }
        } else {
          // Spouse is the only heir — return the surplus to them.
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
              note: 'Sole heir — remainder returned (Radd)',
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

// ============================================================
// FAMILY TREE LAYOUT ENGINE
// Positions AND link paths come from here — the painter and the
// cards read the SAME coordinates, so zooming can never dislocate.
// ============================================================
class TreeLayoutResult {
  final double width;
  final double height;
  final Map<String, Offset> centers; // node.id -> card center
  final List<List<Offset>> edges; // polylines

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

  static TreeLayoutResult compute(List<RelativeNode> relatives, double minWidth) {
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

    // ---- edge helpers ----
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

    Offset top(Offset c) => Offset(c.dx, c.dy - half);
    Offset bottom(Offset c) => Offset(c.dx, c.dy + half);

    final edges = <List<Offset>>[];

    List<Offset> elbow(Offset from, Offset to) {
      final midY = (from.dy + to.dy) / 2;
      return [from, Offset(from.dx, midY), Offset(to.dx, midY), to];
    }

    void bracket(Offset childTop, Offset anchorTop) {
      final y = math.min(childTop.dy, anchorTop.dy) - 24;
      edges.add([childTop, Offset(childTop.dx, y), Offset(anchorTop.dx, y), anchorTop]);
    }

    void coupleBar(Offset a, Offset b) {
      final l = a.dx < b.dx ? a : b;
      final r = a.dx < b.dx ? b : a;
      edges.add([Offset(l.dx + cardW / 2, l.dy), Offset(r.dx - cardW / 2, r.dy)]);
    }

    // ---- 1. Paternal grandparents couple -> father & uncles ----
    final gpf = one('pGrandfather');
    final gpm = one('pGrandmother');
    Offset? grandAnchor;
    if (gpf != null && gpm != null) {
      coupleBar(gpf, gpm);
      grandAnchor = Offset((gpf.dx + gpm.dx) / 2, gpf.dy);
    } else if (gpf != null) {
      grandAnchor = bottom(gpf);
    } else if (gpm != null) {
      grandAnchor = bottom(gpm);
    }

    final f = one('father');
    final m = one('mother');
    if (grandAnchor != null && f != null) edges.add(elbow(grandAnchor, top(f)));
    for (final u in [...all('fullUncle'), ...all('paternalUncle')]) {
      if (grandAnchor != null) {
        edges.add(elbow(grandAnchor, top(u)));
      } else if (f != null) {
        bracket(top(u), top(f)); // sibling bracket with father
      }
    }

    // ---- 2. Maternal grandmother -> mother ----
    final mgmC = one('mGrandmother');
    if (mgmC != null && m != null) edges.add(elbow(bottom(mgmC), top(m)));

    // ---- 3. Parents couple -> me & full siblings ----
    Offset? parentAnchor;
    if (f != null && m != null) {
      coupleBar(f, m);
      parentAnchor = Offset((f.dx + m.dx) / 2, f.dy);
    } else if (f != null) {
      parentAnchor = bottom(f);
    } else if (m != null) {
      parentAnchor = bottom(m);
    }

    Offset meC = const Offset(0, 0);
    for (final r in relatives) {
      if (r.id == 'me') meC = centers[r.id]!;
    }
    if (parentAnchor != null) edges.add(elbow(parentAnchor, top(meC)));

    for (final s in [...all('fullBrother'), ...all('fullSister')]) {
      if (parentAnchor != null) {
        edges.add(elbow(parentAnchor, top(s)));
      } else {
        bracket(top(s), top(meC));
      }
    }
    for (final s in [...all('paternalBrother'), ...all('paternalSister')]) {
      final anchor = f != null ? bottom(f) : parentAnchor;
      if (anchor != null) {
        edges.add(elbow(anchor, top(s)));
      } else {
        bracket(top(s), top(meC));
      }
    }
    for (final s in all('maternalSibling')) {
      final anchor = m != null ? bottom(m) : parentAnchor;
      if (anchor != null) {
        edges.add(elbow(anchor, top(s)));
      } else {
        bracket(top(s), top(meC));
      }
    }

    // ---- 4. Me + spouse(s) -> children ----
    final spouses = [...all('wife'), ...all('husband')]
      ..sort((a, b) => a.dx.compareTo(b.dx));
    Offset coupleAnchor;
    if (spouses.isNotEmpty) {
      Offset prev = meC;
      for (final sp in spouses) {
        coupleBar(prev, sp);
        prev = sp;
      }
      coupleAnchor = Offset((meC.dx + spouses.first.dx) / 2, meC.dy);
    } else {
      coupleAnchor = bottom(meC);
    }
    for (final ch in [...all('son'), ...all('daughter')]) {
      edges.add(elbow(coupleAnchor, top(ch)));
    }

    // ---- 5. Son -> grandchildren (or fall back to me) ----
    final sonC = one('son');
    final gAnchor = sonC != null ? bottom(sonC) : coupleAnchor;
    for (final g in [...all('grandson'), ...all('granddaughter')]) {
      edges.add(elbow(gAnchor, top(g)));
    }

    // ---- 6. Brothers -> nephews ----
    final fbC = one('fullBrother');
    if (fbC != null) {
      for (final n in all('fullNephew')) {
        edges.add(elbow(bottom(fbC), top(n)));
      }
    }
    final pbC = one('paternalBrother');
    if (pbC != null) {
      for (final n in all('paternalNephew')) {
        edges.add(elbow(bottom(pbC), top(n)));
      }
    }

    // ---- 7. Uncles -> cousins ----
    final fuC = one('fullUncle');
    if (fuC != null) {
      for (final c in all('fullCousin')) {
        edges.add(elbow(bottom(fuC), top(c)));
      }
    }
    final puC = one('paternalUncle');
    if (puC != null) {
      for (final c in all('paternalCousin')) {
        edges.add(elbow(bottom(puC), top(c)));
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

// ============================================================
// MAIN SCREEN
// ============================================================
class InheritanceScreen extends StatefulWidget {
  const InheritanceScreen({super.key});

  @override
  State<InheritanceScreen> createState() => _InheritanceScreenState();
}

class _InheritanceScreenState extends State<InheritanceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _lineAnimationController;
  bool _isDarkMode = false;

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

  // Relations that can only exist once in the tree.
  static const Set<String> _singletonKeys = {
    'father', 'mother', 'pGrandfather', 'pGrandmother', 'mGrandmother', 'husband',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _lineAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _loadState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lineAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      _familyRelatives = [
        RelativeNode(id: 'me', label: 'Me', gender: _myGender, level: 0, relationKey: 'me'),
        RelativeNode(id: 'f1', label: 'Father', gender: Gender.male, level: -1, relationKey: 'father'),
        RelativeNode(id: 'm1', label: 'Mother', gender: Gender.female, level: -1, relationKey: 'mother'),
      ];
      _recalculateFamilyShares();
    });
    final jsonStr = prefs.getString('inheritance_saved_scenarios');
    if (jsonStr != null) {
      try {
        final list = jsonDecode(jsonStr) as List;
        setState(() => _savedScenarios = list.cast<Map<String, dynamic>>());
      } catch (_) {}
    }
  }

  Future<void> _saveScenariosToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inheritance_saved_scenarios', jsonEncode(_savedScenarios));
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
      {String? customName}) {
    final existing = _familyRelatives.where((r) => r.relationKey == key).length;
    if (_singletonKeys.contains(key) && existing >= 1) {
      _snack('$label is already in the tree');
      return;
    }
    if (key == 'wife' && existing >= 4) {
      _snack('Maximum 4 wives');
      return;
    }
    setState(() {
      _familyRelatives.add(RelativeNode(
        id: '${key}_${DateTime.now().millisecondsSinceEpoch}',
        label: label,
        customName: customName,
        gender: gender,
        level: level,
        relationKey: key,
      ));
      _lineAnimationController.forward(from: 0);
      _recalculateFamilyShares();
    });
  }

  void _removeFamilyMember(String id) {
    if (id == 'me') return;
    setState(() {
      _familyRelatives.removeWhere((r) => r.id == id);
      _lineAnimationController.forward(from: 0);
      _recalculateFamilyShares();
    });
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
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFamilyTreeTab(),
                        _buildCalculationTab(),
                        _buildScenariosTab(),
                        _buildRulesTab(),
                      ],
                    ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: _isDarkMode ? Colors.white : AppColors.navyBlue,
        unselectedLabelColor: _isDarkMode ? Colors.white38 : AppColors.placeholder,
        indicatorColor: AppColors.midTeal,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Family Tree'),
          Tab(text: 'Calculation'),
          Tab(text: 'Scenarios'),
          Tab(text: 'Rules'),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 1: FAMILY TREE
  // ============================================================
  Widget _buildFamilyTreeTab() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
                  // Subtle transparent Islamic star pattern
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GeoPatternPainter(
                        color: _isDarkMode
                            ? kLinkGreen.withValues(alpha: 0.045)
                            : AppColors.navyBlue.withValues(alpha: 0.05),
                      ),
                    ),
                  ),

                  // The zoomable / pannable canvas — links + cards share
                  // one coordinate space, so they always move together.
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, cons) {
                        final layout = FamilyTreeLayout.compute(
                            _familyRelatives, cons.maxWidth);
                        final canvasH =
                            math.max(layout.height, cons.maxHeight);

                        return InteractiveViewer(
                          constrained: false,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          minScale: 0.05,
                          maxScale: 25,
                          child: SizedBox(
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
                                      child: _buildFamilyCard(node),
                                    ),
                              ],
                            ),
                          ),
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

                  // Zoom hint
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
                              color: kLinkGreen.withValues(alpha: 0.35), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pinch_rounded,
                                size: 12,
                                color: _isDarkMode ? kLinkGreen : AppColors.midTeal),
                            const SizedBox(width: 5),
                            Text(
                              'Pinch to zoom · drag to pan',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: _isDarkMode
                                    ? Colors.white70
                                    : AppColors.navyBlue.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAddRelativeDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20, color: Colors.white),
              label: Text('Add Family Member',
                  style: GoogleFonts.poppins(
                      fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
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
          }
          // A male "me" has wives, a female "me" has a husband — clear the
          // mismatched spouse type on switch.
          _familyRelatives.removeWhere(
              (r) => r.relationKey == (g == Gender.male ? 'husband' : 'wife'));
          _recalculateFamilyShares();
        });
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
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () => _removeFamilyMember(node.id),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration:
                    const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

  void _showAddRelativeDialog() {
    String? selectedKey;
    String? customNameInput;

    final options = <Map<String, dynamic>>[
      {'key': 'father', 'label': 'Father', 'gender': Gender.male, 'level': -1},
      {'key': 'mother', 'label': 'Mother', 'gender': Gender.female, 'level': -1},
      {'key': 'pGrandfather', 'label': 'Paternal Grandfather', 'gender': Gender.male, 'level': -2},
      {'key': 'pGrandmother', 'label': 'Paternal Grandmother', 'gender': Gender.female, 'level': -2},
      {'key': 'mGrandmother', 'label': 'Maternal Grandmother', 'gender': Gender.female, 'level': -2},
      {
        'key': _myGender == Gender.male ? 'wife' : 'husband',
        'label': _myGender == Gender.male ? 'Wife' : 'Husband',
        'gender': _myGender == Gender.male ? Gender.female : Gender.male,
        'level': 0,
      },
      {'key': 'son', 'label': 'Son', 'gender': Gender.male, 'level': 1},
      {'key': 'daughter', 'label': 'Daughter', 'gender': Gender.female, 'level': 1},
      {'key': 'grandson', 'label': 'Grandson (Son\'s Son)', 'gender': Gender.male, 'level': 2},
      {'key': 'granddaughter', 'label': 'Granddaughter (Son\'s Daughter)', 'gender': Gender.female, 'level': 2},
      {'key': 'fullBrother', 'label': 'Full Brother', 'gender': Gender.male, 'level': 0},
      {'key': 'fullSister', 'label': 'Full Sister', 'gender': Gender.female, 'level': 0},
      {'key': 'paternalBrother', 'label': 'Paternal Brother', 'gender': Gender.male, 'level': 0},
      {'key': 'paternalSister', 'label': 'Paternal Sister', 'gender': Gender.female, 'level': 0},
      {'key': 'maternalSibling', 'label': 'Maternal Sibling', 'gender': Gender.male, 'level': 0},
      {'key': 'fullNephew', 'label': 'Full Nephew (Full Brother\'s Son)', 'gender': Gender.male, 'level': 1},
      {'key': 'paternalNephew', 'label': 'Paternal Nephew', 'gender': Gender.male, 'level': 1},
      {'key': 'fullUncle', 'label': 'Full Uncle (Father\'s Full Brother)', 'gender': Gender.male, 'level': -1},
      {'key': 'paternalUncle', 'label': 'Paternal Uncle', 'gender': Gender.male, 'level': -1},
      {'key': 'fullCousin', 'label': 'Full Cousin (Full Uncle\'s Son)', 'gender': Gender.male, 'level': 0},
      {'key': 'paternalCousin', 'label': 'Paternal Cousin', 'gender': Gender.male, 'level': 0},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.78),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Family Member',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (val) => customNameInput = val,
                      decoration: InputDecoration(
                        hintText: 'Enter Name (Optional, e.g. "Abbu")',
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
                    const SizedBox(height: 14),
                    Text('Select Relationship:',
                        style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _isDarkMode ? Colors.white70 : AppColors.navyBlue)),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: options.map((opt) {
                            final isSel = selectedKey == opt['key'];
                            return ChoiceChip(
                              label: Text(opt['label'] as String),
                              selected: isSel,
                              selectedColor: AppColors.navyBlue,
                              backgroundColor: _isDarkMode
                                  ? const Color(0xFF2C2C2C)
                                  : const Color(0xFFF0F0F0),
                              labelStyle: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : (_isDarkMode
                                        ? Colors.white70
                                        : AppColors.navyBlue),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (val) => setModalState(
                                  () => selectedKey = val ? opt['key'] as String : null),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedKey == null
                            ? null
                            : () {
                                final sel =
                                    options.firstWhere((o) => o['key'] == selectedKey);
                                _addFamilyMember(
                                  sel['key'] as String,
                                  sel['label'] as String,
                                  sel['gender'] as Gender,
                                  sel['level'] as int,
                                  customName: (customNameInput?.trim().isEmpty ?? true)
                                      ? null
                                      : customNameInput!.trim(),
                                );
                                Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Add to Tree',
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
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

  // ============================================================
  // TAB 2: CALCULATION — flat list, elders first
  // ============================================================
  Widget _buildCalculationTab() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final validResults =
        _familyResults.where((r) => !r.excluded && r.fraction > 0).toList();

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
                        AppColors.navyBlue,
                        AppColors.midTeal,
                        AppColors.coralOrange,
                        Colors.indigo,
                        Colors.teal,
                        Colors.amber.shade700,
                      ];
                      final c = colors[validResults.indexOf(r) % colors.length];
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('${r.label}: ${r.percentage.toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textColor)),
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
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                      color: AppColors.midTeal, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('Distribution Breakdown',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 12),

          // Flat list — engine already ordered it elders-first.
          ..._familyResults.map(_buildPercentageResultCard),

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
  // TAB 3: SCENARIOS — all 22 heirs
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
          // Deceased gender
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

          // Heir selectors
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
                                onChanged: (v) => setState(
                                    () => _scenarioHeirCounts[key] = v ? 1 : 0),
                                activeTrackColor: AppColors.midTeal,
                              )
                            : Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                                    onPressed: () {
                                      final cur = _scenarioHeirCounts[key] ?? 0;
                                      if (cur > 0) {
                                        setState(() =>
                                            _scenarioHeirCounts[key] = cur - 1);
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
                                        setState(() =>
                                            _scenarioHeirCounts[key] = cur + 1);
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
            ..._scenarioResults!.map(_buildPercentageResultCard),
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
            ..._savedScenarios.map((sc) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)
                      ]),
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark_rounded,
                          color: AppColors.midTeal, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(sc['name'] ?? 'Unnamed Scenario',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textColor)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.redAccent),
                        onPressed: () => setState(() {
                          _savedScenarios.remove(sc);
                          _saveScenariosToPrefs();
                        }),
                      ),
                    ],
                  ),
                )),
          ],
        ],
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
                  });
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

    // ============================================================
  // TAB 4: RULES — all 22 heirs
  // ============================================================
  Widget _buildRulesTab() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;

    final rules = <Map<String, String>>[
      {
        'heir': 'Husband',
        'ref': 'Surah An-Nisa 4:12',
        'eligibility': 'Surviving husband of the deceased wife.',
        'share': '1/2 if no descendants; 1/4 if any child or grandchild exists.',
        'changes': 'Reduces from 1/2 to 1/4 the moment any descendant exists.',
        'exclusion': 'Never excluded.',
        'explanation': 'The husband is a fixed-share (Fard) heir; only descendants change his portion.',
      },
      {
        'heir': 'Wife / Wives',
        'ref': 'Surah An-Nisa 4:12',
        'eligibility': 'Surviving wife (or up to 4 wives) of the deceased husband.',
        'share': '1/4 if no descendants; 1/8 if descendants exist — divided equally among all wives.',
        'changes': 'Multiple wives share the single 1/4 or 1/8 equally.',
        'exclusion': 'Never excluded.',
        'explanation': 'The wives\' portion is one collective Quranic share, not one share each.',
      },
      {
        'heir': 'Son',
        'ref': 'Surah An-Nisa 4:11',
        'eligibility': 'Biological son of the deceased.',
        'share': 'Residuary (Asaba) — takes all that remains after fixed shares, double each daughter\'s portion.',
        'changes': 'Shares the residue with daughters at a 2:1 ratio.',
        'exclusion': 'Never excluded.',
        'explanation': 'The son is the strongest residuary; he blocks grandchildren, all siblings, nephews, uncles and cousins.',
      },
      {
        'heir': 'Daughter',
        'ref': 'Surah An-Nisa 4:11',
        'eligibility': 'Biological daughter of the deceased.',
        'share': '1/2 if alone; 2/3 shared if two or more; residuary with a son (2:1).',
        'changes': 'Turns from fixed-share heir into residuary whenever a son exists.',
        'exclusion': 'Never excluded.',
        'explanation': 'A brother converts her Quranic share into a proportional residuary share.',
      },
      {
        'heir': 'Paternal Grandson (Son\'s Son)',
        'ref': 'Surah An-Nisa 4:11 (by analogy)',
        'eligibility': 'Son of the deceased\'s son.',
        'share': 'Residuary — stands fully in the son\'s place when no son is alive.',
        'changes': 'Takes 2:1 with granddaughters, exactly as sons do with daughters.',
        'exclusion': 'Fully excluded by a living son.',
        'explanation': 'Descendants through sons substitute for their fathers, generation by generation.',
      },
      {
        'heir': 'Paternal Granddaughter (Son\'s Daughter)',
        'ref': 'Surah An-Nisa 4:11 (by analogy)',
        'eligibility': 'Daughter of the deceased\'s son.',
        'share': '1/2 alone or 2/3 shared if no daughters; 1/6 alongside one daughter (completing 2/3).',
        'changes': 'Becomes residuary with a grandson; drops to 1/6 with one daughter.',
        'exclusion': 'Excluded by a son, or by two or more daughters (unless a grandson exists).',
        'explanation': 'She fills whatever room is left of the daughters\' collective 2/3 maximum.',
      },
      {
        'heir': 'Father',
        'ref': 'Surah An-Nisa 4:11',
        'eligibility': 'Biological father of the deceased.',
        'share': '1/6 fixed with a male descendant; 1/6 + remainder with only female descendants; pure residuary with no descendants.',
        'changes': 'His role shifts between fixed-share and residuary depending on descendants.',
        'exclusion': 'Never excluded.',
        'explanation': 'The father is unique — he can inherit as Fard, as Asaba, or as both at once.',
      },
      {
        'heir': 'Mother',
        'ref': 'Surah An-Nisa 4:11',
        'eligibility': 'Biological mother of the deceased.',
        'share': '1/3 if no children and fewer than two siblings; 1/6 otherwise.',
        'changes': 'Even siblings who are themselves blocked still reduce her to 1/6.',
        'exclusion': 'Never excluded.',
        'explanation': 'The mother always inherits; only the size of her fixed share changes.',
      },
      {
        'heir': 'Paternal Grandfather',
        'ref': 'Surah An-Nisa 4:11 (by analogy)',
        'eligibility': 'Father\'s father, when the father has already passed away.',
        'share': 'Acts exactly like the father: 1/6, 1/6 + remainder, or full residuary.',
        'changes': 'Also blocks maternal siblings, like the father does.',
        'exclusion': 'Fully excluded by a living father.',
        'explanation': 'Under Hanafi fiqh the grandfather steps into the father\'s position.',
      },
      {
        'heir': 'Paternal Grandmother',
        'ref': 'Hadith ruling',
        'eligibility': 'Father\'s mother.',
        'share': '1/6 — shared equally (1/12 each) if the maternal grandmother also inherits.',
        'changes': 'Splits the 1/6 whenever both grandmothers qualify.',
        'exclusion': 'Excluded by the mother AND by the father.',
        'explanation': 'The grandmothers\' 1/6 comes from the Sunnah, not directly from the Quran.',
      },
      {
        'heir': 'Maternal Grandmother',
        'ref': 'Hadith ruling',
        'eligibility': 'Mother\'s mother.',
        'share': '1/6 — shared equally with the paternal grandmother if both qualify.',
        'changes': 'Splits the 1/6 when both grandmothers inherit.',
        'exclusion': 'Excluded only by the mother.',
        'explanation': 'She is blocked by her own daughter (the mother) but not by the father.',
      },
      {
        'heir': 'Full Brother',
        'ref': 'Surah An-Nisa 4:176',
        'eligibility': 'Brother sharing both parents, in a Kalalah case (no male descendant, no father).',
        'share': 'Residuary (Asaba) — takes the remainder, double each full sister\'s portion.',
        'changes': 'Shares 2:1 with full sisters.',
        'exclusion': 'Excluded by a son, grandson, father, or (Hanafi) grandfather.',
        'explanation': 'Full siblings only inherit when the deceased leaves neither a male descendant nor a father.',
      },
      {
        'heir': 'Full Sister',
        'ref': 'Surah An-Nisa 4:176',
        'eligibility': 'Sister sharing both parents, in a Kalalah case.',
        'share': '1/2 alone; 2/3 if two or more; residuary with a full brother (2:1) or with daughters.',
        'changes': 'With daughters she becomes Asaba ma\'a al-ghayr and takes the remainder.',
        'exclusion': 'Excluded by a son, grandson, father, or grandfather.',
        'explanation': 'Her three possible roles — Fard, Asaba with brothers, Asaba with daughters — cover most sister cases.',
      },
      {
        'heir': 'Paternal Brother',
        'ref': 'Surah An-Nisa 4:176 (by analogy)',
        'eligibility': 'Brother through the father only.',
        'share': 'Residuary (Asaba), double each paternal sister\'s portion.',
        'changes': 'Only inherits when no full brother (or full sister taking the residue) exists.',
        'exclusion': 'Excluded by descendants (male), father, grandfather, and full brother.',
        'explanation': 'He ranks one step below full siblings in the residuary chain.',
      },
      {
        'heir': 'Paternal Sister',
        'ref': 'Surah An-Nisa 4:176 (by analogy)',
        'eligibility': 'Sister through the father only.',
        'share': '1/2 alone or 2/3 shared if no full sisters; 1/6 completing 2/3 alongside one full sister.',
        'changes': 'Residuary with a paternal brother (2:1) or with daughters.',
        'exclusion': 'Excluded by male descendants, father, grandfather, a full brother, or two+ full sisters (unless a paternal brother exists).',
        'explanation': 'She mirrors the full sister\'s roles, one tier lower in priority.',
      },
      {
        'heir': 'Maternal Sibling',
        'ref': 'Surah An-Nisa 4:12',
        'eligibility': 'Brother or sister through the mother only, in a Kalalah case.',
        'share': '1/6 if one; 1/3 shared equally if two or more.',
        'changes': 'Unique rule: males and females take perfectly equal parts — no 2:1 ratio.',
        'exclusion': 'Excluded by any descendant, the father, or the grandfather.',
        'explanation': 'Maternal siblings are the only heirs whose gender never affects their share.',
      },
      {
        'heir': 'Full Nephew (Full Brother\'s Son)',
        'ref': 'Asaba chain (fiqh)',
        'eligibility': 'Son of the deceased\'s full brother.',
        'share': 'Residuary — takes the entire remainder when he is the nearest agnate.',
        'changes': 'Multiple nephews split the residue equally.',
        'exclusion': 'Excluded by descendants, father, grandfather, and any brother or residuary sister.',
        'explanation': 'The residuary line passes from brothers down to their sons before moving to uncles.',
      },
      {
        'heir': 'Paternal Nephew',
        'ref': 'Asaba chain (fiqh)',
        'eligibility': 'Son of the deceased\'s paternal half-brother.',
        'share': 'Residuary — same rule as the full nephew, one tier lower.',
        'changes': 'Multiple nephews split the residue equally.',
        'exclusion': 'Excluded by everyone above, including the full nephew.',
        'explanation': 'Within each degree, full-blood relatives always outrank half-blood ones.',
      },
      {
        'heir': 'Full Uncle (Father\'s Full Brother)',
        'ref': 'Asaba chain (fiqh)',
        'eligibility': 'Full brother of the deceased\'s father.',
        'share': 'Residuary — takes the remainder when no nearer agnate exists.',
        'changes': 'Multiple uncles split the residue equally.',
        'exclusion': 'Excluded by descendants, father, grandfather, brothers, and nephews.',
        'explanation': 'Uncles inherit only after the deceased\'s own line and the brothers\' line are exhausted.',
      },
      {
        'heir': 'Paternal Uncle',
        'ref': 'Asaba chain (fiqh)',
        'eligibility': 'Paternal half-brother of the deceased\'s father.',
        'share': 'Residuary — same as the full uncle, one tier lower.',
        'changes': 'Multiple uncles split the residue equally.',
        'exclusion': 'Excluded by everyone above, including the full uncle.',
        'explanation': 'Again, full blood outranks half blood at the same degree.',
      },
      {
        'heir': 'Full Cousin (Full Uncle\'s Son)',
        'ref': 'Asaba chain (fiqh)',
        'eligibility': 'Son of the deceased\'s full paternal uncle.',
        'share': 'Residuary — inherits the remainder when he is the nearest surviving agnate.',
        'changes': 'Multiple cousins split the residue equally.',
        'exclusion': 'Excluded by all nearer agnates, including both uncles.',
        'explanation': 'Cousins sit near the end of the Asaba chain and rarely inherit in practice.',
      },
      {
        'heir': 'Paternal Cousin',
        'ref': 'Asaba chain (fiqh)',
        'eligibility': 'Son of the deceased\'s paternal half-uncle.',
        'share': 'Residuary — the last male agnate in the standard chain.',
        'changes': 'Multiple cousins split the residue equally.',
        'exclusion': 'Excluded by everyone above, including the full cousin.',
        'explanation': 'If even he is absent, the surplus returns to fixed-share heirs (Radd) or the treasury.',
      },
    ];

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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: kLinkGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Faraid Rules Reference',
                          style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text('22 heirs · fixed shares, residue & exclusion (Hanafi)',
                          style: GoogleFonts.inter(
                              fontSize: 10.5, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

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

  Widget _buildRuleCard(Map<String, String> rule, Color cardBg, Color textColor) {
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: AppColors.midTeal,
          collapsedIconColor: _isDarkMode ? Colors.white38 : AppColors.placeholder,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.midTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.gavel_rounded, size: 18, color: AppColors.midTeal),
          ),
          title: Text(rule['heir']!,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(rule['ref']!,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.midTeal)),
          ),
          children: [
            _ruleRow(Icons.how_to_reg_rounded, 'Who qualifies',
                rule['eligibility']!, textColor),
            _ruleRow(Icons.pie_chart_rounded, 'Share', rule['share']!, textColor),
            _ruleRow(Icons.sync_alt_rounded, 'How it changes', rule['changes']!,
                textColor),
            _ruleRow(Icons.block_rounded, 'Exclusion', rule['exclusion']!,
                textColor, iconColor: AppColors.coralOrange),
            _ruleRow(Icons.lightbulb_outline_rounded, 'In short',
                rule['explanation']!, textColor),
          ],
        ),
      ),
    );
  }

  Widget _ruleRow(IconData icon, String title, String value, Color textColor,
      {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: iconColor ?? AppColors.midTeal),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                      text: '$title:  ',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textColor)),
                  TextSpan(
                      text: value,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          height: 1.35,
                          color: _isDarkMode
                              ? Colors.white70
                              : AppColors.navyBlue.withValues(alpha: 0.75))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PAINTERS
// ============================================================

/// Subtle 8-point Islamic star pattern for the tree background.
class GeoPatternPainter extends CustomPainter {
  final Color color;
  GeoPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 56.0;
    for (double x = 0; x <= size.width + step; x += step) {
      for (double y = 0; y <= size.height + step; y += step) {
        _drawStar(canvas, Offset(x, y), 16, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final aOut = i * math.pi / 4 - math.pi / 2;
      final aIn = aOut + math.pi / 8;
      final outer = Offset(c.dx + r * math.cos(aOut), c.dy + r * math.sin(aOut));
      final inner = Offset(
          c.dx + r * 0.45 * math.cos(aIn), c.dy + r * 0.45 * math.sin(aIn));
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant GeoPatternPainter old) => old.color != color;
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

    // Head
    canvas.drawCircle(Offset(cx, size.height * 0.36), size.width * 0.16, fill);

    // Shoulders (half-disc clipped by the circle's bottom)
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(cx, size.height * 0.86), radius: size.width * 0.28),
      math.pi,
      math.pi,
      true,
      fill,
    );

    // Simple hijab-style outline for female nodes
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

      // Percentage label on slices wide enough to fit it
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

    // Center label
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
