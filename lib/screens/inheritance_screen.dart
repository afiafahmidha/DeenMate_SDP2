import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/auth_header.dart'; // AppColors

/// ===== ISLAMIC INHERITANCE (FARAID) MODULE =====
/// Entry point — shows two cards: Calculate by Share, and Rules.
/// Push like the other planner pages:
///   Navigator.of(context).push(
///     MaterialPageRoute(builder: (_) => const InheritanceGuideScreen()),
///   );
class InheritanceGuideScreen extends StatelessWidget {
  const InheritanceGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: const Color(0xFFF7F7F5),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.navyBlue, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.navyBlue, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Inheritance (Faraid)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                            Text('Islamic estate distribution guide', style: GoogleFonts.inter(fontSize: 11, color: AppColors.navyBlue.withValues(alpha: 0.55))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _homeCard(
                    context: context,
                    icon: Icons.calculate_rounded,
                    title: 'Calculate by Share',
                    subtitle: 'Select surviving heirs to see each share as a fraction and percentage',
                    color: AppColors.navyBlue,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalculateByShareScreen())),
                  ),
                  const SizedBox(height: 14),
                  _homeCard(
                    context: context,
                    icon: Icons.menu_book_rounded,
                    title: 'Rules of Inheritance',
                    subtitle: 'Learn the eligibility, share, and exclusion rules for every heir',
                    color: AppColors.midTeal,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InheritanceRulesScreen())),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.navyBlue.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.coralOrange, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This calculator follows standard Hanafi fiqh rules, including the full priority order of extended heirs and adjustments for Awl (proportional reduction) and Radd (return of residue). For actual estate distribution, please have the result verified by a qualified Islamic scholar or Faraid expert.',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.navyBlue.withValues(alpha: 0.6), height: 1.5),
                          ),
                        ),
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

  Widget _homeCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.navyBlue.withValues(alpha: 0.55), height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FARAID CALCULATION ENGINE
// ============================================================

class FaraidShare {
  final String label;
  final double fraction; // 0.0 - 1.0
  final String note;
  final bool excluded;
  FaraidShare({required this.label, required this.fraction, required this.note, this.excluded = false});
}

class HeirCounts {
  String deceasedGender = 'Male';
  bool spouseAlive = false;
  int wivesCount = 1;
  int son = 0;
  int daughter = 0;
  int grandson = 0; // son's son
  int granddaughter = 0; // son's daughter
  bool father = false;
  bool mother = false;
  bool paternalGrandfather = false;
  bool paternalGrandmother = false;
  bool maternalGrandmother = false;
  int fullBrother = 0;
  int fullSister = 0;
  int paternalBrother = 0;
  int paternalSister = 0;
  int maternalSibling = 0;
  int fullNephew = 0;
  int paternalNephew = 0;
  int fullUncle = 0;
  int paternalUncle = 0;
  int fullCousin = 0;
  int paternalCousin = 0;
}

class FaraidCalculator {
  static List<FaraidShare> calculate(HeirCounts h) {
    final List<FaraidShare> results = [];
    double usedFraction = 0.0;
    bool residueClaimed = false;

    final bool hasSon = h.son > 0;
    final bool hasRealDaughter = h.daughter > 0;
    final bool hasGrandson = !hasSon && h.grandson > 0;
    final bool hasGranddaughterRaw = !hasSon && h.granddaughter > 0;
    final bool hasMaleDescendant = hasSon || hasGrandson;
    final bool hasAnyDescendant = hasSon || hasRealDaughter || hasGrandson || hasGranddaughterRaw;

    // ---- 1. SPOUSE (Fard) ----
    double spouseFraction = 0.0;
    if (h.spouseAlive) {
      if (h.deceasedGender == 'Male') {
        spouseFraction = hasAnyDescendant ? (1 / 8) : (1 / 4);
        final perWife = spouseFraction / h.wivesCount;
        for (int i = 0; i < h.wivesCount; i++) {
          results.add(FaraidShare(
            label: h.wivesCount > 1 ? 'Wife ${i + 1}' : 'Wife',
            fraction: perWife,
            note: hasAnyDescendant ? 'Fard: 1/8 (shared, descendant present)' : 'Fard: 1/4 (shared)',
          ));
        }
      } else {
        spouseFraction = hasAnyDescendant ? (1 / 4) : (1 / 2);
        results.add(FaraidShare(label: 'Husband', fraction: spouseFraction, note: hasAnyDescendant ? 'Fard: 1/4 (descendant present)' : 'Fard: 1/2'));
      }
      usedFraction += spouseFraction;
    }

    // ---- 2. DESCENDANTS: Fard portions for daughters/granddaughters, Asaba residue tracked separately ----
    double childrenFardUsed = 0.0;
    bool sonsTakeAsaba = false;
    bool grandsonsTakeAsaba = false;

    if (hasSon) {
      sonsTakeAsaba = true; // sons + daughters split residue together later
    } else if (hasRealDaughter) {
      final double daughterFraction = h.daughter == 1 ? (1 / 2) : (2 / 3);
      results.add(FaraidShare(
        label: h.daughter > 1 ? '${h.daughter} Daughters (combined)' : 'Daughter',
        fraction: daughterFraction,
        note: h.daughter == 1 ? 'Fard: 1/2 (only daughter)' : 'Fard: 2/3 (shared, no son present)',
      ));
      childrenFardUsed += daughterFraction;
      usedFraction += daughterFraction;

      if (hasGrandson) {
        grandsonsTakeAsaba = true; // grandsons + granddaughters take residue together
      } else if (hasGranddaughterRaw) {
        if (h.daughter == 1) {
          results.add(FaraidShare(
            label: h.granddaughter > 1 ? '${h.granddaughter} Paternal Granddaughters (combined)' : 'Paternal Granddaughter',
            fraction: 1 / 6,
            note: 'Fard: 1/6 (completes 2/3 with the one daughter)',
          ));
          usedFraction += 1 / 6;
        } else {
          results.add(FaraidShare(
            label: h.granddaughter > 1 ? '${h.granddaughter} Paternal Granddaughters (combined)' : 'Paternal Granddaughter',
            fraction: 0,
            note: 'Excluded — two or more real daughters already reached the 2/3 maximum, and no grandson is present to make her residuary.',
            excluded: true,
          ));
        }
      }
    } else if (hasGrandson) {
      grandsonsTakeAsaba = true;
    } else if (hasGranddaughterRaw) {
      final double gdFraction = h.granddaughter == 1 ? (1 / 2) : (2 / 3);
      results.add(FaraidShare(
        label: h.granddaughter > 1 ? '${h.granddaughter} Paternal Granddaughters (combined)' : 'Paternal Granddaughter',
        fraction: gdFraction,
        note: 'Fard: standing in as daughter\'s share (no real daughter present)',
      ));
      childrenFardUsed += gdFraction;
      usedFraction += gdFraction;
    }

    // ---- 3. FATHER / PATERNAL GRANDFATHER (Fard 1/6 + possible Asaba) ----
    bool fatherIsAsabaCandidate = false;
    if (h.father) {
      if (hasAnyDescendant) {
        final double fatherFraction = 1 / 6;
        results.add(FaraidShare(label: 'Father', fraction: fatherFraction, note: 'Fard: 1/6 (descendant present)'));
        usedFraction += fatherFraction;
        if (!hasMaleDescendant) fatherIsAsabaCandidate = true; // gets residue too, on top of 1/6
      } else {
        fatherIsAsabaCandidate = true; // pure Asaba, no descendant at all
      }
    }
    final bool grandfatherEligible = !h.father && h.paternalGrandfather;
    bool grandfatherIsAsabaCandidate = false;
    if (grandfatherEligible) {
      if (hasAnyDescendant) {
        final double grandfatherFraction = 1 / 6;
        results.add(FaraidShare(label: 'Paternal Grandfather', fraction: grandfatherFraction, note: 'Fard: 1/6 (descendant present, no father)'));
        usedFraction += grandfatherFraction;
        if (!hasMaleDescendant) grandfatherIsAsabaCandidate = true;
      } else {
        grandfatherIsAsabaCandidate = true;
      }
    } else if (h.paternalGrandfather && h.father) {
      results.add(FaraidShare(label: 'Paternal Grandfather', fraction: 0, note: 'Excluded — father is alive.', excluded: true));
    }

    // ---- 4. MOTHER (Fard 1/6 or 1/3, with Umariyyatain exception) ----
    final int siblingCountForHijab = h.fullBrother + h.fullSister + h.paternalBrother + h.paternalSister + h.maternalSibling;
    if (h.mother) {
      double motherFraction;
      String motherNote;
      final bool onlySpouseAndParents = h.spouseAlive && h.father && !hasAnyDescendant && siblingCountForHijab == 0;
      if (hasAnyDescendant || siblingCountForHijab >= 2) {
        motherFraction = 1 / 6;
        motherNote = hasAnyDescendant ? 'Fard: 1/6 (descendant present)' : 'Fard: 1/6 (2+ siblings present, even if they don\'t inherit)';
      } else if (onlySpouseAndParents) {
        final double remainderAfterSpouse = 1.0 - spouseFraction;
        motherFraction = remainderAfterSpouse / 3;
        motherNote = 'Fard: 1/3 of the remainder after spouse\'s share (special "Umariyyatain" case — spouse + both parents only)';
      } else {
        motherFraction = 1 / 3;
        motherNote = 'Fard: 1/3 (no descendants, fewer than 2 siblings)';
      }
      results.add(FaraidShare(label: 'Mother', fraction: motherFraction, note: motherNote));
      usedFraction += motherFraction;
    }

    // ---- 5. GRANDMOTHERS (blocked by mother) ----
    final bool paternalGmBlocked = h.mother || h.father;
    final bool maternalGmBlocked = h.mother;
    final bool paternalGmEligible = h.paternalGrandmother && !paternalGmBlocked;
    final bool maternalGmEligible = h.maternalGrandmother && !maternalGmBlocked;
    if (h.paternalGrandmother && paternalGmBlocked) {
      results.add(FaraidShare(label: 'Paternal Grandmother', fraction: 0, note: 'Excluded — blocked by ${h.mother ? 'mother' : 'father'} being alive.', excluded: true));
    }
    if (h.maternalGrandmother && maternalGmBlocked) {
      results.add(FaraidShare(label: 'Maternal Grandmother', fraction: 0, note: 'Excluded — blocked by mother being alive.', excluded: true));
    }
    if (paternalGmEligible || maternalGmEligible) {
      final int gmCount = (paternalGmEligible ? 1 : 0) + (maternalGmEligible ? 1 : 0);
      final double each = (1 / 6) / gmCount;
      if (paternalGmEligible) {
        results.add(FaraidShare(label: 'Paternal Grandmother', fraction: each, note: gmCount > 1 ? 'Fard: shares 1/6 with maternal grandmother' : 'Fard: 1/6'));
        usedFraction += each;
      }
      if (maternalGmEligible) {
        results.add(FaraidShare(label: 'Maternal Grandmother', fraction: each, note: gmCount > 1 ? 'Fard: shares 1/6 with paternal grandmother' : 'Fard: 1/6'));
        usedFraction += each;
      }
    }

    // ---- 6. SIBLINGS ----
    final bool siblingsBlockedByAscendantOrMale = h.father || grandfatherEligible || hasMaleDescendant;
    final bool maternalSiblingsBlocked = siblingsBlockedByAscendantOrMale || hasAnyDescendant;

    bool fullSiblingsTakeAsaba = false;
    bool fullSisterAsabaMaaGhayr = false;
    bool paternalSiblingsExcludedByFull = false;

    if (siblingsBlockedByAscendantOrMale) {
      if (h.fullBrother + h.fullSister > 0) {
        results.add(FaraidShare(label: 'Full Siblings', fraction: 0, note: 'Excluded — blocked by father, paternal grandfather, or a male descendant.', excluded: true));
      }
      if (h.paternalBrother + h.paternalSister > 0) {
        results.add(FaraidShare(label: 'Paternal Siblings', fraction: 0, note: 'Excluded — blocked by father, paternal grandfather, or a male descendant.', excluded: true));
      }
    } else {
      // Full siblings
      if (h.fullBrother > 0) {
        fullSiblingsTakeAsaba = true; // resolved later with residue
      } else if (h.fullSister > 0) {
        if (childrenFardUsed > 0 && !hasMaleDescendant) {
          fullSisterAsabaMaaGhayr = true; // becomes residuary alongside daughters
        } else {
          final double fsFraction = h.fullSister == 1 ? (1 / 2) : (2 / 3);
          results.add(FaraidShare(
            label: h.fullSister > 1 ? '${h.fullSister} Full Sisters (combined)' : 'Full Sister',
            fraction: fsFraction,
            note: h.fullSister == 1 ? 'Fard: 1/2 (only full sister, no full brother)' : 'Fard: 2/3 (shared, no full brother)',
          ));
          usedFraction += fsFraction;
        }
      }

      // Paternal siblings — only relevant if full brother absent
      if (h.fullBrother > 0) {
        paternalSiblingsExcludedByFull = true;
        if (h.paternalBrother + h.paternalSister > 0) {
          results.add(FaraidShare(label: 'Paternal Siblings', fraction: 0, note: 'Excluded — a full brother is present.', excluded: true));
        }
      } else if (h.fullSister >= 2 && h.paternalBrother == 0) {
        paternalSiblingsExcludedByFull = true;
        if (h.paternalSister > 0) {
          results.add(FaraidShare(label: 'Paternal Sister', fraction: 0, note: 'Excluded — two or more full sisters already reached 2/3, and no paternal brother is present to make her residuary.', excluded: true));
        }
      } else {
        if (h.paternalBrother > 0) {
          // paternal brothers (+sisters) become asaba, handled with residue below
        } else if (h.paternalSister > 0) {
          if (h.fullSister == 1) {
            results.add(FaraidShare(
              label: h.paternalSister > 1 ? '${h.paternalSister} Paternal Sisters (combined)' : 'Paternal Sister',
              fraction: 1 / 6,
              note: 'Fard: 1/6 (completes 2/3 with the one full sister)',
            ));
            usedFraction += 1 / 6;
          } else if (childrenFardUsed > 0 && !hasMaleDescendant && h.fullSister == 0) {
            // asaba ma'a ghayr with daughters, handled below via flag
          } else if (h.fullSister == 0) {
            final double psFraction = h.paternalSister == 1 ? (1 / 2) : (2 / 3);
            results.add(FaraidShare(
              label: h.paternalSister > 1 ? '${h.paternalSister} Paternal Sisters (combined)' : 'Paternal Sister',
              fraction: psFraction,
              note: h.paternalSister == 1 ? 'Fard: 1/2 (only paternal sister)' : 'Fard: 2/3 (shared)',
            ));
            usedFraction += psFraction;
          }
        }
      }

      // Maternal siblings
      if (maternalSiblingsBlocked) {
        if (h.maternalSibling > 0) {
          results.add(FaraidShare(label: 'Maternal Sibling(s)', fraction: 0, note: 'Excluded — blocked by father, paternal grandfather, or any descendant.', excluded: true));
        }
      } else if (h.maternalSibling > 0) {
        final double msFraction = h.maternalSibling == 1 ? (1 / 6) : (1 / 3);
        results.add(FaraidShare(
          label: h.maternalSibling > 1 ? '${h.maternalSibling} Maternal Siblings (combined)' : 'Maternal Sibling',
          fraction: msFraction,
          note: h.maternalSibling == 1 ? 'Fard: 1/6' : 'Fard: 1/3 (shared equally, regardless of gender)',
        ));
        usedFraction += msFraction;
      }
    }
    if (maternalSiblingsBlocked && !siblingsBlockedByAscendantOrMale && h.maternalSibling > 0) {
      results.add(FaraidShare(label: 'Maternal Sibling(s)', fraction: 0, note: 'Excluded — blocked by a descendant being present.', excluded: true));
    }

    // ---- 7. RESIDUE (ASABA) — priority chain ----
    final double remainder = (1.0 - usedFraction).clamp(0.0, 1.0);

    if (sonsTakeAsaba) {
      final double units = (h.son * 2 + h.daughter).toDouble();
      final double perUnit = units > 0 ? remainder / units : 0;
      results.add(FaraidShare(label: h.son > 1 ? '${h.son} Sons (combined)' : 'Son', fraction: perUnit * 2 * h.son, note: 'Residuary (Asaba) — each son gets 2x a daughter\'s share'));
      if (h.daughter > 0) {
        results.add(FaraidShare(label: h.daughter > 1 ? '${h.daughter} Daughters (combined, as residuary with sons)' : 'Daughter (as residuary with son)', fraction: perUnit * h.daughter, note: 'Residuary (Asaba) — shares with son(s), half a son\'s portion each'));
      }
      residueClaimed = true;
    } else if (grandsonsTakeAsaba) {
      final double units = (h.grandson * 2 + h.granddaughter).toDouble();
      final double perUnit = units > 0 ? remainder / units : 0;
      results.add(FaraidShare(label: h.grandson > 1 ? '${h.grandson} Paternal Grandsons (combined)' : 'Paternal Grandson', fraction: perUnit * 2 * h.grandson, note: 'Residuary (Asaba) — takes remainder as closest male descendant'));
      if (h.granddaughter > 0) {
        results.add(FaraidShare(label: h.granddaughter > 1 ? '${h.granddaughter} Paternal Granddaughters (combined, residuary)' : 'Paternal Granddaughter (residuary)', fraction: perUnit * h.granddaughter, note: 'Residuary (Asaba) — shares with grandson(s)'));
      }
      residueClaimed = true;
    } else if (fatherIsAsabaCandidate) {
      final int fIdx = results.indexWhere((e) => e.label == 'Father');
      if (fIdx != -1) {
        results[fIdx] = FaraidShare(label: 'Father', fraction: results[fIdx].fraction + remainder, note: 'Fard 1/6 + residue as Asaba (no male descendant present)');
      } else {
        results.add(FaraidShare(label: 'Father', fraction: remainder, note: 'Residuary (Asaba) — takes remaining estate as nearest male ascendant'));
      }
      residueClaimed = true;
    } else if (grandfatherIsAsabaCandidate) {
      final int gIdx = results.indexWhere((e) => e.label == 'Paternal Grandfather');
      if (gIdx != -1) {
        results[gIdx] = FaraidShare(label: 'Paternal Grandfather', fraction: results[gIdx].fraction + remainder, note: 'Fard 1/6 + residue as Asaba (no male descendant, father absent)');
      } else {
        results.add(FaraidShare(label: 'Paternal Grandfather', fraction: remainder, note: 'Residuary (Asaba) — takes remaining estate (father absent)'));
      }
      residueClaimed = true;
    } else if (fullSiblingsTakeAsaba) {
      final double units = (h.fullBrother * 2 + h.fullSister).toDouble();
      final double perUnit = units > 0 ? remainder / units : 0;
      results.add(FaraidShare(label: h.fullBrother > 1 ? '${h.fullBrother} Full Brothers (combined)' : 'Full Brother', fraction: perUnit * 2 * h.fullBrother, note: 'Residuary (Asaba) — takes remainder, no closer heir present'));
      if (h.fullSister > 0) {
        results.add(FaraidShare(label: h.fullSister > 1 ? '${h.fullSister} Full Sisters (combined, with brother)' : 'Full Sister (with brother)', fraction: perUnit * h.fullSister, note: 'Residuary (Asaba) — shares with full brother(s), 2:1 ratio'));
      }
      residueClaimed = true;
    } else if (fullSisterAsabaMaaGhayr) {
      results.add(FaraidShare(label: h.fullSister > 1 ? '${h.fullSister} Full Sisters (combined)' : 'Full Sister', fraction: remainder, note: 'Residuary "Asaba ma\'a ghayr" — inherits alongside daughters/granddaughters since no father, grandfather, or male descendant is present'));
      residueClaimed = true;
    } else if (!paternalSiblingsExcludedByFull && h.paternalBrother > 0) {
      final double units = (h.paternalBrother * 2 + h.paternalSister).toDouble();
      final double perUnit = units > 0 ? remainder / units : 0;
      results.add(FaraidShare(label: h.paternalBrother > 1 ? '${h.paternalBrother} Paternal Brothers (combined)' : 'Paternal Brother', fraction: perUnit * 2 * h.paternalBrother, note: 'Residuary (Asaba) — no full brother present'));
      if (h.paternalSister > 0) {
        results.add(FaraidShare(label: h.paternalSister > 1 ? '${h.paternalSister} Paternal Sisters (combined, with brother)' : 'Paternal Sister (with brother)', fraction: perUnit * h.paternalSister, note: 'Residuary (Asaba) — shares with paternal brother(s)'));
      }
      residueClaimed = true;
    } else if (!paternalSiblingsExcludedByFull && h.paternalSister > 0 && childrenFardUsed > 0 && !hasMaleDescendant && h.fullSister == 0) {
      results.add(FaraidShare(label: h.paternalSister > 1 ? '${h.paternalSister} Paternal Sisters (combined)' : 'Paternal Sister', fraction: remainder, note: 'Residuary "Asaba ma\'a ghayr" — inherits alongside daughters/granddaughters'));
      residueClaimed = true;
    } else if (h.fullNephew > 0) {
      results.add(FaraidShare(label: h.fullNephew > 1 ? '${h.fullNephew} Full Nephews (combined)' : 'Full Nephew', fraction: remainder, note: 'Residuary (Asaba) — closer heirs absent, inherits as full brother\'s son(s)'));
      residueClaimed = true;
    } else if (h.paternalNephew > 0) {
      results.add(FaraidShare(label: h.paternalNephew > 1 ? '${h.paternalNephew} Paternal Nephews (combined)' : 'Paternal Nephew', fraction: remainder, note: 'Residuary (Asaba) — closer heirs absent, inherits as paternal brother\'s son(s)'));
      residueClaimed = true;
    } else if (h.fullUncle > 0) {
      results.add(FaraidShare(label: h.fullUncle > 1 ? '${h.fullUncle} Full Paternal Uncles (combined)' : 'Full Paternal Uncle', fraction: remainder, note: 'Residuary (Asaba) — closer heirs absent, inherits as father\'s full brother'));
      residueClaimed = true;
    } else if (h.paternalUncle > 0) {
      results.add(FaraidShare(label: h.paternalUncle > 1 ? '${h.paternalUncle} Paternal Uncles (combined)' : 'Paternal Paternal Uncle', fraction: remainder, note: 'Residuary (Asaba) — closer heirs absent, inherits as father\'s paternal brother'));
      residueClaimed = true;
    } else if (h.fullCousin > 0) {
      results.add(FaraidShare(label: h.fullCousin > 1 ? '${h.fullCousin} Full Cousins (combined)' : 'Full Cousin', fraction: remainder, note: 'Residuary (Asaba) — closer heirs absent, inherits as full uncle\'s son(s)'));
      residueClaimed = true;
    } else if (h.paternalCousin > 0) {
      results.add(FaraidShare(label: h.paternalCousin > 1 ? '${h.paternalCousin} Paternal Cousins (combined)' : 'Paternal Cousin', fraction: remainder, note: 'Residuary (Asaba) — closer heirs absent, inherits as paternal uncle\'s son(s)'));
      residueClaimed = true;
    }

    if (residueClaimed) {
      _markExcludedIfPresentButUnclaimed(results, h);
    }

    // ---- 8. AWL (proportional reduction if Fard shares exceed the whole estate) ----
    final double totalFard = results.where((r) => !r.excluded).fold(0.0, (sum, r) => sum + r.fraction);
    if (totalFard > 1.0001) {
      final double scale = 1.0 / totalFard;
      for (int i = 0; i < results.length; i++) {
        if (!results[i].excluded) {
          results[i] = FaraidShare(
            label: results[i].label,
            fraction: results[i].fraction * scale,
            note: '${results[i].note} (adjusted under Awl — shares proportionally reduced as total exceeded the estate)',
          );
        }
      }
    } else if (!residueClaimed && totalFard < 0.9999 && totalFard > 0) {
      // ---- 9. RADD (return of unclaimed residue to Fard heirs, excluding spouse) ----
      final double leftover = 1.0 - totalFard;
      final bool onlySpouseRemains = results.where((r) => !r.excluded).every((r) => r.label.contains('Wife') || r.label == 'Husband');
      if (onlySpouseRemains && results.any((r) => !r.excluded)) {
        final int count = results.where((r) => !r.excluded).length;
        for (int i = 0; i < results.length; i++) {
          if (!results[i].excluded) {
            final double share = leftover / count;
            results[i] = FaraidShare(label: results[i].label, fraction: results[i].fraction + share, note: '${results[i].note} (Radd — sole heir receives full remainder)');
          }
        }
      } else {
        final double nonSpouseFard = results.where((r) => !r.excluded && !r.label.contains('Wife') && r.label != 'Husband').fold(0.0, (sum, r) => sum + r.fraction);
        if (nonSpouseFard > 0) {
          for (int i = 0; i < results.length; i++) {
            final r = results[i];
            if (!r.excluded && !r.label.contains('Wife') && r.label != 'Husband') {
              final double addOn = leftover * (r.fraction / nonSpouseFard);
              results[i] = FaraidShare(label: r.label, fraction: r.fraction + addOn, note: '${r.note} (Radd — receives a proportional share of the unclaimed residue)');
            }
          }
        }
      }
    }

    return results;
  }

  static void _markExcludedIfPresentButUnclaimed(List<FaraidShare> results, HeirCounts h) {
    void addExcludedIfMissing(String label, int count, String reason) {
      if (count > 0 && !results.any((r) => r.label.contains(label))) {
        results.add(FaraidShare(label: label, fraction: 0, note: reason, excluded: true));
      }
    }

    final claimedLabels = results.where((r) => !r.excluded).map((r) => r.label).join('|');
    final bool higherAsabaClaimed = claimedLabels.contains('Son') ||
        claimedLabels.contains('Grandson') ||
        claimedLabels.contains('Father') ||
        claimedLabels.contains('Grandfather') ||
        claimedLabels.contains('Full Brother') ||
        claimedLabels.contains('Full Sister');

    if (higherAsabaClaimed) {
      addExcludedIfMissing('Paternal Brother', h.paternalBrother, 'Excluded — a closer Asaba (residuary) heir already claimed the estate.');
      addExcludedIfMissing('Paternal Sister', h.paternalSister, 'Excluded — a closer Asaba (residuary) heir already claimed the estate.');
      addExcludedIfMissing('Full Nephew', h.fullNephew, 'Excluded — a closer Asaba (residuary) heir already claimed the estate.');
      addExcludedIfMissing('Paternal Nephew', h.paternalNephew, 'Excluded — a closer Asaba (residuary) heir already claimed the estate.');
      addExcludedIfMissing('Full Paternal Uncle', h.fullUncle, 'Excluded — a closer Asaba (residuary) heir already claimed the estate.');
      addExcludedIfMissing('Paternal Paternal Uncle', h.paternalUncle, 'Excluded — a closer Asaba (residuary) heir already claimed the estate.');
      addExcludedIfMissing('Full Cousin', h.fullCousin, 'Excluded — a closer Asaba (residuary) heir already claimed the estate.');
      addExcludedIfMissing('Paternal Cousin', h.paternalCousin, 'Excluded — a closer Asaba (residuary) heir already claimed the estate.');
    }
    if (claimedLabels.contains('Nephew')) {
      addExcludedIfMissing('Full Paternal Uncle', h.fullUncle, 'Excluded — a nephew already claimed the estate as a closer Asaba heir.');
      addExcludedIfMissing('Paternal Paternal Uncle', h.paternalUncle, 'Excluded — a nephew already claimed the estate as a closer Asaba heir.');
      addExcludedIfMissing('Full Cousin', h.fullCousin, 'Excluded — a nephew already claimed the estate as a closer Asaba heir.');
      addExcludedIfMissing('Paternal Cousin', h.paternalCousin, 'Excluded — a nephew already claimed the estate as a closer Asaba heir.');
    }
    if (claimedLabels.contains('Uncle')) {
      addExcludedIfMissing('Full Cousin', h.fullCousin, 'Excluded — an uncle already claimed the estate as a closer Asaba heir.');
      addExcludedIfMissing('Paternal Cousin', h.paternalCousin, 'Excluded — an uncle already claimed the estate as a closer Asaba heir.');
    }
  }
}

// ============================================================
// CALCULATE BY SHARE SCREEN
// ============================================================

class _HeirField {
  final String key;
  final String label;
  final bool isBoolean; // true = existence toggle, false = quantity counter
  const _HeirField({required this.key, required this.label, this.isBoolean = false});
}

const List<_HeirField> _heirFields = [
  _HeirField(key: 'son', label: 'Son'),
  _HeirField(key: 'daughter', label: 'Daughter'),
  _HeirField(key: 'grandson', label: 'Paternal Grandson'),
  _HeirField(key: 'granddaughter', label: 'Paternal Granddaughter'),
  _HeirField(key: 'father', label: 'Father', isBoolean: true),
  _HeirField(key: 'mother', label: 'Mother', isBoolean: true),
  _HeirField(key: 'paternalGrandfather', label: 'Paternal Grandfather', isBoolean: true),
  _HeirField(key: 'paternalGrandmother', label: 'Paternal Grandmother', isBoolean: true),
  _HeirField(key: 'maternalGrandmother', label: 'Maternal Grandmother', isBoolean: true),
  _HeirField(key: 'fullBrother', label: 'Full Brother'),
  _HeirField(key: 'fullSister', label: 'Full Sister'),
  _HeirField(key: 'paternalBrother', label: 'Paternal Brother'),
  _HeirField(key: 'paternalSister', label: 'Paternal Sister'),
  _HeirField(key: 'maternalSibling', label: 'Maternal Sibling'),
  _HeirField(key: 'fullNephew', label: 'Full Nephew'),
  _HeirField(key: 'paternalNephew', label: 'Paternal Nephew'),
  _HeirField(key: 'fullUncle', label: 'Full Paternal Uncle'),
  _HeirField(key: 'paternalUncle', label: 'Paternal Paternal Uncle'),
  _HeirField(key: 'fullCousin', label: 'Full Cousin'),
  _HeirField(key: 'paternalCousin', label: 'Paternal Cousin'),
];

class CalculateByShareScreen extends StatefulWidget {
  const CalculateByShareScreen({super.key});

  @override
  State<CalculateByShareScreen> createState() => _CalculateByShareScreenState();
}

class _CalculateByShareScreenState extends State<CalculateByShareScreen> {
  final HeirCounts _heirs = HeirCounts();
  List<FaraidShare>? _results;

  int _getCount(String key) {
    switch (key) {
      case 'son': return _heirs.son;
      case 'daughter': return _heirs.daughter;
      case 'grandson': return _heirs.grandson;
      case 'granddaughter': return _heirs.granddaughter;
      case 'fullBrother': return _heirs.fullBrother;
      case 'fullSister': return _heirs.fullSister;
      case 'paternalBrother': return _heirs.paternalBrother;
      case 'paternalSister': return _heirs.paternalSister;
      case 'maternalSibling': return _heirs.maternalSibling;
      case 'fullNephew': return _heirs.fullNephew;
      case 'paternalNephew': return _heirs.paternalNephew;
      case 'fullUncle': return _heirs.fullUncle;
      case 'paternalUncle': return _heirs.paternalUncle;
      case 'fullCousin': return _heirs.fullCousin;
      case 'paternalCousin': return _heirs.paternalCousin;
      default: return 0;
    }
  }

  void _setCount(String key, int value) {
    setState(() {
      switch (key) {
        case 'son': _heirs.son = value; break;
        case 'daughter': _heirs.daughter = value; break;
        case 'grandson': _heirs.grandson = value; break;
        case 'granddaughter': _heirs.granddaughter = value; break;
        case 'fullBrother': _heirs.fullBrother = value; break;
        case 'fullSister': _heirs.fullSister = value; break;
        case 'paternalBrother': _heirs.paternalBrother = value; break;
        case 'paternalSister': _heirs.paternalSister = value; break;
        case 'maternalSibling': _heirs.maternalSibling = value; break;
        case 'fullNephew': _heirs.fullNephew = value; break;
        case 'paternalNephew': _heirs.paternalNephew = value; break;
        case 'fullUncle': _heirs.fullUncle = value; break;
        case 'paternalUncle': _heirs.paternalUncle = value; break;
        case 'fullCousin': _heirs.fullCousin = value; break;
        case 'paternalCousin': _heirs.paternalCousin = value; break;
      }
      _results = null;
    });
  }

  bool _getBool(String key) {
    switch (key) {
      case 'father': return _heirs.father;
      case 'mother': return _heirs.mother;
      case 'paternalGrandfather': return _heirs.paternalGrandfather;
      case 'paternalGrandmother': return _heirs.paternalGrandmother;
      case 'maternalGrandmother': return _heirs.maternalGrandmother;
      default: return false;
    }
  }

  void _setBool(String key, bool value) {
    setState(() {
      switch (key) {
        case 'father': _heirs.father = value; break;
        case 'mother': _heirs.mother = value; break;
        case 'paternalGrandfather': _heirs.paternalGrandfather = value; break;
        case 'paternalGrandmother': _heirs.paternalGrandmother = value; break;
        case 'maternalGrandmother': _heirs.maternalGrandmother = value; break;
      }
      _results = null;
    });
  }

  void _calculate() {
    setState(() => _results = FaraidCalculator.calculate(_heirs));
  }

  void _resetAll() {
    setState(() {
      _heirs.spouseAlive = false;
      _heirs.wivesCount = 1;
      _heirs.son = 0;
      _heirs.daughter = 0;
      _heirs.grandson = 0;
      _heirs.granddaughter = 0;
      _heirs.father = false;
      _heirs.mother = false;
      _heirs.paternalGrandfather = false;
      _heirs.paternalGrandmother = false;
      _heirs.maternalGrandmother = false;
      _heirs.fullBrother = 0;
      _heirs.fullSister = 0;
      _heirs.paternalBrother = 0;
      _heirs.paternalSister = 0;
      _heirs.maternalSibling = 0;
      _heirs.fullNephew = 0;
      _heirs.paternalNephew = 0;
      _heirs.fullUncle = 0;
      _heirs.paternalUncle = 0;
      _heirs.fullCousin = 0;
      _heirs.paternalCousin = 0;
      _results = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: const Color(0xFFF7F7F5),
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.navyBlue, size: 20), onPressed: () => Navigator.pop(context)),
                        Expanded(child: Text('Calculate by Share', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navyBlue))),
                        TextButton(onPressed: _resetAll, child: Text('Reset', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.coralOrange))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        _buildGenderCard(),
                        const SizedBox(height: 14),
                        _buildSpouseCard(),
                        const SizedBox(height: 14),
                        _buildHeirListCard(),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _calculate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navyBlue,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('Calculate', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
                          ),
                        ),
                        if (_results != null) ...[
                          const SizedBox(height: 24),
                          _buildResultsSection(),
                        ],
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

  Widget _buildGenderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Deceased Person', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navyBlue)),
          const SizedBox(height: 10),
          Row(
            children: ['Male', 'Female'].map((g) {
              final selected = _heirs.deceasedGender == g;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _heirs.deceasedGender = g;
                    _heirs.spouseAlive = false;
                    _results = null;
                  }),
                  child: Container(
                    margin: EdgeInsets.only(right: g == 'Male' ? 8 : 0, left: g == 'Female' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: selected ? AppColors.navyBlue : const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(12)),
                    child: Text(g, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.navyBlue.withValues(alpha: 0.55))),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpouseCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_heirs.deceasedGender == 'Male' ? 'Wife/Wives alive' : 'Husband alive', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.navyBlue)),
              Switch(
                value: _heirs.spouseAlive,
                onChanged: (v) => setState(() { _heirs.spouseAlive = v; _results = null; }),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.midTeal,
                inactiveTrackColor: const Color(0xFFE0E0E0),
              ),
            ],
          ),
          if (_heirs.spouseAlive && _heirs.deceasedGender == 'Male') ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Number of wives', style: GoogleFonts.inter(fontSize: 13, color: AppColors.navyBlue)),
                _counterRow(_heirs.wivesCount, 1, 4, (v) => setState(() { _heirs.wivesCount = v; _results = null; })),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeirListCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Surviving Family Members', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navyBlue)),
          const SizedBox(height: 6),
          Text('Toggle who is alive, or set how many.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.navyBlue.withValues(alpha: 0.45))),
          const SizedBox(height: 12),
          ..._heirFields.map((field) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(field.label, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.navyBlue))),
                  field.isBoolean
                      ? Switch(
                          value: _getBool(field.key),
                          onChanged: (v) => _setBool(field.key, v),
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.midTeal,
                          inactiveTrackColor: const Color(0xFFE0E0E0),
                        )
                      : _counterRow(_getCount(field.key), 0, 10, (v) => _setCount(field.key, v)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _counterRow(int value, int min, int max, ValueChanged<int> onChanged) {
    return Row(
      children: [
        GestureDetector(
          onTap: value > min ? () => onChanged(value - 1) : null,
          child: Container(width: 26, height: 26, decoration: BoxDecoration(color: AppColors.navyBlue.withValues(alpha: 0.08), shape: BoxShape.circle), child: Icon(Icons.remove_rounded, size: 14, color: AppColors.navyBlue.withValues(alpha: value > min ? 1 : 0.3))),
        ),
        SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navyBlue))),
        GestureDetector(
          onTap: value < max ? () => onChanged(value + 1) : null,
          child: Container(width: 26, height: 26, decoration: BoxDecoration(color: AppColors.navyBlue.withValues(alpha: 0.08), shape: BoxShape.circle), child: Icon(Icons.add_rounded, size: 14, color: AppColors.navyBlue)),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    final eligible = _results!.where((r) => !r.excluded).toList();
    final excluded = _results!.where((r) => r.excluded).toList();

    if (_results!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(
          children: [
            Icon(Icons.family_restroom_rounded, size: 36, color: AppColors.navyBlue.withValues(alpha: 0.25)),
            const SizedBox(height: 10),
            Text('Select at least one surviving heir above to see results.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: AppColors.navyBlue.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resultsSectionLabel('Eligible Heirs'),
        const SizedBox(height: 10),
        ...eligible.map(_shareCard),
        if (excluded.isNotEmpty) ...[
          const SizedBox(height: 20),
          _resultsSectionLabel('Excluded Heirs'),
          const SizedBox(height: 10),
          ...excluded.map(_shareCard),
        ],
      ],
    );
  }

  Widget _resultsSectionLabel(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.navyBlue, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
      ],
    );
  }

  Widget _shareCard(FaraidShare share) {
    final fractionStr = share.excluded ? '—' : _fractionToReadable(share.fraction);
    final pctStr = share.excluded ? '0%' : '${(share.fraction * 100).toStringAsFixed(1)}%';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: share.excluded ? Border.all(color: AppColors.coralOrange.withValues(alpha: 0.2)) : null,
        boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: (share.excluded ? AppColors.coralOrange : AppColors.midTeal).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(fractionStr, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: share.excluded ? AppColors.coralOrange : AppColors.midTeal)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(share.label, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue))),
                    if (!share.excluded) Text(pctStr, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(share.note, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.navyBlue.withValues(alpha: 0.55), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fractionToReadable(double f) {
    if (f <= 0) return '0';
    const Map<String, double> common = {
      '1/2': 0.5, '1/3': 1 / 3, '1/4': 0.25, '1/6': 1 / 6,
      '1/8': 0.125, '2/3': 2 / 3, '1/12': 1 / 12, '1/24': 1 / 24,
      '1/16': 1 / 16, '1/32': 1 / 32,
    };
    for (final entry in common.entries) {
      if ((f - entry.value).abs() < 0.004) return entry.key;
    }
    return '${(f * 100).toStringAsFixed(1)}%';
  }
}

// ============================================================
// RULES OF INHERITANCE SCREEN (accordion reference)
// ============================================================

class _HeirRule {
  final String heir;
  final String reference;
  final String eligibility;
  final String share;
  final String changes;
  final String exclusion;
  final String explanation;
  const _HeirRule({
    required this.heir,
    required this.reference,
    required this.eligibility,
    required this.share,
    required this.changes,
    required this.exclusion,
    required this.explanation,
  });
}

const List<_HeirRule> _heirRules = [
  _HeirRule(
    heir: 'Husband',
    reference: 'Surah An-Nisa 4:12',
    eligibility: 'Surviving spouse of the deceased wife.',
    share: '1/2 if she left no children; 1/4 if she left children or grandchildren.',
    changes: 'Reduced from 1/2 to 1/4 when any descendant (child or grandchild) exists.',
    exclusion: 'Never fully excluded — always inherits as a Quranic (Fard) heir.',
    explanation: 'The husband\'s share is fixed and does not change based on other relatives except descendants.',
  ),
  _HeirRule(
    heir: 'Wife',
    reference: 'Surah An-Nisa 4:12',
    eligibility: 'Surviving spouse (or spouses) of the deceased husband.',
    share: '1/4 if he left no children; 1/8 if he left children or grandchildren. Split equally if multiple wives.',
    changes: 'Reduced from 1/4 to 1/8 when any descendant exists; divided among all surviving wives.',
    exclusion: 'Never fully excluded — always inherits as a Quranic (Fard) heir.',
    explanation: 'Multiple wives share the same total fraction (1/4 or 1/8) equally between them.',
  ),
  _HeirRule(
    heir: 'Son',
    reference: 'Surah An-Nisa 4:11',
    eligibility: 'Biological son of the deceased.',
    share: 'Residuary (Asaba) — takes the remainder after Fard heirs, double a daughter\'s portion.',
    changes: 'If both sons and daughters exist, the residue is split with sons getting twice what daughters get.',
    exclusion: 'Never excluded — a son always inherits.',
    explanation: 'Sons are never given a fixed fraction; they inherit whatever remains after fixed-share heirs are paid, which is often the largest portion of the estate.',
  ),
  _HeirRule(
    heir: 'Daughter',
    reference: 'Surah An-Nisa 4:11',
    eligibility: 'Biological daughter of the deceased.',
    share: '1/2 if she is the only child; 2/3 shared if two or more; becomes residuary (with sons) if any son is present.',
    changes: 'Her role changes from a fixed Fard share to a residuary share the moment a son also exists.',
    exclusion: 'Never fully excluded — always inherits, either as Fard or as residuary.',
    explanation: 'A single daughter never gets less than 1/2 of the estate on her own share, but that portion can be reduced if brothers are present sharing the residue.',
  ),
  _HeirRule(
    heir: 'Paternal Grandson (Son\'s Son)',
    reference: 'Surah An-Nisa 4:11 (by analogy to sons)',
    eligibility: 'Son of a deceased or absent son.',
    share: 'Stands in for an absent son — residuary (Asaba), double a granddaughter\'s portion.',
    changes: 'Only inherits when there is no surviving son of the deceased.',
    exclusion: 'Fully excluded if any son of the deceased is alive.',
    explanation: 'Grandsons through a son act exactly like sons when the son himself has passed away or is otherwise absent.',
  ),
  _HeirRule(
    heir: 'Paternal Granddaughter (Son\'s Daughter)',
    reference: 'Surah An-Nisa 4:11 (by analogy to daughters)',
    eligibility: 'Daughter of a deceased or absent son.',
    share: '1/6 (completing 2/3) if exactly one real daughter exists; standard daughter share (1/2 or 2/3) if no real daughter; residuary with a grandson if one is present.',
    changes: 'Her share depends heavily on how many real daughters and grandsons exist alongside her.',
    exclusion: 'Excluded entirely if there is a surviving son, or if two or more real daughters exist with no grandson present.',
    explanation: 'This is one of the more nuanced shares — her portion shifts depending on exactly which other descendants are present.',
  ),
  _HeirRule(
    heir: 'Father',
    reference: 'Surah An-Nisa 4:11',
    eligibility: 'Biological father of the deceased.',
    share: '1/6 if any descendant exists; also takes the residue as Asaba if no male descendant exists; pure residuary (no fixed portion) if there are no descendants at all.',
    changes: 'Gains an additional residuary share whenever there is no son or grandson.',
    exclusion: 'Never excluded — the father always inherits in some form.',
    explanation: 'The father can end up with much more than 1/6 when the deceased left only daughters, since he then also takes what remains as the closest male relative.',
  ),
  _HeirRule(
    heir: 'Mother',
    reference: 'Surah An-Nisa 4:11',
    eligibility: 'Biological mother of the deceased.',
    share: '1/3 if there are no children and fewer than two siblings; 1/6 if there are children, grandchildren, or two or more siblings.',
    changes: 'A special exception ("Umariyyatain") applies when only the spouse and both parents survive: the mother then gets 1/3 of what remains after the spouse\'s share, not 1/3 of the whole estate.',
    exclusion: 'Never excluded — the mother always inherits.',
    explanation: 'Even siblings who are themselves blocked from inheriting (for example, by the father\'s presence) still reduce the mother\'s share from 1/3 to 1/6 if there are two or more of them.',
  ),
  _HeirRule(
    heir: 'Paternal Grandfather',
    reference: 'Surah An-Nisa 4:11 (by analogy to the father)',
    eligibility: 'Father\'s father, when the father himself has passed away.',
    share: 'Same structure as the father: 1/6 with descendants, plus residue if no male descendant, or pure residue if no descendants at all.',
    changes: 'Steps into the father\'s exact role and share pattern.',
    exclusion: 'Fully excluded if the father is alive.',
    explanation: 'The paternal grandfather essentially substitutes for an absent father in every respect under Hanafi fiqh.',
  ),
  _HeirRule(
    heir: 'Paternal Grandmother',
    reference: 'Hadith-based ruling (not explicit in the Quran)',
    eligibility: 'Father\'s mother.',
    share: '1/6, shared equally with the maternal grandmother if both are present and eligible.',
    changes: 'None beyond sharing 1/6 with another eligible grandmother.',
    exclusion: 'Excluded if the mother or father is alive.',
    explanation: 'Grandmothers only inherit through a well-established hadith ruling, since the Quran does not mention their share directly.',
  ),
  _HeirRule(
    heir: 'Maternal Grandmother',
    reference: 'Hadith-based ruling (not explicit in the Quran)',
    eligibility: 'Mother\'s mother.',
    share: '1/6, shared equally with the paternal grandmother if both are present and eligible.',
    changes: 'None beyond sharing 1/6 with another eligible grandmother.',
    exclusion: 'Excluded if the mother is alive.',
    explanation: 'Unlike the paternal grandmother, the maternal grandmother is not affected by whether the father is alive — only by the mother.',
  ),
  _HeirRule(
    heir: 'Full Brother',
    reference: 'Surah An-Nisa 4:176',
    eligibility: 'Brother sharing both parents with the deceased.',
    share: 'Residuary (Asaba) — takes the remainder, double a full sister\'s portion if she is also present.',
    changes: 'Only inherits when there are no descendants and no father or paternal grandfather.',
    exclusion: 'Fully excluded by a son, grandson, father, or paternal grandfather.',
    explanation: 'Full brothers are the strongest sibling class and block paternal (consanguine) siblings from inheriting alongside them.',
  ),
  _HeirRule(
    heir: 'Full Sister',
    reference: 'Surah An-Nisa 4:176',
    eligibility: 'Sister sharing both parents with the deceased.',
    share: '1/2 alone, 2/3 shared if two or more, residuary with a full brother if present, or residuary alongside daughters if there is no full brother but daughters exist.',
    changes: 'Her role shifts between a fixed share and a residuary share depending on which other heirs are present.',
    exclusion: 'Fully excluded by a son, grandson, father, or paternal grandfather.',
    explanation: 'This is the classic case cited alongside the daughter\'s share — the surah addresses "Kalalah" (a person with no parent or child) directly for siblings.',
  ),
  _HeirRule(
    heir: 'Paternal Brother',
    reference: 'Surah An-Nisa 4:176 (by analogy)',
    eligibility: 'Brother sharing only the father with the deceased (consanguine).',
    share: 'Same structure as a full brother, but only inherits when full siblings are absent or do not exhaust the estate.',
    changes: 'Blocked or reduced whenever a full brother, or two or more full sisters, are present.',
    exclusion: 'Excluded by a full brother, by two or more full sisters (unless he can inherit as residuary), or by the same ascendant/descendant blockers as full siblings.',
    explanation: 'Paternal siblings share the father but not the mother with the deceased, placing them one step below full siblings in priority.',
  ),
  _HeirRule(
    heir: 'Paternal Sister',
    reference: 'Surah An-Nisa 4:176 (by analogy)',
    eligibility: 'Sister sharing only the father with the deceased (consanguine).',
    share: '1/6 if exactly one full sister exists (completing 2/3); standard sister share if no full sister; residuary with a paternal brother if present.',
    changes: 'Her exact share depends on the mix of full siblings and paternal brothers present.',
    exclusion: 'Excluded by a full brother, by two or more full sisters with no paternal brother present, or by the usual ascendant/descendant blockers.',
    explanation: 'This mirrors the granddaughter\'s relationship to the daughter — a "junior" version of the closer relative\'s share.',
  ),
  _HeirRule(
    heir: 'Maternal Sibling',
    reference: 'Surah An-Nisa 4:12',
    eligibility: 'Sibling sharing only the mother with the deceased (uterine).',
    share: '1/6 if only one; 1/3 shared equally (regardless of gender) if two or more.',
    changes: 'Unlike full/paternal siblings, maternal siblings never become residuary and always split equally between brothers and sisters.',
    exclusion: 'Excluded by any descendant (son, daughter, grandchild) or by the father or paternal grandfather.',
    explanation: 'The Quran addresses maternal siblings in a separate verse from full/paternal siblings, giving them a simpler, purely fixed share.',
  ),
  _HeirRule(
    heir: 'Full Nephew',
    reference: 'Standard Hanafi Asaba priority order',
    eligibility: 'Son of a full brother.',
    share: 'Residuary (Asaba) — takes the full remainder if he is the closest eligible heir.',
    changes: 'None — either fully inherits the residue or is fully excluded.',
    exclusion: 'Excluded by any descendant, father, paternal grandfather, full brother, or paternal brother.',
    explanation: 'Nephews only inherit as residuary heirs and never receive a fixed Quranic share.',
  ),
  _HeirRule(
    heir: 'Paternal Nephew',
    reference: 'Standard Hanafi Asaba priority order',
    eligibility: 'Son of a paternal (consanguine) brother.',
    share: 'Residuary (Asaba) — takes the full remainder if he is the closest eligible heir.',
    changes: 'None — either fully inherits the residue or is fully excluded.',
    exclusion: 'Excluded by everything that excludes a full nephew, plus by a full nephew himself.',
    explanation: 'One step below the full nephew in the Asaba priority chain.',
  ),
  _HeirRule(
    heir: 'Full Paternal Uncle',
    reference: 'Standard Hanafi Asaba priority order',
    eligibility: 'Father\'s full brother.',
    share: 'Residuary (Asaba) — takes the full remainder if he is the closest eligible heir.',
    changes: 'None — either fully inherits the residue or is fully excluded.',
    exclusion: 'Excluded by any closer heir, including nephews.',
    explanation: 'Uncles only enter the picture when no closer relatives (down to nephews) survive.',
  ),
  _HeirRule(
    heir: 'Paternal Paternal Uncle',
    reference: 'Standard Hanafi Asaba priority order',
    eligibility: 'Father\'s paternal (consanguine) brother.',
    share: 'Residuary (Asaba) — takes the full remainder if he is the closest eligible heir.',
    changes: 'None — either fully inherits the residue or is fully excluded.',
    exclusion: 'Excluded by a full paternal uncle and everything that excludes him.',
    explanation: 'One step below the full paternal uncle in the priority chain.',
  ),
  _HeirRule(
    heir: 'Full Cousin',
    reference: 'Standard Hanafi Asaba priority order',
    eligibility: 'Son of a full paternal uncle.',
    share: 'Residuary (Asaba) — takes the full remainder if he is the closest eligible heir.',
    changes: 'None — either fully inherits the residue or is fully excluded.',
    exclusion: 'Excluded by any closer heir in the chain, including uncles.',
    explanation: 'One of the most distant relatives who can still inherit under Hanafi fiqh, only relevant when no closer relative survives at all.',
  ),
  _HeirRule(
    heir: 'Paternal Cousin',
    reference: 'Standard Hanafi Asaba priority order',
    eligibility: 'Son of a paternal (consanguine) uncle.',
    share: 'Residuary (Asaba) — takes the full remainder if he is the closest eligible heir.',
    changes: 'None — either fully inherits the residue or is fully excluded.',
    exclusion: 'Excluded by a full cousin and everything that excludes him.',
    explanation: 'The final and most distant class in the standard Hanafi Asaba priority chain covered by this guide.',
  ),
];

class InheritanceRulesScreen extends StatefulWidget {
  const InheritanceRulesScreen({super.key});

  @override
  State<InheritanceRulesScreen> createState() => _InheritanceRulesScreenState();
}

class _InheritanceRulesScreenState extends State<InheritanceRulesScreen> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: const Color(0xFFF7F7F5),
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.navyBlue, size: 20), onPressed: () => Navigator.pop(context)),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.midTeal, borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rules of Inheritance', style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                              Text('Tap a heir to see the full rules', style: GoogleFonts.inter(fontSize: 11, color: AppColors.navyBlue.withValues(alpha: 0.55))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _heirRules.length,
                      itemBuilder: (context, index) {
                        final rule = _heirRules[index];
                        final expanded = _expandedIndex == index;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => setState(() => _expandedIndex = expanded ? null : index),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(rule.heir, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                                            const SizedBox(height: 3),
                                            Text(rule.reference, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.midTeal, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      AnimatedRotation(
                                        turns: expanded ? 0.5 : 0,
                                        duration: const Duration(milliseconds: 200),
                                        child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.navyBlue.withValues(alpha: 0.5)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedCrossFade(
                                duration: const Duration(milliseconds: 200),
                                crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                firstChild: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),
                                      _ruleRow('Eligibility', rule.eligibility, Icons.check_circle_outline_rounded, AppColors.midTeal),
                                      _ruleRow('Prescribed Share', rule.share, Icons.pie_chart_outline_rounded, AppColors.navyBlue),
                                      _ruleRow('When It Changes', rule.changes, Icons.swap_horiz_rounded, AppColors.coralOrange),
                                      _ruleRow('When Excluded', rule.exclusion, Icons.block_rounded, Colors.redAccent),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: AppColors.navyBlue.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(12)),
                                        child: Text(rule.explanation, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.navyBlue.withValues(alpha: 0.7), height: 1.5)),
                                      ),
                                    ],
                                  ),
                                ),
                                secondChild: const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        );
                      },
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

  Widget _ruleRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.navyBlue.withValues(alpha: 0.65), height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}