import 'package:intl/intl.dart' hide TextDirection;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/auth_header.dart'; // AppColors
import 'hajj_ritual_detail_screen.dart';

class HajjSeasonInfo {
  final int year;
  final String hijriYear;
  final DateTime coreStartDate; // 8th Dhul Hijjah
  final DateTime coreEndDate;   // 13th Dhul Hijjah
  final DateTime seasonEarliestFlight;
  final DateTime seasonLatestReturn;

  const HajjSeasonInfo({
    required this.year,
    required this.hijriYear,
    required this.coreStartDate,
    required this.coreEndDate,
    required this.seasonEarliestFlight,
    required this.seasonLatestReturn,
  });
}

final List<HajjSeasonInfo> _hajjSeasons = [
  HajjSeasonInfo(
    year: 2024,
    hijriYear: '1445 AH',
    coreStartDate: DateTime(2024, 6, 14),
    coreEndDate: DateTime(2024, 6, 19),
    seasonEarliestFlight: DateTime(2024, 5, 9),
    seasonLatestReturn: DateTime(2024, 7, 7),
  ),
  HajjSeasonInfo(
    year: 2025,
    hijriYear: '1446 AH',
    coreStartDate: DateTime(2025, 6, 4),
    coreEndDate: DateTime(2025, 6, 9),
    seasonEarliestFlight: DateTime(2025, 4, 29),
    seasonLatestReturn: DateTime(2025, 6, 25),
  ),
  HajjSeasonInfo(
    year: 2026,
    hijriYear: '1447 AH',
    coreStartDate: DateTime(2026, 5, 24),
    coreEndDate: DateTime(2026, 5, 29),
    seasonEarliestFlight: DateTime(2026, 4, 18),
    seasonLatestReturn: DateTime(2026, 6, 15),
  ),
  HajjSeasonInfo(
    year: 2027,
    hijriYear: '1448 AH',
    coreStartDate: DateTime(2027, 5, 13),
    coreEndDate: DateTime(2027, 5, 18),
    seasonEarliestFlight: DateTime(2027, 4, 7),
    seasonLatestReturn: DateTime(2027, 6, 4),
  ),
  HajjSeasonInfo(
    year: 2028,
    hijriYear: '1449 AH',
    coreStartDate: DateTime(2028, 5, 2),
    coreEndDate: DateTime(2028, 5, 7),
    seasonEarliestFlight: DateTime(2028, 3, 27),
    seasonLatestReturn: DateTime(2028, 5, 24),
  ),
  HajjSeasonInfo(
    year: 2029,
    hijriYear: '1450 AH',
    coreStartDate: DateTime(2029, 4, 21),
    coreEndDate: DateTime(2029, 4, 26),
    seasonEarliestFlight: DateTime(2029, 3, 16),
    seasonLatestReturn: DateTime(2029, 5, 13),
  ),
];

class HajjMistake {
  final String id;
  final String title;
  final String category; // 'Ihram', 'Tawaf & Sa\'i', 'Arafat & Mina', 'Rami & Qurbani', 'General'
  final String severity; // 'Tark al-Wajib (Dam)', 'Ihram Restriction', 'Condition of Tawaf', etc.
  final String mistakeDesc;
  final String remedy;
  final String kaffarahType;
  final String arabicAyah;
  final String englishAyah;
  final String quranRef;
  final String arabicHadith;
  final String englishHadith;
  final String hadithRef;
  final String fiqhExplanation;

  const HajjMistake({
    required this.id,
    required this.title,
    required this.category,
    required this.severity,
    required this.mistakeDesc,
    required this.remedy,
    required this.kaffarahType,
    required this.arabicAyah,
    required this.englishAyah,
    required this.quranRef,
    required this.arabicHadith,
    required this.englishHadith,
    required this.hadithRef,
    required this.fiqhExplanation,
  });
}

final List<HajjMistake> _hajjMistakes = [
  HajjMistake(
    id: 'm1',
    title: 'Passing the Miqat without Ihram',
    category: 'Ihram',
    severity: 'Tark al-Wajib (Dam)',
    mistakeDesc: 'Crossing the designated Miqat boundary (by air, land, or sea) without wearing the Ihram sheets and making the Niyyah (intention) & Talbiyah for Hajj or Umrah.',
    remedy: 'If possible, the pilgrim MUST return to the Miqat before starting any rites. If unable to return, a Dam (slaughtering 1 sheep in Makkah for the poor) is obligatory.',
    kaffarahType: 'Dam (Slaughtering 1 Sheep in Haram)',
    arabicAyah: 'وَأَتِمُّوا الْحَجَّ وَالْعُمْرَةَ لِلَّهِ',
    englishAyah: 'And complete the Hajj and Umrah for Allah...',
    quranRef: 'Quran - Surah Al-Baqarah (2:196)',
    arabicHadith: 'مَنْ نَسِيَ مِنْ نُسُكِهِ شَيْئًا أَوْ تَرَكَهُ فَلْيُهْرِقْ دَمًا',
    englishHadith: 'Whoever forgets a ritual or omits it, let him slaughter a sacrifice in Makkah.',
    hadithRef: 'Al-Muwatta (832), Sunan al-Bayhaqi (5/153)',
    fiqhExplanation: 'Assuming Ihram at or before the Miqat is an established Wajib. Passing it intentionally without Ihram requires Istighfar and either returning to the Miqat or offering a Dam in the Haram boundary.',
  ),
  HajjMistake(
    id: 'm2',
    title: 'Using Perfume or Scented Products in Ihram',
    category: 'Ihram',
    severity: 'Ihram Restriction',
    mistakeDesc: 'Applying perfume, attar, scented soap, shampoo, or scented body wipes to the body or Ihram cloth after having made the Niyyah.',
    remedy: 'Wash it off immediately with plain water. If done intentionally with knowledge, one must pay the Fidyah of Choice. If done out of forgetfulness, wash it off and make Istighfar with no penalty.',
    kaffarahType: 'Fidyah (Choose 1: Fast 3 Days, Feed 6 Poor, OR 1 Sheep)',
    arabicAyah: 'فَفِدْيَةٌ مِّن صِيَامٍ أَوْ صَدَقَةٍ أَوْ نُسُكٍ',
    englishAyah: '...a ransom of fasting or charity or sacrifice...',
    quranRef: 'Quran - Surah Al-Baqarah (2:196)',
    arabicHadith: 'صُمْ ثَلاَثَةَ أَيَّامٍ، أَوْ أَطْعِمْ سِتَّةَ مَسَاكِينَ، أَوْ انْسُكْ بِشَاةٍ',
    englishHadith: 'Fast three days, or feed six poor persons (half Sa\' each), or sacrifice a sheep.',
    hadithRef: 'Sahih al-Bukhari (1814), Sahih Muslim (1201)',
    fiqhExplanation: 'The scent must be washed away as soon as remembered. Unscented toiletries should be prepared beforehand.',
  ),
  HajjMistake(
    id: 'm3',
    title: 'Cutting Hair or Clipping Nails in Ihram',
    category: 'Ihram',
    severity: 'Ihram Restriction',
    mistakeDesc: 'Trimming finger or toe nails, or cutting/plucking hair from the head, beard, or body prior to the official Halq/Taqsir ritual.',
    remedy: 'Pay the Fidyah of Choice: Fasting 3 days, feeding 6 poor persons (half Sa\' of grain each in Haram), OR slaughtering a sheep for the poor of Makkah.',
    kaffarahType: 'Fidyah (Choose 1: Fast 3 Days, Feed 6 Poor, OR 1 Sheep)',
    arabicAyah: 'وَلَا تَحْلِقُوا رُءُوسَكُمْ حَتَّىٰ يَبْلُغَ الْهَدْيُ مَحِلَّهُ',
    englishAyah: 'And do not shave your heads until the sacrificial animal has reached its place of slaughter.',
    quranRef: 'Quran - Surah Al-Baqarah (2:196)',
    arabicHadith: 'صُمْ ثَلاَثَةَ أَيَّامٍ، أَوْ أَطْعِمْ سِتَّةَ مَسَاكِينَ، أَوْ انْسُكْ بِشَاةٍ',
    englishHadith: 'Fast three days, or feed six poor persons, or sacrifice a sheep.',
    hadithRef: 'Sahih al-Bukhari (1814), Sahih Muslim (1201)',
    fiqhExplanation: 'If only 1 or 2 hairs fell accidentally while making wudu or scratching, there is no penalty by consensus, but intentional cutting incurs Fidyah.',
  ),
  HajjMistake(
    id: 'm4',
    title: 'Covering Head or Wearing Stitched Clothes (Men)',
    category: 'Ihram',
    severity: 'Ihram Restriction (Men)',
    mistakeDesc: 'Men wearing tailored garments (shirts, pants, underwear) or covering the head with caps, turbans, or attached hoods while in Ihram.',
    remedy: 'Remove the garment immediately. If worn for an entire day/night knowingly, Fidyah of Choice is required. Using an unattached umbrella or sitting under a tent roof is 100% permissible.',
    kaffarahType: 'Fidyah (Choose 1: Fast 3 Days, Feed 6 Poor, OR 1 Sheep)',
    arabicAyah: 'ثُمَّ لْيَقْضُوا تَفَثَهُمْ وَلْيُوفُوا نُذُورَهُمْ وَلْيَطَّوَّفُوا بِالْبَيْتِ الْعَتِيقِ',
    englishAyah: 'Then let them end their untidiness and fulfill their vows and circumambulate the Ancient House.',
    quranRef: 'Quran - Surah Al-Hajj (22:29)',
    arabicHadith: 'لاَ يَلْبَسُ الْمُحْرِمُ الْقَمِيصَ وَلاَ الْعِمَامَةَ وَلاَ السَّرَاوِيلَ وَلاَ الْبُرْنُسَ',
    englishHadith: 'A person in Ihram must not wear shirts, turbans, trousers, hooded cloaks, or leather socks...',
    hadithRef: 'Sahih al-Bukhari (1542), Sahih Muslim (1177)',
    fiqhExplanation: 'Holding an umbrella over one\'s head or resting under a shelter does not count as covering the head because it is not fixed to the head.',
  ),
  HajjMistake(
    id: 'm5',
    title: 'Performing Tawaf without Wudu / Taharah',
    category: 'Tawaf & Sa\'i',
    severity: 'Condition of Tawaf',
    mistakeDesc: 'Performing Tawaf around the Kaaba while in a state of minor impurity (without Wudu) or major ritual impurity (Janabah/menses).',
    remedy: 'Tawaf requires ritual purity. If wudu breaks mid-Tawaf, exit to make wudu and resume. If an obligatory Tawaf (Ifadah/Umrah) was performed without wudu, it MUST be repeated in purity.',
    kaffarahType: 'Repeat Tawaf in State of Purity (No Sacrifice)',
    arabicAyah: 'وَطَهِّرْ بَيْتِيَ لِلطَّائِفِينَ وَالْقَائِمِينَ وَالرُّكَّعِ السُّجُودِ',
    englishAyah: 'And purify My House for those who perform Tawaf and those who stand and those who bow in worship.',
    quranRef: 'Quran - Surah Al-Hajj (22:26)',
    arabicHadith: 'الطَّوَافُ حَوْلَ الْبَيْتِ مِثْلُ الصَّلاَةِ، إِلاَّ أَنَّكُمْ تَتَكَلَّمُونَ فِيهِ',
    englishHadith: 'Tawaf around the House is like prayer, except that speech is permitted during it.',
    hadithRef: 'Jami` at-Tirmidhi (960), Sunan an-Nasa\'i (2922)',
    fiqhExplanation: 'Unlike Sa\'i (which is valid without wudu though Sunnah with wudu), Tawaf is invalid without Taharah according to the majority of scholars.',
  ),
  HajjMistake(
    id: 'm6',
    title: 'Walking Inside the Hateem (Hijr Ismail) in Tawaf',
    category: 'Tawaf & Sa\'i',
    severity: 'Tawaf Incomplete',
    mistakeDesc: 'Passing through the interior of the semi-circular wall (Hateem / Hijr Ismail) instead of circling on the outside of it.',
    remedy: 'The Hateem is part of the Kaaba\'s interior. Circling inside it means you did not circle the full Kaaba. Any circuit that went inside the Hateem does NOT count and must be repeated outside.',
    kaffarahType: 'Repeat the Invalid Circuit Outside Hateem',
    arabicAyah: 'وَلْيَطَّوَّفُوا بِالْبَيْتِ الْعَتِيقِ',
    englishAyah: '...and let them circumambulate the Ancient House (Al-Bayt al-Ateeq).',
    quranRef: 'Quran - Surah Al-Hajj (22:29)',
    arabicHadith: 'صَلِّي فِي الْحِجْرِ إِذَا أَرَدْتِ دُخُولَ الْبَيْتِ، فَإِنَّمَا هُوَ قِطْعَةٌ مِنَ الْبَيْتِ',
    englishHadith: 'Pray in the Hateem if you wish to enter the Kaaba, for it is a part of the House.',
    hadithRef: 'Sahih al-Bukhari (1584), Sahih Muslim (1333)',
    fiqhExplanation: 'All 7 rounds must be performed completely outside the curved Hateem wall.',
  ),
  HajjMistake(
    id: 'm7',
    title: 'Starting Sa\'i at Marwah instead of Safa',
    category: 'Tawaf & Sa\'i',
    severity: 'Order Error',
    mistakeDesc: 'Starting the 7 laps of Sa\'i from the hill of Marwah instead of Safa, or counting round-trip (Safa to Safa) as 1 lap.',
    remedy: 'Sa\'i must begin at Safa and conclude at Marwah (Safa→Marwah = 1, Marwah→Safa = 2, ending on 7th at Marwah). If started at Marwah, that first lap is ignored; count 7 laps starting from Safa.',
    kaffarahType: 'Complete 7 Valid Laps Starting from Safa',
    arabicAyah: 'إِنَّ الصَّفَا وَالْمَرْوَةَ مِن شَعَائِرِ اللَّهِ',
    englishAyah: 'Indeed, as-Safa and al-Marwah are among the symbols of Allah...',
    quranRef: 'Quran - Surah Al-Baqarah (2:158)',
    arabicHadith: 'نَبْدَأُ بِمَا بَدَأَ اللَّهُ بِهِ',
    englishHadith: 'We begin with that which Allah began with (Safa).',
    hadithRef: 'Sahih Muslim (1218)',
    fiqhExplanation: 'Each single stretch between the two hills counts as one complete lap. The 7th lap will always naturally finish at Marwah.',
  ),
  HajjMistake(
    id: 'm8',
    title: 'Staying Outside Arafat Boundaries on 9th Dhul Hijjah',
    category: 'Arafat & Mina',
    severity: 'Rukn Omitted (Void)',
    mistakeDesc: 'Staying outside the official yellow boundary markers of Arafat (e.g. remaining in the valley of Namirah or outside tents) throughout the entire day & night of 9th.',
    remedy: 'Wuquf at Arafat is the core pillar of Hajj. One must be present inside the boundary for any duration between Dhuhr of 9th and Fajr of 10th. If completely missed, Hajj is void and must be repeated in a future year.',
    kaffarahType: 'Hajj is Void — Convert to Umrah & Repeat Next Year',
    arabicAyah: 'فَإِذَا أَفَضْتُم مِّنْ عَرَفَاتٍ فَاذْكُرُوا اللَّهَ عِندَ الْمَشْعَرِ الْحَرَامِ',
    englishAyah: 'Then when you depart from Arafat, remember Allah at the sacred monument (Muzdalifah)...',
    quranRef: 'Quran - Surah Al-Baqarah (2:198)',
    arabicHadith: 'الْحَجُّ عَرَفَةُ',
    englishHadith: 'Hajj is Arafah! Whoever arrives at Arafat before Fajr on the night of Muzdalifah has caught the Hajj.',
    hadithRef: 'Jami` at-Tirmidhi (889), Sunan Abi Dawud (1949)',
    fiqhExplanation: 'Large clear signs are posted: "Start of Arafat" and "End of Arafat". Ensure your tent or standing place is strictly within these borders.',
  ),
  HajjMistake(
    id: 'm9',
    title: 'Departing Arafat Before Sunset on 9th Dhul Hijjah',
    category: 'Arafat & Mina',
    severity: 'Tark al-Wajib (Dam)',
    mistakeDesc: 'Rushing and exiting the boundaries of Arafat towards Muzdalifah before the sun has completely set.',
    remedy: 'If you leave early, you MUST return to Arafat before sunset. If you do not return before sunset, you have omitted a Wajib and a Dam (sacrificing 1 sheep in Makkah) is obligatory.',
    kaffarahType: 'Dam (Slaughtering 1 Sheep in Haram)',
    arabicAyah: 'فَإِذَا أَفَضْتُم مِّنْ عَرَفَاتٍ فَاذْكُرُوا اللَّهَ عِندَ الْمَشْعَرِ الْحَرَامِ',
    englishAyah: 'Then when you depart from Arafat, remember Allah at the sacred monument...',
    quranRef: 'Quran - Surah Al-Baqarah (2:198)',
    arabicHadith: 'فَلَمْ يَزَلْ وَاقِفًا حَتَّى غَرَبَتِ الشَّمْسُ وَذَهَبَتِ الصُّفْرَةُ قَلِيلاً',
    englishHadith: 'The Prophet (ﷺ) remained standing at Arafat until the sun disc disappeared completely and the yellow dusk departed, then moved to Muzdalifah.',
    hadithRef: 'Sahih Muslim (1218)',
    fiqhExplanation: 'Combining part of the day and part of the night at Arafat is Wajib according to the vast majority of scholars.',
  ),
  HajjMistake(
    id: 'm10',
    title: 'Missing or Neglecting Rami al-Jamarat (Stoning)',
    category: 'Rami & Qurbani',
    severity: 'Tark al-Wajib (Dam)',
    mistakeDesc: 'Failing to stone the Jamarat pillars on 10th (Big Jamarah) or during the days of Tashreeq (11th, 12th, 13th) without appointing a valid proxy for illness/frailty.',
    remedy: 'If remembered during the days of Tashreeq, perform the missed stoning before sunset of the 13th. If the Tashreeq days passed completely, a Dam (sheep sacrifice in Haram) is required.',
    kaffarahType: 'Dam (Slaughtering 1 Sheep in Haram)',
    arabicAyah: 'وَاذْكُرُوا اللَّهَ فِي أَيَّامٍ مَّعْدُودَاتٍ',
    englishAyah: 'And remember Allah during [specific] numbered days...',
    quranRef: 'Quran - Surah Al-Baqarah (2:203)',
    arabicHadith: 'مَنْ نَسِيَ مِنْ نُسُكِهِ شَيْئًا أَوْ تَرَكَهُ فَلْيُهْرِقْ دَمًا',
    englishHadith: 'Whoever forgets a ritual or omits it must offer a sacrifice.',
    hadithRef: 'Al-Muwatta (832)',
    fiqhExplanation: 'Each pebble must hit the basin/pillar. If throwing 7 pebbles all at once in one throw, it only counts as 1 pebble; throw them one by one saying Allahu Akbar.',
  ),
  HajjMistake(
    id: 'm11',
    title: 'Shaving/Cutting only 2-3 Hairs for Halq/Taqsir',
    category: 'Rami & Qurbani',
    severity: 'Incomplete Tahallul',
    mistakeDesc: 'Snipping just two or three strands from the front and assuming one has exited Ihram, then wearing normal clothes and applying perfume.',
    remedy: 'Trim at least a fingertip (~1 inch) evenly from all parts of the hair, or shave the entire head (for men). If normal clothes were worn prematurely, trim properly now and make Istighfar.',
    kaffarahType: 'Properly Complete Halq/Taqsir + Istighfar',
    arabicAyah: 'مُحَلِّقِينَ رُءُوسَكُمْ وَمُقَصِّرِينَ لَا تَخَافُونَ',
    englishAyah: '...with shaved heads and shortened hair, not fearing...',
    quranRef: 'Quran - Surah Al-Fath (48:27)',
    arabicHadith: 'اللَّهُمَّ اغْفِرْ لِلْمُحَلِّقِينَ... وَلِلْمُقَصِّرِينَ',
    englishHadith: 'The Prophet (ﷺ) supplicated: "O Allah, forgive those who shave their heads!" They asked: "And those who shorten, O Messenger of Allah?" He repeated it three times, and on the fourth said: "And those who shorten."',
    hadithRef: 'Sahih al-Bukhari (1727), Sahih Muslim (1301)',
    fiqhExplanation: 'For women, gather the hair and cut the length of a fingertip from the bottom. For men, trimming must encompass hair across the entire head.',
  ),
  HajjMistake(
    id: 'm12',
    title: 'Departing Makkah without Tawaf al-Wida',
    category: 'Tawaf & Sa\'i',
    severity: 'Tark al-Wajib (Dam)',
    mistakeDesc: 'Non-resident pilgrims traveling out of Makkah back to their home country without performing the Farewell Tawaf (Tawaf al-Wida).',
    remedy: 'If still nearby, return to Makkah to perform it. If already departed far away, a Dam (sheep sacrifice in Haram) must be arranged. (Note: Menstruating women are excused from Tawaf al-Wida with no penalty).',
    kaffarahType: 'Dam (Sheep in Haram) — Excused for Menstruating Women',
    arabicAyah: 'وَلْيَطَّوَّفُوا بِالْبَيْتِ الْعَتِيقِ',
    englishAyah: '...and let them circumambulate the Ancient House.',
    quranRef: 'Quran - Surah Al-Hajj (22:29)',
    arabicHadith: 'أُمِرَ النَّاسُ أَنْ يَكُونَ آخِرُ عَهْدِهِمْ بِالْبَيْتِ، إِلاَّ أَنَّهُ خُفِّفَ عَنِ الْمَرْأَةِ الْحَائِضِ',
    englishHadith: 'The people were ordered to make the circumambulation of the Kaaba the last thing they do, but an exception was made for menstruating women.',
    hadithRef: 'Sahih al-Bukhari (1755), Sahih Muslim (1328)',
    fiqhExplanation: 'Tawaf al-Wida is the final farewell to the House of Allah. It has no Sa\'i attached to it and should be done just before departure.',
  ),
];

class CompletedPilgrimage {
  final String id;
  final String mode; // 'Hajj' or 'Umrah'
  final String hajjType; // 'Tamattu', 'Qiran', 'Ifrad' or '-'
  final DateTime completionDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final String note;
  final int completedRituals;
  final int totalRituals;

  CompletedPilgrimage({
    required this.id,
    required this.mode,
    required this.hajjType,
    required this.completionDate,
    this.startDate,
    this.endDate,
    this.note = '',
    required this.completedRituals,
    required this.totalRituals,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode,
    'hajjType': hajjType,
    'completionDate': completionDate.toIso8601String(),
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'note': note,
    'completedRituals': completedRituals,
    'totalRituals': totalRituals,
  };

  factory CompletedPilgrimage.fromJson(Map<String, dynamic> json) => CompletedPilgrimage(
    id: json['id'] as String? ?? UniqueKey().toString(),
    mode: json['mode'] as String? ?? 'Hajj',
    hajjType: json['hajjType'] as String? ?? 'Tamattu',
    completionDate: DateTime.tryParse(json['completionDate'] as String? ?? '') ?? DateTime.now(),
    startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'] as String) : null,
    endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'] as String) : null,
    note: json['note'] as String? ?? '',
    completedRituals: json['completedRituals'] as int? ?? 0,
    totalRituals: json['totalRituals'] as int? ?? 0,
  );
}

class HajjUmrahPlannerScreen extends StatefulWidget {
  const HajjUmrahPlannerScreen({super.key});

  @override
  State<HajjUmrahPlannerScreen> createState() => _HajjUmrahPlannerScreenState();
}

class _HajjUmrahPlannerScreenState extends State<HajjUmrahPlannerScreen>
    with TickerProviderStateMixin {
  int _tab = 0;
  static const _tabLabels = ['Rituals', 'Packing', 'Document', 'Duas', 'Mistakes', 'History'];
  static const _tabIcons = [
    Icons.auto_awesome_rounded,
    Icons.local_offer_rounded,
    Icons.folder_open_rounded,
    Icons.chat_bubble_rounded,
    Icons.warning_amber_rounded,
    Icons.history_edu_rounded,
  ];
  String _mode = 'Hajj'; // 'Hajj' or 'Umrah'
  String _hajjType = 'Tamattu'; // 'Tamattu', 'Qiran', or 'Ifrad'
  bool _isDarkMode = false;
  int _selectedHajjYear = 2026;
  DateTime? _tripStartDate;
  DateTime? _tripEndDate;
  List<CompletedPilgrimage> _history = [];
  String _mistakeCategoryFilter = 'All';
  String _mistakeSearchQuery = '';

  final Map<String, bool> _hajjRitualDone = {};
  final Map<String, bool> _umrahRitualDone = {};
  final Map<String, bool> _packingDone = {};
  final Map<String, bool> _documentsDone = {};

  // ===== ROAD-FILL ANIMATION CONTROLLERS =====
  final Map<String, AnimationController> _segmentControllers = {};
  final Map<String, Animation<double>> _segmentAnimations = {};

  // ===== RITUAL STEPS DATA =====
  final List<Map<String, String>> _hajjStepsTamattu = [
    {'id': 'ihram_u', 'title': 'Enter Ihram for Umrah', 'desc': 'Wear Ihram at the Miqat with the intention (Niyyah) for Umrah.'},
    {'id': 'tawaf_u', 'title': 'Tawaf of Umrah', 'desc': 'Circle the Kaaba 7 times, starting at the Black Stone.'},
    {'id': 'sai_u', 'title': 'Sa\'i of Umrah', 'desc': 'Walk between the hills of Safa and Marwah 7 times.'},
    {'id': 'halq_u', 'title': 'Halq / Taqsir (Umrah)', 'desc': 'Shave or trim the hair to complete Umrah and exit Ihram.'},
    {'id': 'ihram_h', 'title': 'Enter Ihram for Hajj', 'desc': 'Wear Ihram on the 8th of Dhul Hijjah from Makkah.'},
    {'id': 'mina1', 'title': 'Day of Tarwiyah (8th Dhul Hijjah)', 'desc': 'Travel to Mina, stay overnight, offer the 5 daily prayers.'},
    {'id': 'arafat', 'title': 'Day of Arafah (9th Dhul Hijjah)', 'desc': 'Stand at Arafat (Wuquf) from Dhuhr until Maghrib — the core of Hajj.'},
    {'id': 'muzdalifah', 'title': 'Muzdalifah', 'desc': 'Travel after sunset, collect pebbles for Rami, stay overnight.'},
    {'id': 'rami1', 'title': 'Rami al-Jamarat (10th)', 'desc': 'Stone the large Jamarat (Jamarat al-Aqabah) with 7 pebbles.'},
    {'id': 'qurbani', 'title': 'Qurbani (Sacrifice)', 'desc': 'Offer the sacrifice, then shave or trim the hair (Halq/Taqsir).'},
    {'id': 'tawaf_ifadah', 'title': 'Tawaf al-Ifadah', 'desc': 'Return to Makkah for the obligatory Tawaf.'},
    {'id': 'sai_h', 'title': 'Sa\'i of Hajj', 'desc': 'Walk between the hills of Safa and Marwah 7 times for Hajj.'},
    {'id': 'rami_days', 'title': 'Rami (11th–13th)', 'desc': 'Stone all three Jamarat each day while staying at Mina.'},
    {'id': 'tawaf_wida', 'title': 'Tawaf al-Wida', 'desc': 'Farewell Tawaf performed just before leaving Makkah.'},
  ];

  final List<Map<String, String>> _hajjStepsQiran = [
    {'id': 'ihram_qiran', 'title': 'Enter Ihram for Qiran', 'desc': 'Wear Ihram at the Miqat with the intention for both Hajj & Umrah.'},
    {'id': 'tawaf_qudum', 'title': 'Tawaf al-Qudum', 'desc': 'Arrival Tawaf around the Kaaba (7 rounds).'},
    {'id': 'sai_h', 'title': 'Sa\'i of Hajj & Umrah', 'desc': 'Walk between the hills of Safa and Marwah 7 times.'},
    {'id': 'mina1', 'title': 'Day of Tarwiyah (8th Dhul Hijjah)', 'desc': 'Travel to Mina, stay overnight, offer the 5 daily prayers.'},
    {'id': 'arafat', 'title': 'Day of Arafah (9th Dhul Hijjah)', 'desc': 'Stand at Arafat (Wuquf) from Dhuhr until Maghrib — the core of Hajj.'},
    {'id': 'muzdalifah', 'title': 'Muzdalifah', 'desc': 'Travel after sunset, collect pebbles for Rami, stay overnight.'},
    {'id': 'rami1', 'title': 'Rami al-Jamarat (10th)', 'desc': 'Stone the large Jamarat (Jamarat al-Aqabah) with 7 pebbles.'},
    {'id': 'qurbani', 'title': 'Qurbani (Sacrifice)', 'desc': 'Offer the sacrifice, then shave or trim the hair (Halq/Taqsir).'},
    {'id': 'tawaf_ifadah', 'title': 'Tawaf al-Ifadah', 'desc': 'Return to Makkah for the obligatory Hajj Tawaf.'},
    {'id': 'rami_days', 'title': 'Rami (11th–13th)', 'desc': 'Stone all three Jamarat each day while staying at Mina.'},
    {'id': 'tawaf_wida', 'title': 'Tawaf al-Wida', 'desc': 'Farewell Tawaf performed just before leaving Makkah.'},
  ];

  final List<Map<String, String>> _hajjStepsIfrad = [
    {'id': 'ihram_ifrad', 'title': 'Enter Ihram for Ifrad', 'desc': 'Wear Ihram at the Miqat with the intention for Hajj only.'},
    {'id': 'tawaf_qudum', 'title': 'Tawaf al-Qudum', 'desc': 'Arrival Tawaf around the Kaaba (7 rounds).'},
    {'id': 'sai_h', 'title': 'Sa\'i of Hajj', 'desc': 'Walk between the hills of Safa and Marwah 7 times.'},
    {'id': 'mina1', 'title': 'Day of Tarwiyah (8th Dhul Hijjah)', 'desc': 'Travel to Mina, stay overnight, offer the 5 daily prayers.'},
    {'id': 'arafat', 'title': 'Day of Arafah (9th Dhul Hijjah)', 'desc': 'Stand at Arafat (Wuquf) from Dhuhr until Maghrib — the core of Hajj.'},
    {'id': 'muzdalifah', 'title': 'Muzdalifah', 'desc': 'Travel after sunset, collect pebbles for Rami, stay overnight.'},
    {'id': 'rami1', 'title': 'Rami al-Jamarat (10th)', 'desc': 'Stone the large Jamarat (Jamarat al-Aqabah) with 7 pebbles.'},
    {'id': 'halq_ifrad', 'title': 'Halq / Taqsir', 'desc': 'Shave or trim the hair to exit Ihram (Qurbani is optional/not obligatory).'},
    {'id': 'tawaf_ifadah', 'title': 'Tawaf al-Ifadah', 'desc': 'Return to Makkah for the obligatory Hajj Tawaf.'},
    {'id': 'rami_days', 'title': 'Rami (11th–13th)', 'desc': 'Stone all three Jamarat each day while staying at Mina.'},
    {'id': 'tawaf_wida', 'title': 'Tawaf al-Wida', 'desc': 'Farewell Tawaf performed just before leaving Makkah.'},
  ];

  List<Map<String, String>> _getActiveSteps() {
    if (_mode == 'Hajj') {
      if (_hajjType == 'Tamattu') return _hajjStepsTamattu;
      if (_hajjType == 'Qiran') return _hajjStepsQiran;
      return _hajjStepsIfrad;
    } else {
      return _umrahSteps;
    }
  }

  final List<Map<String, String>> _umrahSteps = [
    {'id': 'ihram_u', 'title': 'Enter Ihram', 'desc': 'Wear Ihram at the Miqat with the intention (Niyyah) for Umrah.'},
    {'id': 'tawaf_u', 'title': 'Tawaf', 'desc': 'Circle the Kaaba 7 times, starting and ending at the Black Stone.'},
    {'id': 'sai_u', 'title': 'Sa\'i', 'desc': 'Walk between the hills of Safa and Marwah 7 times.'},
    {'id': 'halq_u', 'title': 'Halq / Taqsir', 'desc': 'Shave or trim the hair to complete Umrah.'},
  ];

  // ===== STEP ILLUSTRATIONS =====
  final Map<String, String> _hajjStepImages = {
    'ihram': 'assets/images/hajj_umrah/2.png',
    'ihram_u': 'assets/images/hajj_umrah/2.png',
    'tawaf_u': 'assets/images/hajj_umrah/1.png',
    'sai_u': 'assets/images/hajj_umrah/6.png',
    'halq_u': 'assets/images/hajj_umrah/7.png',
    'ihram_h': 'assets/images/hajj_umrah/2.png',
    'ihram_qiran': 'assets/images/hajj_umrah/2.png',
    'ihram_ifrad': 'assets/images/hajj_umrah/2.png',
    'tawaf_qudum': 'assets/images/hajj_umrah/1.png',
    'mina1': 'assets/images/hajj_umrah/6.png',
    'arafat': 'assets/images/hajj_umrah/8.png',
    'muzdalifah': 'assets/images/hajj_umrah/9.png',
    'rami1': 'assets/images/hajj_umrah/5.png',
    'qurbani': 'assets/images/hajj_umrah/10.png',
    'halq_ifrad': 'assets/images/hajj_umrah/7.png',
    'tawaf_ifadah': 'assets/images/hajj_umrah/4.png',
    'sai_h': 'assets/images/hajj_umrah/6.png',
    'rami_days': 'assets/images/hajj_umrah/11.png',
    'tawaf_wida': 'assets/images/hajj_umrah/1.png',
  };

  final Map<String, String> _umrahStepImages = {
    'ihram_u': 'assets/images/hajj_umrah/2.png',
    'tawaf_u': 'assets/images/hajj_umrah/1.png',
    'sai_u': 'assets/images/hajj_umrah/6.png',
    'halq_u': 'assets/images/hajj_umrah/7.png',
  };

  // ===== ELABORATE RITUAL DETAILS (Arabic & English with Quran & Hadith References) =====
  final Map<String, Map<String, dynamic>> _ritualDetails = {
    'ihram_h': {
      'titleEn': 'Enter Ihram for Hajj (Tamattu\')',
      'titleAr': 'الإحرام للحج (تمتع)',
      'day': '8th Dhul Hijjah - From Makkah residence',
      'dayAr': '٨ ذو الحجة - من مكان الإقامة بمكة',
      'overviewEn': 'For Hajj al-Tamattu\', pilgrims re-enter the state of Ihram on the 8th of Dhul Hijjah from their hotel or residence in Makkah. It involves physical purification, putting on the Ihram garments, making the intention for Hajj, and chanting the Talbiyah.',
      'overviewAr': 'بالنسبة لحج التمتع، يحرم الحاج بالحج ضحى يوم التروية (٨ ذو الحجة) من مكان إقامته في مكة المكرمة، حيث يغتسل ويتطيب ويلبس ملابس الإحرام وينوي الحج قائلاً: لَبَّيْكَ اللَّهُمَّ حَجًّا.',
      'overviewArTranslit': "Binnasbati lihajjit-tamattu', yuhrimul-haajju bil-hajji duha yawmit-tarwiyah (8 Dhul-Hijjah) min makani iqamatihī fī Makkatal-Mukarramah, haythu yagtasilu wa yatatayyabu wa yalbasu malabisal-ihram wa yanwil-hajja qa'ilan: Labbayk Allahumma Hajjah.",
      'overviewArMeaning': "Regarding Hajj al-Tamattu', the pilgrim enters the state of Ihram for Hajj during the forenoon of the Day of Tarwiyah (8th of Dhul Hijjah) from their place of residence in Makkah, where they perform Ghusl, apply perfume, wear the Ihram garments, and make the intention for Hajj, saying: Labbayk Allahumma Hajjah.",
      'actionDetails': [
        {
          'title': 'Perform Ghusl (ritual bath) at your residence in Makkah.',
          'details': 'Before entering Ihram, it is highly recommended (Sunnah) to perform Ghusl. This involves a full-body bath. Trim your nails, shave underarms/pubic hair, and take a complete bath. If Ghusl is not possible, perform Wudu instead.',
          'glossary': [
            {'term': 'Ghusl', 'meaning': 'The full-body ritual purification bath in Islam.'},
            {'term': 'Sunnah', 'meaning': 'The practices and traditions of Prophet Muhammad (ﷺ).'},
            {'term': 'Wudu', 'meaning': 'The ritual ablution performed before prayers.'}
          ]
        },
        {
          'title': 'Wear Ihram garments (for men) or modest dress (for women).',
          'details': 'Men wrap the Izar around the waist and drape the Rida over the shoulders. No underwear, socks, or head coverings are allowed. Women wear modest, loose-fitting clothing covering the entire body except the face and hands.',
          'glossary': [
            {'term': 'Ihram', 'meaning': 'The sacred state of consecration and the unstitched garments worn by pilgrims.'},
            {'term': 'Izar', 'meaning': 'The lower sheet of unstitched white cloth wrapped around the waist.'},
            {'term': 'Rida', 'meaning': 'The upper sheet of unstitched white cloth covering the shoulders.'}
          ]
        },
        {
          'title': 'Offer 2 Rakah prayer if possible, then make intention.',
          'details': 'Offer two units of prayer (Nafl) if not in a forbidden prayer time, then declare the intention: "Labbayk Allahumma Hajjah" (لَبَّيْكَ اللَّهُمَّ حَجًّا).',
          'glossary': [
            {'term': 'Rakah', 'meaning': 'A unit of Islamic prayer.'},
            {'term': 'Niyyah', 'meaning': 'The intention in the heart to perform an act of worship.'}
          ]
        },
        {
          'title': 'Begin reciting Talbiyah.',
          'details': 'Recite "Labbayk Allahumma Labbayk..." loudly for men, and quietly for women. This is chanted continuously until stoning the first Jamrah on the 10th of Dhul Hijjah.',
          'glossary': [
            {'term': 'Talbiyah', 'meaning': 'The standard prayer chanted by pilgrims during Hajj: "Labbayk Allahumma Labbayk..." (Here I am, O Allah, here I am...).'}
          ]
        }
      ],
      'quran': {
        'textAr': 'وَأَتِمُّوا الْحَجَّ وَالْعُمْرَةَ لِلَّهِ',
        'referenceAr': 'سورة البقرة - الآية ١٩٦',
        'textEn': 'And complete the Hajj and Umrah for Allah.',
        'translitEn': 'Wa atimmul-hajja wal-\'umrata lillah.',
        'referenceEn': 'Surah Al-Baqarah (2:196)',
        'explanationEn': 'Divine command to complete the rituals of Hajj and Umrah sincerely for the sake of Allah.',
        'explanationAr': 'الأمر بوجوب إكمال أعمال الحج والعمرة وإخلاصها لله تعالى.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ جَابِرٍ رَضِيَ اللَّهُ عَنْهُ: «أَمَرَنَا النَّبِيُّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ لَمَّا حَلَلْنَا أَنْ نُحْرِمَ إِذَا تَوَجَّهْنَا إِلَى مِنًى، فَأَهْلَلْنَا مِنَ الأَبْطَحِ»',
          'translitEn': 'An Jabir radiya-allahu anhu: "Amarana an-nabiyyu salla-allahu alayhi wa sallama lamma halalna an nuhri-ma idha tawajjahna ila Mina, fa ahlalna mina-l-Abtah."',
          'referenceEn': 'Sahih al-Bukhari & Sahih Muslim',
          'textEn': 'Jabir narrated: "The Prophet (ﷺ) commanded us to assume Ihram when we directed ourselves towards Mina; so we assumed Ihram from Al-Abtah (Makkah Residence)."',
          'explanationEn': 'This Hadith establishes that pilgrims performing Tamattu\'-type Hajj should enter Ihram for Hajj from their location of stay in Makkah on the 8th of Dhul Hijjah.',
          'sourceBook': 'Sahih al-Bukhari & Sahih Muslim',
          'sourceBookDesc': 'These are the two most authentic collections of Hadith in Sunni Islam, compiled by Imam Al-Bukhari and Imam Muslim.'
        },
        {
          'textAr': 'عَنِ ابْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ سُئِلَ: مَا يَلْبَسُ الْمُحْرِمُ؟ فَقَالَ: «لاَ يَلْبَسُ الْقُمُصَ وَلاَ الْعَمَائِمَ وَلاَ السَّرَاوِيلاَتِ وَلاَ الْبَرَانِسَ وَلاَ الْخِفَافَ...»',
          'translitEn': 'An ibni Umar radiya-allahu anhuma anna rasula-llahi salla-allahu alayhi wa sallama su\'ila: Ma yalbasu-l-muhrim? Faqala: La yalbasu-l-qumusa wa la-l-ama\'ima wa la-s-sarawilati wa la-l-baranisa wa la-l-khifafa...',
          'referenceEn': 'Sahih al-Bukhari 1542 & Sahih Muslim 1177',
          'textEn': 'Narrated Abdullah ibn Umar: A man asked the Prophet (ﷺ), "What should a pilgrim in Ihram wear?" The Prophet replied, "He should not wear shirts, turbans, trousers, hooded cloaks, or leather socks..."',
          'explanationEn': 'This Hadith lays out the essential dress code for men in Ihram to strip away worldly status and distinctions before Almighty Allah.',
          'sourceBook': 'Sahih al-Bukhari & Sahih Muslim',
          'sourceBookDesc': 'These are the two most authentic collections of Hadith in Sunni Islam, compiled by Imam Al-Bukhari and Imam Muslim.'
        }
      ],
      'duas': [
        {
          'title': 'Intention for Hajj (Tamattu\')',
          'arabic': 'لَبَّيْكَ اللَّهُمَّ حَجًّا',
          'translit': 'Labbayk Allahumma Hajjah',
          'meaningEn': 'O Allah, I answer Your call to perform Hajj.',
          'meaningAr': 'التلفظ بالنية للدخول في مناسك الحج.',
        },
        {
          'title': 'The Talbiyah',
          'arabic': 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لا شَرِيكَ لَكَ لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكُ، لا شَرِيكَ لَكَ',
          'translit': 'Labbayk Allahumma Labbayk, Labbayka la sharika laka labbayk, innal-hamda wan-ni’mata laka wal-mulk, la sharika lak.',
          'meaningEn': 'Here I am, O Allah, here I am. Here I am, You have no partner, here I am. Verily all praise, grace, and sovereignty belong to You. You have no partner.',
          'meaningAr': 'التلبية إعلاناً للتوحيد وإجابةً لنداء الله عز وجل.',
        }
      ]
    },

    'ihram_qiran': {
      'titleEn': 'Enter Ihram for Hajj Qiran',
      'titleAr': 'الإحرام لحج القران',
      'day': 'At Miqat - Before entering Haram boundaries',
      'dayAr': 'الميقات - قبل دخول حدود الحرم',
      'overviewEn': 'In Hajj al-Qiran, the pilgrim enters the state of Ihram at the Miqat with the intention of performing both Umrah and Hajj combined. The pilgrim remains in Ihram without shaving or cutting hair after Umrah, staying in Ihram until the 10th of Dhul Hijjah.',
      'overviewAr': 'حج القران هو أن يحرم الحاج بالعمرة والحج معاً من الميقات، أو يحرم بالعمرة ثم يدخل عليها الحج قبل الطواف. ويلتزم بمحظورات الإحرام ولا يتحلل منه بعد طواف القدوم وسعيه بل يبقى محرماً حتى يوم النحر.',
      'overviewArTranslit': "Hajjul-qirani huwa an yuhrimal-haajju bil-umrati wal-hajji ma'an minal-meeqat, aw yuhrima bil-umrati thumma yadkhula alaihal-hajju qablat-tawaf. Wa yaltazimu bimahzooratil-ihram wa la yatahallalu minhu ba'da tawafil-qudoomi wa sa'yihi bal yabqa muhriman hatta yawmin-nahr.",
      'overviewArMeaning': "Hajj al-Qiran is when the pilgrim enters the state of Ihram for both Umrah and Hajj combined at the Miqat, or enters Ihram for Umrah and then joins Hajj with it before the Tawaf. The pilgrim adheres to the restrictions of Ihram and does not exit Ihram after Tawaf al-Qudum and Sa'i, but remains in the state of Ihram until the Day of Sacrifice (10th of Dhul Hijjah).",
      'actionDetails': [
        {
          'title': 'Perform Ghusl and wear Ihram garments at the Miqat.',
          'details': 'Take a complete ritual purification bath (Ghusl) before reaching the Miqat boundary. Wear the two sheets of unstitched white cloth (Izar and Rida) for men, or modest, clean dress for women.',
          'glossary': [
            {'term': 'Miqat', 'meaning': 'The designated geographic boundary points where pilgrims must enter Ihram.'},
            {'term': 'Ghusl', 'meaning': 'The full-body ritual purification bath in Islam.'}
          ]
        },
        {
          'title': 'Make intention for both Hajj and Umrah.',
          'details': 'After praying 2 Rakat, state your intention clearly: "Labbayk Allahumma Hajjah wa Umrah" (لَبَّيْكَ اللَّهُمَّ حَجًّا وَعُمْرَةً).',
          'glossary': [
            {'term': 'Hajj', 'meaning': 'The major pilgrimage to Makkah performed during Dhul Hijjah.'},
            {'term': 'Umrah', 'meaning': 'The minor pilgrimage to Makkah which can be performed at any time.'}
          ]
        },
        {
          'title': 'Begin reciting Talbiyah and maintain Ihram restrictions.',
          'details': 'Chant the Talbiyah aloud (for men). You must strictly avoid all Ihram restrictions (no perfume, no cutting hair/nails, no hunting) until you pelt the major Jamrah on the 10th of Dhul Hijjah.',
          'glossary': [
            {'term': 'Talbiyah', 'meaning': 'The chant recited by pilgrims: Labbayk Allahumma Labbayk.'},
            {'term': 'Ihram Restrictions', 'meaning': 'Prohibited acts while in Ihram state such as wearing sewn clothes (for men) or using scent.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'فَمَن تَمَتَّعَ بِالْعُمْرَةِ إِلَى الْحَجِّ فَمَا اسْتَيْسَرَ مِنَ الْهَدْيِ',
        'referenceAr': 'سورة البقرة - الآية ١٩٦',
        'textEn': 'Then whoever performs Umrah [during the Hajj months] followed by Hajj, [offers] what can be obtained with ease of sacrificial animals.',
        'translitEn': "Faman tamatta'a bil-'umrati ilal-hajji fama-staysara minal-hady.",
        'referenceEn': 'Surah Al-Baqarah (2:196)',
        'explanationEn': 'The Quran commands those who combine Umrah and Hajj (Tamattu\' or Qiran) to offer an animal sacrifice (Qurbani) out of gratitude.',
        'explanationAr': 'وجوب الهدي (ذبْح شاة) شُكراً لله على تيسير الجمع بين النسكين في سفرة واحدة.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ أَنَسٍ رَضِيَ اللَّهُ عَنْهُمَا قَالَ: سَمِعْتُ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ يَقُولُ: «لَبَّيْكَ عُمْرَةً وَحَجًّا»',
          'translitEn': 'An Anas radiya-allahu anhuma qala: Sami\'tu rasula-llahi salla-allahu alayhi wa sallama yaqulu: Labbayk Umratan wa Hajjah.',
          'referenceEn': 'Sahih Muslim 1251',
          'textEn': 'Anas reported: "I heard the Messenger of Allah (ﷺ) saying: Labbayk for Umrah and Hajj together."',
          'explanationEn': 'This Hadith provides direct evidence for the legality of Qiran (combining Hajj and Umrah in one Ihram).',
          'sourceBook': 'Sahih Muslim',
          'sourceBookDesc': 'Sahih Muslim is one of the six major Hadith collections, compiled by Imam Muslim ibn al-Hajjaj.'
        },
        {
          'textAr': 'عَنِ ابْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ أَحْرَمَ بِالْعُمْرَةِ وَالْحَجِّ مَعاً',
          'translitEn': 'An ibni Umar radiya-allahu anhuma anna rasula-llahi salla-allahu alayhi wa sallama ahrama bil-umrati wal-hajji ma\'an.',
          'referenceEn': 'Sahih al-Bukhari 1562',
          'textEn': 'Ibn Umar reported that the Messenger of Allah (ﷺ) entered the state of Ihram for both Umrah and Hajj together.',
          'explanationEn': 'Confirms that the Prophet ﷺ himself performed Hajj Qiran during his Farewell Pilgrimage.',
          'sourceBook': 'Sahih al-Bukhari',
          'sourceBookDesc': 'Sahih al-Bukhari is the most authentic book of Hadith, compiled by Imam Muhammad ibn Ismail al-Bukhari.'
        }
      ],
      'duas': [
        {
          'title': 'Intention for Hajj Qiran',
          'arabic': 'لَبَّيْكَ اللَّهُمَّ حَجًّا وَعُمْرَةً',
          'translit': 'Labbayk Allahumma Hajjah wa \'Umrah',
          'meaningEn': 'O Allah, I answer Your call to perform Hajj and Umrah together.',
          'meaningAr': 'النية للجمع بين العمرة والحج في إحرام واحد.',
        },
        {
          'title': 'The Talbiyah chant',
          'arabic': 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لا شَرِيكَ لَكَ لَبَّيْكَ...',
          'translit': 'Labbayk Allahumma Labbayk, Labbayka la sharika laka labbayk...',
          'meaningEn': 'Here I am, O Allah, here I am, You have no partner...',
          'meaningAr': 'التلبية إعلاناً للتوحيد وإجابةً لنداء الله عز وجل.',
        }
      ]
    },

    'ihram_ifrad': {
      'titleEn': 'Enter Ihram for Hajj Ifrad',
      'titleAr': 'الإحرام لحج الإفراد',
      'day': 'At Miqat - Before entering Haram boundaries',
      'dayAr': 'الميقات - قبل دخول حدود الحرم',
      'overviewEn': 'Hajj al-Ifrad is performing Hajj alone, without Umrah. The pilgrim enters Ihram at the Miqat with the intention of Hajj only, performs Tawaf al-Qudum, and remains in the state of Ihram until the 10th of Dhul Hijjah. No sacrificial animal (Hady) is obligatory for Ifrad.',
      'overviewAr': 'حج الإفراد هو أن يحرم الحاج بالحج وحده من الميقات قائلاً: لَبَّيْكَ اللَّهُمَّ حَجًّا. ويطوف للقدوم ويسعى للحج ويبقى على إحرامه حتى يوم النحر. ولا يجب عليه الهدي (ذبح فدية).',
      'overviewArTranslit': "Hajjul-ifradi huwa an yuhrimal-haajju bil-hajji wahdahu minal-meeqat qa'ilan: Labbayk Allahumma Hajjah. Wa yatoofu lil-qudoomi wa yas'a lil-hajji wa yabqa 'ala ihramihi hatta yawmin-nahr. Wa la yajibu 'alayhil-hady (dhabhu fidyah).",
      'overviewArMeaning': "Hajj al-Ifrad is performing Hajj alone from the Miqat saying: 'Labbayk Allahumma Hajjah'. The pilgrim performs Tawaf al-Qudum and Sa'i for Hajj and remains in the state of Ihram until the Day of Sacrifice (10th of Dhul Hijjah). An animal sacrifice (Hady) is not obligatory for him.",
      'actionDetails': [
        {
          'title': 'Perform Ghusl and wear Ihram garments at the Miqat.',
          'details': 'Purify your body with Ghusl. Men wear the Izar and Rida sheets. Women wear standard clean modest dress covering everything except face and hands.',
          'glossary': [
            {'term': 'Ghusl', 'meaning': 'The full-body ritual bath taken for purification.'},
            {'term': 'Ifrad', 'meaning': 'A type of Hajj performed on its own without Umrah.'}
          ]
        },
        {
          'title': 'Make intention for Hajj only.',
          'details': 'After performing 2 Rakat prayer, make your intention: "Labbayk Allahumma Hajjah" (لَبَّيْكَ اللَّهُمَّ حَجًّا) for Hajj only.',
          'glossary': [
            {'term': 'Niyyah', 'meaning': 'The intention in the heart to perform an act of worship.'}
          ]
        },
        {
          'title': 'Recite Talbiyah and follow Ihram rules strictly.',
          'details': 'Keep reciting the Talbiyah. You must remain in the state of Ihram with all its restrictions until the 10th of Dhul Hijjah.',
          'glossary': [
            {'term': 'Talbiyah', 'meaning': 'The pilgrim\'s chant answering the call of Allah.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'وَلِلَّهِ عَلَى النَّاسِ حِجُّ الْبَيْتِ مَنِ اسْتَتَاعَ إِلَيْهِ سَبِيلًا',
        'referenceAr': 'سورة آل عمران - الآية ٩٧',
        'textEn': 'And [due] to Allah from the people is a pilgrimage to the House - for whoever is able to find thereto a way.',
        'translitEn': "Wa lillahi 'alan-nasi hijjul-bayti manis-tata'a ilayhi sabila.",
        'referenceEn': 'Surah Ali \'Imran (3:97)',
        'explanationEn': 'This general command shows Hajj itself is the core duty, which the Mufrid (pilgrim performing Ifrad) fulfills directly.',
        'explanationAr': 'وجوب الحج العيني على المستطيع مرة واحدة في العمر.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ عَائِشَةَ رَضِيَ اللَّهُ عَنْهَا قَالَتْ: «خَرَجْنَا مَعَ رَسُولِ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ... فَمِنَّا مَنْ أَهَلَّ بِعُمْرَةٍ، وَمِنَّا مَنْ أَهَلَّ بِحَجٍّ وَعُمْرَةٍ، وَمِنَّا مَنْ أَهَلَّ بِحَجٍّ مُفْرِدٍ»',
          'translitEn': 'An Aisha radiya-allahu anha qalat: Kharajna ma\'a rasuli-llahi salla-allahu alayhi wa sallama... faminna man ahalla bi umrah, wa minna man ahalla bi hajjin wa umrah, wa minna man ahalla bi hajjin mufrid.',
          'referenceEn': 'Sahih al-Bukhari & Sahih Muslim',
          'textEn': 'Aisha narrated: "We set out with the Messenger of Allah (ﷺ)... some of us assumed Ihram for Umrah, some for both Hajj and Umrah, and some for Hajj only (Ifrad)."',
          'explanationEn': 'This confirms that all three types of Hajj (Tamattu\', Qiran, and Ifrad) are valid and were practiced by the Companions under the guidance of the Prophet.',
          'sourceBook': 'Sahih al-Bukhari & Sahih Muslim',
          'sourceBookDesc': 'These are the two most authentic collections of Hadith in Sunni Islam.'
        },
        {
          'textAr': 'عَنْ عَبْدِ اللَّهِ بْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ أَفْرَدَ الْحَجَّ',
          'translitEn': 'An ibni Umar radiya-allahu anhuma anna-nabiyya salla-allahu alayhi wa sallama afrada-l-hajj.',
          'referenceEn': 'Sahih Muslim 1211',
          'textEn': 'Ibn Umar narrated that the Prophet (ﷺ) performed Hajj Ifrad (Hajj only).',
          'explanationEn': 'Provides direct evidence of the validity and practice of Hajj Ifrad by the Prophet ﷺ.',
          'sourceBook': 'Sahih Muslim',
          'sourceBookDesc': 'Sahih Muslim is compiled by Imam Muslim and contains highly authentic narrations.'
        }
      ],
      'duas': [
        {
          'title': 'Intention for Hajj Ifrad',
          'arabic': 'لَبَّيْكَ اللَّهُمَّ حَجًّا',
          'translit': 'Labbayk Allahumma Hajjah',
          'meaningEn': 'O Allah, I answer Your call to perform Hajj.',
          'meaningAr': 'النية لأداء الحج مفرداً.',
        },
        {
          'title': 'General Talbiyah',
          'arabic': 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لا شَرِيكَ لَكَ لَبَّيْكَ...',
          'translit': 'Labbayk Allahumma Labbayk, Labbayka la sharika laka labbayk...',
          'meaningEn': 'Here I am, O Allah, here I am...',
          'meaningAr': 'التلبية إجابة نداء إبراهيم عليه السلام بالحج.'
        }
      ]
    },

    'halq_ifrad': {
      'titleEn': 'Halq or Taqsir (Shaving or Trimming)',
      'titleAr': 'الحلق أو التقصير للمفرد',
      'day': '10th Dhul Hijjah (Yawm an-Nahr)',
      'dayAr': '١٠ ذو الحجة (يوم النحر)',
      'overviewEn': 'After stoning Jamarat al-Aqabah on the 10th of Dhul Hijjah, the pilgrim performing Hajj Ifrad shaves or trims their hair to complete the first partial deconsecration (Tahallul al-Asghar). Because this is Hajj Ifrad, Qurbani (sacrifice) is not obligatory, so they proceed directly from stoning to shaving.',
      'overviewAr': 'بعد رمي جمرة العقبة الكبرى يوم النحر، يقوم المفرد بحلق رأسه أو تقصيره مباشرة (حيث لا يجب عليه ذبح هدي) ليتحلل التحلل الأول، فيلبس ثيابه ويتطيب وتزول عنه محظورات الإحرام عدا النساء.',
      'overviewArTranslit': "Ba'da ramyi Jamratil-Aqabatil-Kubra yawman-nahr, yaqoomul-mufridu bihalqi ra'sihi aw taqseerihi mubasharatan (haythu la yajibu 'alayhi dhabhu hady) liyatahallalat-tahallulal-awwal, fayalbasu thiyabahu wa yatatayyabu wa tazoolu 'anhu mahzooratul-ihrami 'adan-nisa'.",
      'overviewArMeaning': "After stoning Jamarat al-Aqabah al-Kubra on the Day of Sacrifice, the pilgrim performing Ifrad shaves or cuts his hair directly (as animal sacrifice is not obligatory for him) to achieve the first deconsecration. He can then wear his regular clothes, apply perfume, and all restrictions of Ihram are lifted except marital relations.",
      'actionDetails': [
        {
          'title': 'Proceed directly to shave (Halq) or trim (Taqsir) hair after pelting.',
          'details': 'Once you complete stoning the major Jamrah, go to a barber to shave or trim your hair. Qurbani is not obligatory for Ifrad pilgrims, so you can do this immediately.',
          'glossary': [
            {'term': 'Halq', 'meaning': 'Shaving the head completely (applicable for men).'},
            {'term': 'Taqsir', 'meaning': 'Trimming/shortening the hair evenly all around.'}
          ]
        },
        {
          'title': 'Men are highly recommended to shave completely.',
          'details': 'Shaving the entire head (Halq) is superior to trimming, as the Prophet ﷺ supplicated three times for those who shave and only once for those who trim.',
          'glossary': [
            {'term': 'Prophetic Supplication', 'meaning': 'Prayers made by the Prophet ﷺ carrying immense blessing.'}
          ]
        },
        {
          'title': 'Women trim a fingertip length of hair.',
          'details': 'Women do not shave their heads. They gather their hair and cut a small portion, about the length of a fingertip (1.5–2 cm), from the ends.',
          'glossary': [
            {'term': 'Fingertip length', 'meaning': 'The measure used for women trimming hair (approx. 2 cm).'}
          ]
        },
        {
          'title': 'Achieve Tahallul al-Asghar and change into regular clothes.',
          'details': 'Once the hair is shaved or trimmed, you enter the state of partial deconsecration (Tahallul al-Asghar). You can now shower, wear regular clothes, and use perfume.',
          'glossary': [
            {'term': 'Tahallul al-Asghar', 'meaning': 'The first stage of exiting Ihram which lifts all restrictions except marital relations.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'مُحَلِّقِينَ رُءُوسَكُمْ وَمُقَصِّرِينَ لَا تَخَافُونَ',
        'referenceAr': 'سورة الفتح - الآية ٢٧',
        'textEn': 'With your heads shaved and hair shortened, not fearing.',
        'translitEn': 'Muhalliqina ru\'usakum wa muqassirina la takhafûn.',
        'referenceEn': 'Surah Al-Fath (48:27)',
        'explanationEn': 'Shaving and trimming are recognized by Allah as the sacred conclusion of the state of Ihram.',
        'explanationAr': 'مشروعية الحلق والتقصير لإنهاء الإحرام والتحلل.',
      },
      'hadiths': [
        {
          'textAr': 'عَنِ ابْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ حَلَقَ فِي حَجَّتِهِ',
          'translitEn': 'An ibni Umar radiya-allahu anhuma anna-nabiyya salla-allahu alayhi wa sallama halaqa fi hajjatihi.',
          'referenceEn': 'Sahih al-Bukhari & Sahih Muslim',
          'textEn': 'Ibn Umar narrated: "The Messenger of Allah (ﷺ) had his head shaved during his Hajj pilgrimage."',
          'explanationEn': 'Prophetic action showing head shaving is the optimal way to conclude the pilgrimage.',
          'sourceBook': 'Sahih al-Bukhari & Sahih Muslim',
          'sourceBookDesc': 'These are the two primary authentic collections of prophetic traditions.'
        },
        {
          'textAr': 'عَنْ أَبِي هُرَيْرَةَ رَضِيَ اللَّهُ عَنْهُ قَالَ: قَالَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ: «اللَّهُمَّ اغْفِرْ لِلْمُحَلِّقِينَ»، قَالُوا: وَلِلْمُقَصِّرِينَ...؟',
          'translitEn': 'An Abi Hurairah radiya-allahu anhu qala: Qala rasulu-llahi salla-allahu alayhi wa sallama: Allahumma-ghfir lil-muhalliqina. Qalu: Wa lil-muqassirina...?',
          'referenceEn': 'Sahih al-Bukhari 1727 & Sahih Muslim 1301',
          'textEn': 'Abu Hurairah reported: The Prophet (ﷺ) said, "O Allah, forgive those who shave their heads!" The companions asked, "And those who trim, O Messenger of Allah?" He said, "O Allah, forgive those who shave!" They asked again, and on the third time he said, "And those who trim."',
          'explanationEn': 'Demonstrates that head-shaving is thrice blessed by the Prophet ﷺ compared to trimming.',
          'sourceBook': 'Sahih al-Bukhari & Sahih Muslim',
          'sourceBookDesc': 'Compiled by Imams Al-Bukhari and Muslim, these books represent the peak of Hadith authenticity.'
        }
      ],
      'duas': [
        {
          'title': 'Dua of Gratitude upon Shaving',
          'arabic': 'الْحَمْدُ لِلَّهِ الَّذِي قَضَى عَنَّا نُسُكَنَا',
          'translit': 'Alhamdu lillahil-ladhi qada \'anna nusukana',
          'meaningEn': 'Praise be to Allah Who has enabled us to complete our rituals.',
          'meaningAr': 'الحمد والشكر لله على إتمام مناسك التحلل الأصغر.',
        },
        {
          'title': 'Dua for Forgiveness upon Shaving',
          'arabic': 'اللَّهُمَّ ثَبِّتْ لِي بِكُلِّ شَعْرَةٍ حَسَنَةً وَامْحُ عَنِّي بِهَا سَيِّئَةً',
          'translit': 'Allahumma thabbit li bikulli sha\'ratin hasanataw-wamhu \'anni biha sayyi\'ah',
          'meaningEn': 'O Allah, record for me a good deed for every hair and wipe out a sin for it.',
          'meaningAr': 'سؤال الله الثواب والمغفرة مع تساقط شعر الرأس.'
        }
      ]
    },

    'sai_h': {
      'titleEn': 'Sa’i of Hajj (Safa & Marwah)',
      'titleAr': 'سعي الحج (الصفا والمروة)',
      'day': '10th Dhul Hijjah or Days of Tashreeq',
      'dayAr': '١٠ ذو الحجة أو أيام التشريق',
      'overviewEn': 'Sa’i of Hajj is a mandatory ritual consisting of walking seven times between the hills of Safa and Marwah. For Hajj Tamattu\', this Sa\'i is performed after Tawaf al-Ifadah. For Hajj Qiran and Ifrad, it is typically performed after Tawaf al-Qudum or Tawaf al-Ifadah.',
      'overviewAr': 'سعي الحج هو المشي بين الصفا والمروة سبعة أشواط، وهو ركن من أركان الحج عند جمهور العلماء. يؤديه القارن والمفرد بعد طواف القدوم (أو طواف الإفاضة)، بينما يؤديه المتمتع بعد طواف الإفاضة وجوباً.',
      'overviewArTranslit': "Sa'yul-hajji huwal-mashyu baynas-Safa wal-Marwata sab'ata ashwaatin, wa huwa ruknum-min arkaanil-hajji 'inda jumhooril-ulama'. Yu'addeehil-qaarinu wal-mufridu ba'da tawafil-qudoomi (aw tawafil-ifadah), baynama yu'addeehil-mutamatti'u ba'da tawafil-ifadah wajooban.",
      'overviewArMeaning': "Sa'i of Hajj is walking between Safa and Marwah seven times, and it is a pillar among the pillars of Hajj according to the majority of scholars. The pilgrim performing Qiran and Ifrad performs it after Tawaf al-Qudum (or Tawaf al-Ifadah), while the pilgrim performing Tamattu' must perform it after Tawaf al-Ifadah.",
      'actionDetails': [
        {
          'title': 'Perform 7 laps starting from Safa and ending at Marwah.',
          'details': 'Walk from Safa to Marwah (1st lap), then back to Safa (2nd lap), and repeat until you complete 7 laps, ending at Marwah.',
          'glossary': [
            {'term': 'Sa\'i', 'meaning': 'The ritual of walking seven times between Safa and Marwah.'},
            {'term': 'Safa', 'meaning': 'The small hill where the Sa\'i begins.'},
            {'term': 'Marwah', 'meaning': 'The small hill where the Sa\'i ends.'}
          ]
        },
        {
          'title': 'Men should jog/run briskly between the green lights (Raml).',
          'details': 'When men reach the area marked by green fluorescent lights, they should run or jog briskly (Raml) while maintaining dignity. Women walk normally.',
          'glossary': [
            {'term': 'Raml', 'meaning': 'Brushing/brisk running performed by men in specific parts of Tawaf and Sa\'i.'}
          ]
        },
        {
          'title': 'Make sincere Duas and remember Allah at the peaks.',
          'details': 'At the top of Safa and Marwah, face the Kaaba, raise your hands, and make personal supplications. Recite the prophetic praise three times before making your own prayers.',
          'glossary': [
            {'term': 'Kaaba', 'meaning': 'The cuboid building at the center of Islam\'s most sacred mosque, Al-Masjid al-Haram.'},
            {'term': 'Dhikr', 'meaning': 'The remembrance of Allah through chanting praises.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'إِنَّ الصَّفَا وَالْمَرْوَةَ مِن شَعَائِرِ اللَّهِ ۖ فَمَنْ حَجَّ الْبَيْتَ أَوِ اعْتَمَرَ فَلَا جُنَاحَ عَلَيْهِ أَن يَطَّوَّفَ بِهِمَا',
        'referenceAr': 'سورة البقرة - الآية ١٥٨',
        'textEn': 'Indeed, Safa and Marwah are among the symbols of Allah. So whoever makes Hajj to the House or performs Umrah - there is no blame upon him for walking between them.',
        'translitEn': "Innas-Safa wal-Marwata min sha'a'irillah. Faman hajjal-bayta awi-'tamara fala junaha 'alayhi ay-yattawwafa bihima.",
        'referenceEn': 'Surah Al-Baqarah (2:158)',
        'explanationEn': 'Allah establishes Safa and Marwah as sacred signs of His worship, honoring the persistence and faith of Hajar (peace be upon her).',
        'explanationAr': 'تبيّن الآية أن الصفا والمروة من شعائر الدين ومواضع العبادة، وتشرع السعي بينهما.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ جَابِرِ بْنِ عَبْدِ اللَّهِ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ قَالَ فِي سَعْيِهِ: «ابْدَءُوا بِمَا بَدَأَ اللَّهُ بِهِ» فَبَدَأَ بِالصَّفَا',
          'translitEn': 'An Jabiri-bni Abdillah radiya-allahu anhuma anna-nabiyya salla-allahu alayhi wa sallama qala fi sa\'yihi: Ibda\'u bima bada\'a-llahu bihi, fabada\'a bis-Safa.',
          'referenceEn': 'Sahih Muslim 1218',
          'textEn': 'Jabir bin Abdullah reported: The Prophet (ﷺ) said regarding Sa’i: "Begin with that which Allah has begun with." So he started with Safa.',
          'explanationEn': 'This Hadith confirms the obligation of starting the Sa’i from Mount Safa as demonstrated by the Prophet (ﷺ).',
          'sourceBook': 'Sahih Muslim',
          'sourceBookDesc': 'One of the authentic Hadith collections compiled by Imam Muslim.'
        },
        {
          'textAr': 'عَنْ حَبِيبَةَ بِنْتِ أَبِي تَجْرَاةَ قَالَتْ: رَأَيْتُ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ يَسْعَى بَيْنَ الصَّفَا وَالْمَرْوَةَ وَهُوَ يَقُولُ: «اسْعَوْا فَإِنَّ اللَّهَ كَتَبَ عَلَيْكُمُ السَّعْيَ»',
          'translitEn': 'An Habibata binti Abi Tajra\'ata qalat: Ra\'aytu rasula-llahi salla-allahu alayhi wa sallama yas\'a baynas-Safa wal-Marwata wa huwa yaqul: Is\'aw fa-inna-llaha kataba alaykumu-s-sa\'y.',
          'referenceEn': 'Musnad Ahmad 27410 & Sunan al-Kubra of Al-Bayhaqi',
          'textEn': 'Habibah bint Abi Tajrah narrated: "I saw the Messenger of Allah (ﷺ) performing Sa\'i between Safa and Marwah, and he was saying: Run, for Allah has decreed running (Sa\'i) upon you."',
          'explanationEn': 'Establishes that Sa\'i is a binding obligation (Wajib/Rukn) on the pilgrim by divine decree.',
          'sourceBook': 'Musnad Ahmad',
          'sourceBookDesc': 'A major collection of Hadith compiled by Imam Ahmad ibn Hanbal, organized by narrating Companions.'
        }
      ],
      'duas': [
        {
          'title': 'Prophetic Praise on Safa & Marwah',
          'arabic': 'لا إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، لا إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ، أَنْجَزَ وَعْدَهُ، وَنَصَرَ عَبْدَهُ، وَهَزَمَ الأَحْزَابَ وَحْدَهُ',
          'translit': 'La ilaha illallahu wahdahu la sharika lahu, lahul-mulku wa lahul-hamdu, wa huwa \'ala kulli shay\'in qadir. La ilaha illallahu wahdahu, anjaza wa\'dahu, wa nasara \'abdahu, wa hazamal-ahzaba wahdah.',
          'meaningEn': 'There is no deity except Allah alone, without partner. To Him belongs sovereignty and praise, and He has power over all things. There is no deity except Allah alone, He fulfilled His promise, granted victory to His servant, and defeated the confederates alone.',
          'meaningAr': 'التكبير والتهليل والثناء على الله عند صعود جبل الصفا والمروة والاستقبال للقبلة.',
        },
        {
          'title': 'Dua of Hajar\'s Commemoration',
          'arabic': 'إِنَّ الصَّفَا وَالْمَرْوَةَ مِن شَعَائِرِ اللَّهِ فَمَنْ حَجَّ الْبَيْتَ أَوِ اعْتَمَرَ فَلَا جُنَاحَ عَلَيْهِ أَن يَطَّوَّفَ بِهِمَا',
          'translit': 'Innas-Safa wal-Marwata min sha\'a\'irillah faman hajjal-bayta awi-\'tamara fala junaha \'alayhi ay-yattawwafa bihima.',
          'meaningEn': 'Indeed, Safa and Marwah are among the symbols of Allah. So whoever makes Hajj to the House or performs Umrah - there is no blame upon him for walking between them.',
          'meaningAr': 'تلاوة الآية عند الإقبال على جبل الصفا لبدء السعي.',
        }
      ]
    },

    'ihram': {
      'titleEn': 'Enter Ihram & Intention (Niyyah)',
      'titleAr': 'الإحرام والنية',
      'day': 'Miqat - Before entering the Haram boundaries',
      'dayAr': 'الميقات - قبل دخول حدود الحرم',
      'overviewEn': 'Ihram is the sacred state a pilgrim enters to perform Hajj or Umrah. It involves specific physical purifications (Ghusl), wearing designated unstitched white sheets (for men), reciting the Niyyah (intention), and continuously chanting the Talbiyah. Once in Ihram, prohibitions such as cutting hair, applying perfume, clipping nails, and hunting apply until deconsecration.',
      'overviewAr': 'الإحرام هو النية والنية في الدخول في النسك مع التجرُّد من المَخِيط للرجال. ويبدأ بالتطهر والغسل، ثم لبس رداء وإزار أبيضين نظيفين، بينما تلبس المرأة ما شاءت من اللباس الساتر دون تبرج، ثم التلفظ بالنية والالتزام بمحظورات الإحرام كَقَصّ الشعر والطيب والجدال.',
      'overviewArTranslit': "Al-ihramu huwan-niyyatu fid-dukhooli fin-nusuki ma'at-tajarru-di minal-makheeti lir-rijaal. Wa yabda'u bit-tatah-huri wal-ghusli, thumma lubsi rida'in wa izaarin abyadayni nazeefayni, baynama talbasul-mar'atu ma sha'at minal-libasis-saatiri doona tabarruj, thumma at-talaffuzu bin-niyyati wal-iltizaamu bimahzooratil-ihrami kaqassis-sha'ri wat-teebi wal-jidaal.",
      'overviewArMeaning': "Ihram is the intention to enter the state of pilgrimage rituals along with stripping away sewn clothes for men. It begins with purification and bathing (Ghusl), then wearing two clean white sheets (a lower garment and a shoulder cover), while a woman wears whatever modest clothing she wishes without displaying adornment, followed by uttering the intention and adhering to the restrictions of Ihram such as cutting hair, applying perfume, and arguing.",
      'actionDetails': [
        {
          'title': 'Perform Ghusl (ritual bath) and trim nails/mustache before Miqat.',
          'details': 'Take a physical purification bath, clean your body, clip nails, and trim hair if necessary before passing the Miqat boundary.',
          'glossary': [
            {'term': 'Ghusl', 'meaning': 'The full-body ritual purification bath in Islam.'},
            {'term': 'Miqat', 'meaning': 'The geographical boundaries set by the Prophet ﷺ where entering Ihram is required.'}
          ]
        },
        {
          'title': 'Wear 2 unstitched white sheets (Izar & Rida) for men; loose modest dress for women.',
          'details': 'Men wrap one sheet around the waist (Izar) and one over the shoulders (Rida). No sewn clothing, underwear, or socks are allowed. Women wear clean modest clothes and leave their face and hands uncovered.',
          'glossary': [
            {'term': 'Izar', 'meaning': 'The lower sheet of Ihram cloth wrapped around the waist.'},
            {'term': 'Rida', 'meaning': 'The upper sheet of Ihram cloth covering the shoulders.'}
          ]
        },
        {
          'title': 'Offer 2 Rakat Sunnah prayer at the Miqat.',
          'details': 'If appropriate (not during disliked prayer times), offer 2 Rakat of optional prayer (Nafl) after wearing the Ihram sheets.',
          'glossary': [
            {'term': 'Rakat', 'meaning': 'Units of prayer.'},
            {'term': 'Nafl', 'meaning': 'Supererogatory (voluntary) prayer.'}
          ]
        },
        {
          'title': 'Make explicit intention (Niyyah).',
          'details': 'State your intention for Hajj or Umrah: "Labbayk Allahumma Umrah" (لَبَّيْكَ اللَّهُمَّ عُمْرَةً) or "Labbayk Allahumma Hajjah" (لَبَّيْكَ اللَّهُمَّ حَجًّا).',
          'glossary': [
            {'term': 'Niyyah', 'meaning': 'Sincere intention in the heart to initiate an act of worship.'}
          ]
        },
        {
          'title': 'Begin loud recitation of Talbiyah.',
          'details': 'Chant the Talbiyah loudly (for men) and quietly (for women). This must be recited regularly until you start stoning the Jamrah or performing Tawaf.',
          'glossary': [
            {'term': 'Talbiyah', 'meaning': 'The chant recited by pilgrims: Labbayk Allahumma Labbayk.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'الْحَجُّ أَشْهُرٌ مَّعْلُومَاتٌ ۚ فَمَن فَرَضَ فِيهِنَّ الْحَجَّ فَلَا رَفَثَ وَلَا فُسُوقَ وَلَا جِدَالَ فِي الْحَجِّ ۗ وَمَا تَفْعَلُوا مِنْ خَيْرٍ يَعْلَمْهُ اللَّهُ',
        'referenceAr': 'سورة البقرة - الآية ١٩٧',
        'textEn': 'Hajj is [during] well-known months, so whoever has made Hajj obligatory upon himself therein [by entering the state of ihram], there is [to be for him] no sexual relations and no disobedience and no disputing during Hajj. And whatever good you do - Allah knows it.',
        'translitEn': 'Al-hajju ashhurum-ma\'lumat. Faman farada fihinnal-hajja fala rafatha wa la fusuqa wa la jidala fil-hajj. Wa ma taf\'alu min khayriy-ya\'lamhullah.',
        'referenceEn': 'Surah Al-Baqarah (2:197)',
        'explanationEn': 'Allah explicitly establishes that entering Ihram requires refraining from immoral actions, disputes, and earthly desires, elevating spiritual focus solely towards Allah.',
        'explanationAr': 'توضح الآية الكريمة حرمة وقت الإحرام ووجوب اجتناب الرفث والفسوق والجدال بالباطل، ليتفرغ الحاج لذكر الله والتقوى.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ عَبْدِ اللَّهِ بْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ سُئِلَ: مَا يَلْبَسُ الْمُحْرِمُ؟ فَقَالَ: «لاَ يَلْبَسُ الْقُمُصَ وَلاَ الْعَمَائِمَ وَلاَ السَّرَاوِيلاَتِ وَلاَ الْبَرَانِسَ وَلاَ الْخِفَافَ...»',
          'translitEn': 'An ibni Umar radiya-allahu anhuma anna rasula-llahi salla-allahu alayhi wa sallama su\'ila: Ma yalbasu-l-muhrim? Faqala: La yalbasu-l-qumusa wa la-l-ama\'ima wa la-s-sarawilati wa la-l-baranisa wa la-l-khifafa...',
          'referenceEn': 'Sahih al-Bukhari 1542, Sahih Muslim 1177',
          'textEn': 'Narrated Abdullah ibn Umar: A man asked the Prophet (ﷺ), "What should a pilgrim in Ihram wear?" The Prophet replied, "He should not wear shirts, turbans, trousers, hooded cloaks, or leather socks..."',
          'explanationEn': 'This Hadith lays out the essential dress code for men in Ihram to strip away worldly status and distinctions before Almighty Allah.',
          'sourceBook': 'Sahih al-Bukhari & Sahih Muslim',
          'sourceBookDesc': 'These are the two primary authentic collections of prophetic traditions.'
        },
        {
          'textAr': 'عَنْ عُمَرَ بْنِ الْخَطَّابِ رَضِيَ اللَّهُ عَنْهُ قَالَ: سَمِعْتُ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ يَقُولُ: «إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ»',
          'translitEn': 'An Umara-bni-l-Khattabi radiya-allahu anhu qala: Sami\'tu rasula-llahi salla-allahu alayhi wa sallama yaqulu: Innama-l-a\'malu bin-niyyat.',
          'referenceEn': 'Sahih al-Bukhari 1 & Sahih Muslim 1907',
          'textEn': 'Umar ibn al-Khattab narrated: I heard the Messenger of Allah (ﷺ) say: "Indeed, actions are only judged by intentions..."',
          'explanationEn': 'Establishes that the internal intention (Niyyah) in the heart is the foundation for all religious acts including Hajj and Umrah.',
          'sourceBook': 'Sahih al-Bukhari',
          'sourceBookDesc': 'The first and most authentic compiler of authentic prophetic statements.'
        }
      ],
      'duas': [
        {
          'title': 'The Talbiyah (التلبية)',
          'arabic': 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لا شَرِيكَ لَكَ لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكُ، لا شَرِيكَ لَكَ',
          'translit': 'Labbayk Allahumma Labbayk, Labbayka la sharika laka labbayk, innal-hamda wan-ni’mata laka wal-mulk, la sharika lak.',
          'meaningEn': 'Here I am O Allah, here I am. Here I am, You have no partner, here I am. Verily all praise, grace, and sovereignty belong to You. You have no partner.',
          'meaningAr': 'إجابة بعد إجابة لك يا الله، لا شريك لك، إن الحمد والنعمة والملك لك وحدك لا شريك لك.',
        },
        {
          'title': 'Dua for Intention of Hajj',
          'arabic': 'اللَّهُمَّ إِنِّي أُرِيدُ الْحَجَّ فَيَسِّرْهُ لِي وَتَقَبَّلْهُ مِنِّي',
          'translit': 'Allahumma inni ureedul-hajja fayassirhu li wa taqabbalhu minni',
          'meaningEn': 'O Allah, I intend to perform Hajj, so make it easy for me and accept it from me.',
          'meaningAr': 'التوسل بتسهيل وقبول الحج.',
        }
      ]
    },

    'tawaf_qudum': {
      'titleEn': 'Tawaf al-Qudum (Arrival Tawaf)',
      'titleAr': 'طواف القدوم',
      'day': 'Upon arrival in Makkah',
      'dayAr': 'فور الوصول إلى مكة المكرمة',
      'overviewEn': 'Tawaf al-Qudum is the welcome circumambulation performed around the Holy Kaaba upon reaching Makkah. Pilgrims circle the Kaaba seven times counter-clockwise, starting from the Black Stone (Hajar al-Aswad). For men, Idtiba (uncovering the right shoulder) and Raml (brisk walking in the first 3 rounds) are Sunnah.',
      'overviewAr': 'طواف القدوم هو تحية البيت الحرام للمُفْرِد والمقترن فور وصولهما إلى مكة. يطوف الحاج سبعة أشواط يبدأ كل شوط من الحجر الأسود وينتهي عنده، ويُسن للرجال الانطباع (كشف الكتف الأيمن) والرَّمَل (الهرولة الخفيفة في الأشواط الثلاثة الأولى).',
      'overviewArTranslit': "Tawaful-qudoomi huwa tahiyyatul-baytil-harami lil-mufridi wal-muqtarini fawra wusoolihima ila Makkah. Yatooful-haajju sab'ata ashwaatin yabda'u kullu shawtim-minal-hajaril-aswadi wa yantahi 'indah, wa yusannu lir-rijaalil-idtiba'u (kashful-katifil-ayman) war-ramalu (al-harwalatul-khafeefatu fil-ashwaatith-thalathatil-oola).",
      'overviewArMeaning': "Tawaf al-Qudum is the greeting of the Sacred House for those performing Ifrad and Qiran immediately upon their arrival in Makkah. The pilgrim circumambulates seven times, starting and ending each round at the Black Stone. It is Sunnah for men to perform Idtiba (uncovering the right shoulder) and Raml (brisk walking in the first three rounds).",
      'actionDetails': [
        {
          'title': 'Uncover the right shoulder (Idtiba) for men during Tawaf.',
          'details': 'Pass the upper sheet of the Ihram (Rida) under your right armpit and drape it over your left shoulder, leaving your right shoulder uncovered throughout the Tawaf.',
          'glossary': [
            {'term': 'Idtiba', 'meaning': 'Uncovering the right shoulder for men during Tawaf.'},
            {'term': 'Rida', 'meaning': 'The upper sheet of the unstitched Ihram cloth.'}
          ]
        },
        {
          'title': 'Start each circuit at the Hajar al-Aswad saying "Bismillahi Allahu Akbar".',
          'details': 'Align yourself with the Black Stone corner of the Kaaba. Point your right hand towards the stone, kiss it if possible without causing harm, and say "Bismillahi Allahu Akbar" to start your circuit.',
          'glossary': [
            {'term': 'Hajar al-Aswad', 'meaning': 'The Black Stone set in the southeastern corner of the Kaaba.'},
            {'term': 'Allahu Akbar', 'meaning': 'Allah is the Greatest.'}
          ]
        },
        {
          'title': 'Perform Raml (quick brisk walking) in the first 3 rounds.',
          'details': 'Men should perform the first three rounds with quick, short steps (Raml), slightly jogging if space permits. The remaining four rounds are done at a normal walking pace.',
          'glossary': [
            {'term': 'Raml', 'meaning': 'Walking with quick, short steps and moving the shoulders, sunnah in the first 3 rounds.'}
          ]
        },
        {
          'title': 'Recite "Rabbana atina fid-dunya hasanatan..." between Rukn al-Yamani and the Black Stone.',
          'details': 'Between the Yemeni corner and the Black Stone, it is sunnah to recite the prayer asking for good in this life and the hereafter.',
          'glossary': [
            {'term': 'Rukn al-Yamani', 'meaning': 'The southwestern corner of the Kaaba, facing Yemen.'}
          ]
        },
        {
          'title': 'Offer 2 Rakat behind Maqam Ibrahim upon completion.',
          'details': 'Once 7 rounds are complete, cover your shoulder. Go behind the Station of Abraham (or anywhere in the mosque) and pray 2 units of prayer.',
          'glossary': [
            {'term': 'Maqam Ibrahim', 'meaning': 'The crystal and bronze dome containing the stone with the footprints of Ibrahim (AS).'},
            {'term': 'Rakat', 'meaning': 'Units of prayer.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'وَإِذْ جَعَلْنَا الْبَيْتَ مَثَابَةً لِّلنَّاسِ وَأَمْنًا وَاتَّخِذُوا مِن مَّقَامِ إِبْرَاهِيمَ مُصَلًّى',
        'referenceAr': 'سورة البقرة - الآية ١٢٥',
        'textEn': 'And [remember] when We made the House a place of return for the people and [a place of] security. And take, [O believers], from the standing place of Abraham a place of prayer.',
        'translitEn': 'Wa idh ja\'alnal-bayta mathabatal-linnasi wa amna. Wattakhidhu mim-maqami Ibrahima musalla.',
        'referenceEn': 'Surah Al-Baqarah (2:125)',
        'explanationEn': 'Allah commands believers to make the Sanctuary a place of worship and to pray behind Maqam Ibrahim after performing Tawaf.',
        'explanationAr': 'أمر الله تعالى بتعظيم الكعبة وأداء الصلاة عند مقام إبراهيم عليه السلام تخليداً لذكراه واقتداءً بالأنبياء.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ جَابِرِ بْنِ عَبْدِ اللَّهِ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ لَمَّا قَدِمَ مَكَّةَ أَتَى الْحَجَرَ فَاسْتَلَمَهُ فَرَمَلَ ثَلاَثًا وَمَشَى أَرْبَعًا، ثُمَّ تَقَدَّمَ إِلَى مَقَامِ إِبْرَاهِيمَ...',
          'translitEn': 'An Jabir radiya-allahu anhuma anna rasula-llahi salla-allahu alayhi wa sallama lamma qadima Makkata atal-hajara fastalamahu faramala thalathan wa masha arba\'an...',
          'referenceEn': 'Sahih Muslim 1218',
          'textEn': 'Jabir bin Abdullah reported: When Allah’s Messenger (ﷺ) came to Makkah, he touched the Black Stone, then walked briskly (Raml) for three circuits and walked normally for four. Then he proceeded to Maqam Ibrahim...',
          'explanationEn': 'This Hadith details the exact Sunnah method of Tawaf al-Qudum as demonstrated by Prophet Muhammad (ﷺ).',
          'sourceBook': 'Sahih Muslim',
          'sourceBookDesc': 'One of the two most authentic collections of Hadith in Sunni Islam.'
        },
        {
          'textAr': 'عَنِ ابْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ كَانَ لاَ يَدَعُ أَنْ يَسْتَلِمَ الرُّكْنَ الْيَمَانِيَ وَالْحَجَرَ فِي كُلِّ طَوَافٍ',
          'translitEn': 'An ibni Umar radiya-allahu anhuma anna rasula-llahi salla-allahu alayhi wa sallama kana la yada\'u an yastalima-r-rukna-l-yamaniya wal-hajara fi kulli tawaf.',
          'referenceEn': 'Sahih al-Bukhari 1609 & Sahih Muslim 1267',
          'textEn': 'Ibn Umar reported: "The Messenger of Allah (ﷺ) did not omit to touch the Yamani corner and the Black Stone in every circuit of Tawaf."',
          'explanationEn': 'Underlines the Sunnah of touching the Yemeni Corner and kissing/touching the Black Stone during circumambulation.',
          'sourceBook': 'Sahih al-Bukhari & Sahih Muslim',
          'sourceBookDesc': 'Imam Bukhari and Imam Muslim collections containing highly verified prophetic traditions.'
        }
      ],
      'duas': [
        {
          'title': 'Dua Between Corners',
          'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
          'translit': 'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina \'adhaban-nar.',
          'meaningEn': 'Our Lord, grant us good in this world and good in the Hereafter and protect us from the punishment of the Fire.',
          'meaningAr': 'ربنا منحنا الخير في الدنيا والآخرة ونجنا من عذاب النار.',
        },
        {
          'title': 'Dua upon starting Tawaf',
          'arabic': 'بِسْمِ اللَّهِ وَاللَّهُ أَكْبَرُ، اللَّهُمَّ إِيمَانًا بِكَ وَتَصْدِيقًا بِكِتَابِكَ',
          'translit': 'Bismillahi wallahu Akbar, Allahumma imanam-bika wa tasdeeqam-bikitabik',
          'meaningEn': 'In the name of Allah, Allah is the Greatest. O Allah, out of faith in You and belief in Your Book.',
          'meaningAr': 'البدء بالطواف بذكر اسم الله والتكبير والتصديق بكتابه.',
        }
      ]
    },

    'mina1': {
      'titleEn': 'Day of Tarwiyah (8th Dhul Hijjah)',
      'titleAr': 'يوم التروية (٨ ذو الحجة)',
      'day': '8th Dhul Hijjah - Stay in Mina',
      'dayAr': '٨ ذو الحجة - المبيت بمنى',
      'overviewEn': 'The Day of Tarwiyah marks the official start of Hajj. Pilgrims move to the tent city of Mina in the morning. They perform Dhuhr, Asr, Maghrib, Isha, and Fajr of the 9th Dhul Hijjah in Mina, shortening 4-rak’at prayers to 2 rak’at (Qasr) without combining them. Pilgrims spend the night in spiritual preparation and remembrance.',
      'overviewAr': 'يوم التروية هو بداية أعمال الحج الفعلية. يتوجه الحجاج إلى منى في الصباح، ويصلون فيها الظهر والعصر والمغرب والعشاء وفجر يوم عرفة، يقصرون الصلاة الرباعية ركعتين دون جمع، ويبيتون في منى اتباعاً لسنة النبي صلى الله عليه وسلم.',
      'overviewArTranslit': "Yawmut-tarwiyati huwa bidayatu a'malil-hajji al-fi'liyyah. Yatawajjahul-hujjaju ila Mina fis-sabah, wa yusalloona feeha ad-duhra wal-'asra wal-maghriba wal-'isha'a wa fajra yawmi 'Arafah, yaqsooroonas-salatar-ruba'iyyata rak'atayni doona jam', wa yabeetoona fee Mina ittiba'an lisunnatil-Nabiyyi salla-Allahu 'alayhi wa sallam.",
      'overviewArMeaning': "The Day of Tarwiyah is the beginning of the actual Hajj rituals. Pilgrims head to Mina in the morning, and perform the Dhuhr, Asr, Maghrib, Isha, and Fajr prayers of the Day of Arafah there, shortening the four-unit prayers to two units without combining them, and staying overnight in Mina following the Sunnah of the Prophet (peace be upon him).",
      'actionDetails': [
        {
          'title': 'Enter Ihram from residence if not already in Ihram.',
          'details': 'Tamattu\'-type pilgrims assume Hajj Ihram from Makkah in the morning of the 8th. Perform Ghusl, wear sheets, set Hajj intention, and begin chanting Talbiyah.',
          'glossary': [
            {'term': 'Tarwiyah', 'meaning': 'The Day of Watering (8th Dhul Hijjah) when pilgrims historically prepared water reserves.'},
            {'term': 'Ihram', 'meaning': 'The state of consecration necessary for performing Hajj.'}
          ]
        },
        {
          'title': 'Depart for Mina after sunrise on the 8th of Dhul Hijjah.',
          'details': 'Move towards the tent city of Mina calmly, repeating the Talbiyah along the way.',
          'glossary': [
            {'term': 'Mina', 'meaning': 'A valley located 8 kilometers east of Makkah where pilgrims reside in tents.'}
          ]
        },
        {
          'title': 'Pray five daily prayers at Mina with Qasr (shortened).',
          'details': 'Pray Dhuhr, Asr, Maghrib, Isha, and the Fajr of the 9th of Dhul Hijjah in Mina. Shorten the 4-Rakat prayers (Dhuhr, Asr, Isha) to 2 Rakat, but pray them on their own times without combining.',
          'glossary': [
            {'term': 'Qasr', 'meaning': 'The practice of shortening 4-Rakat prayers to 2 units while traveling.'},
            {'term': 'Jam\'', 'meaning': 'Combining two prayers in one prayer time.'}
          ]
        },
        {
          'title': 'Spend the entire night at Mina resting for Arafah.',
          'details': 'Sleeping and staying overnight in Mina on this night is a highly emphasized Sunnah of the Prophet ﷺ.',
          'glossary': [
            {'term': 'Sunnah', 'meaning': 'The normative practices of the Prophet ﷺ.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'وَاذْكُرُوا اللَّهَ فِي أَيَّامٍ مَّعْدُودَاتٍ ۚ فَمَن تَعَجَّلَ فِي يَوْمَيْنِ فَلَا إِثْمَ عَلَيْهِ وَمَن تَأَخَّرَ فَلَا إِثْمَ عَلَيْهِ ۚ لِمَنِ اتَّقَىٰ',
        'referenceAr': 'سورة البقرة - الآية ٢٠٣',
        'textEn': 'And remember Allah during specific numbered days. Then whoever hastens [his departure] in two days, there is no sin upon him; and whoever delays, there is no sin upon him - for him who fears Allah.',
        'translitEn': "Wadhkurullaha fi ayyamim-ma'dudat. Faman ta'ajjala fi yawmayni fala ithma 'alayh, wa man ta'akhkhara fala ithma 'alayhi limanit-taqa.",
        'referenceEn': 'Surah Al-Baqarah (2:203)',
        'explanationEn': 'This verse refers to the numbered days of Mina overall, highlighting the importance of constant Remembrance (Dhikr) of Allah throughout the stay.',
        'explanationAr': 'الأيام المعدودات هي أيام التشريق ومنى، وأمر الله فيها بإكثار الذكر والتقوى.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ جَابِرٍ رَضِيَ اللَّهُ عَنْهُ فِي صِفَةِ حَجَّةِ النَّبِيِّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ: «فَلَمَّا كَانَ يَوْمُ التَّرْوِيَةِ تَوَجَّهُوا إِلَى مِنًى، فَرَكِبَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، فَصَلَّى بِهَا الظُّهْرَ وَالْعَعْصَرَ وَالْمَغْرِبَ وَالْعِشَاءَ وَالْفَجْرَ...»',
          'translitEn': 'An Jabir radiya-allahu anhu: Falamma kana yawmu-t-tarwiyati tawajjahu ila Mina, farakiba rasulu-llahi salla-allahu alayhi wa sallama, fasalla bihad-Duhra wal-Asra wal-Maghriba wal-Isha\'a wal-Fajr...',
          'referenceEn': 'Sahih Muslim 1218',
          'textEn': 'Jabir (RA) narrated regarding the Prophet’s Hajj: "When the Day of Tarwiyah arrived, they turned towards Mina. The Messenger of Allah (ﷺ) rode there and offered Dhuhr, Asr, Maghrib, Isha, and Fajr prayers. Then he waited until sunrise..."',
          'explanationEn': 'This establishes the Sunnah of traveling to Mina on the 8th and performing shortened prayers before advancing to Arafah.',
          'sourceBook': 'Sahih Muslim',
          'sourceBookDesc': 'One of the six major Hadith collections, compiled by Imam Muslim.'
        },
        {
          'textAr': 'عَنِ ابْنِ عَبَّاسٍ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ صَلَّى بِالْمَبِيتِ فِي مِنى ثَمَّ غَدَا إِلَى عَرَفَاتٍ',
          'translitEn': 'An ibni Abbas radiya-allahu anhuma anna-nabiyya salla-allahu alayhi wa sallama salla bil-mabeeti fi Mina thumma ghada ila Arafat.',
          'referenceEn': 'Sahih al-Bukhari 1657',
          'textEn': 'Ibn Abbas narrated that the Prophet (ﷺ) stayed overnight in Mina, then departed for Arafat in the morning.',
          'explanationEn': 'Confirms the sequence of staying the night in Mina before departing to the plains of Arafat.',
          'sourceBook': 'Sahih al-Bukhari',
          'sourceBookDesc': 'The primary source of authentic prophetic statements, compiled by Imam Al-Bukhari.'
        }
      ],
      'duas': [
        {
          'title': 'Dua of Remembrance in Mina',
          'arabic': 'اللَّهُمَّ إِلَيْكَ تَوَجَّهْتُ، وَوَجْهَكَ أَرَدْتُ، فَاجْعَلْ ذَنْبِي مَغْفُوراً، وَحَجِّي مَبْرُوراً، وَارْحَمْنِي وَلا تُخَيِّبْنِي',
          'translit': 'Allahumma ilayka tawajjahtu, wa wajhaka aradtu, faj’al dhanbi maghfuran, wa hajji mabruran, warhamni wa la tukhayyibni.',
          'meaningEn': 'O Allah, unto You I have turned, and Your Countenance I seek. Forgive my sins, accept my Hajj, show mercy upon me, and do not disappoint me.',
          'meaningAr': 'اللهم إني توجهت إليك وابتغيت وجهك الكريم، فاغفر ذنبي واجعل حجي مبروراً وارحمني.',
        },
        {
          'title': 'Constant Talbiyah chant',
          'arabic': 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لا شَرِيكَ لَكَ لَبَّيْكَ...',
          'translit': 'Labbayk Allahumma Labbayk, Labbayka la sharika laka labbayk...',
          'meaningEn': 'Here I am, O Allah, here I am...',
          'meaningAr': 'شعار الحج بالتلبية والإعلان عن التوحيد.'
        }
      ]
    },

    'arafat': {
      'titleEn': 'Day of Arafah (9th Dhul Hijjah) - Core of Hajj',
      'titleAr': 'يوم عرفة (٩ ذو الحجة) - ركن الحج الأعظم',
      'day': '9th Dhul Hijjah - Standing at Arafat (Wuquf)',
      'dayAr': '٩ ذو الحجة - الوقوف بعرفة',
      'overviewEn': 'The Day of Arafah is the pinnacle and supreme ritual of Hajj ("Hajj is Arafah"). Pilgrims move from Mina to the plain of Arafat. Standing at Arafat (Wuquf) takes place from Dhuhr until Maghrib. Dhuhr and Asr are prayed together combined and shortened (Jam\' & Qasr) at Dhuhr time. Pilgrims spend the entire afternoon crying, seeking forgiveness, and making earnest Duas.',
      'overviewAr': 'يوم عرفة هو العيد الأكبر والحج الأعظم ("الحج عرفة"). يتوجه الحجاج من منى إلى عرفات. يبدأ وقت الوقوف من زوال الشمس (الظهر) حتى غروبها. يصلى الظهر والعصر جمع تقديم وقصراً بأذان وإقامتين. ويقضي الحاج ما بعد الظهر إلى الغروب بالتضرع والدعاء والبكاء لله تعالى.',
      'overviewArTranslit': "Yawmu 'Arafah huwal-'eedul-akbaru wal-hajjul-a'zam ('Al-Hajju 'Arafah'). Yatawajjahul-hujjaju min Mina ila 'Arafat. Yabda'u waqtul-wuqoofi min zawalis-shamsi (ad-duhr) hatta ghuroobiha. Yusallad-duhru wal-'asru jam'a taqdeemin wa qasran bi-adhanin wa iqamatayn. Wa yaqdil-haajju ma ba'dad-duhri ilal-ghuroobi bit-tadarru'i wad-du'a'i wal-buka'i lillahi ta'ala.",
      'overviewArMeaning': "The Day of Arafah is the greatest day and the core of Hajj ('Hajj is Arafah'). Pilgrims proceed from Mina to Arafat. The time of standing begins from the decline of the sun (Dhuhr) until its sunset. Dhuhr and Asr are prayed combined (at the earlier time) and shortened with one Adhan and two Iqamahs. The pilgrim spends the time after Dhuhr until sunset in supplication, prayer, and crying to Allah the Almighty.",
      'actionDetails': [
        {
          'title': 'Travel to Arafat after sunrise on the 9th of Dhul Hijjah.',
          'details': 'Leave your tent in Mina after Fajr and sunrise. Travel to Arafat by bus, train, or walking, chanting the Talbiyah.',
          'glossary': [
            {'term': 'Arafat', 'meaning': 'The vast plain located southeast of Makkah where the core Hajj standing is observed.'}
          ]
        },
        {
          'title': 'Pray Dhuhr & Asr combined and shortened at Dhuhr time.',
          'details': 'Pray Dhuhr (2 Rakat) and Asr (2 Rakat) combined (Jam\' al-Taqdeem) during Dhuhr time with 1 Adhan and 2 separate Iqamahs. No voluntary prayers are offered between them.',
          'glossary': [
            {'term': 'Jam\' al-Taqdeem', 'meaning': 'Combining two prayers ahead of time, in the first prayer\'s time.'},
            {'term': 'Adhan', 'meaning': 'The call to prayer.'},
            {'term': 'Iqamah', 'meaning': 'The second call to stand for prayer.'}
          ]
        },
        {
          'title': 'Observe Wuquf (standing) facing the Qiblah until sunset.',
          'details': 'Spend the afternoon from Dhuhr until sunset standing or sitting, facing the Qiblah (direction of Kaaba), raising your hands in earnest prayer, and seeking forgiveness.',
          'glossary': [
            {'term': 'Wuquf', 'meaning': 'The obligatory standing/staying at Arafat, the single most important pillar of Hajj.'},
            {'term': 'Qiblah', 'meaning': 'The direction of the Kaaba in Makkah.'}
          ]
        },
        {
          'title': 'Make maximum Duas and do not leave before sunset.',
          'details': 'Maintain focus and continue praying until the sun has completely set. Leaving Arafat before sunset is prohibited and requires a penalty.',
          'glossary': [
            {'term': 'Dua', 'meaning': 'Supplication or making request to Allah.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'فَإِذَا أَفَضْتُمْ مِّنْ عَرَفَاتٍ فَاذْكُرُوا اللَّهَ عِندَ الْمَشْعَرِ الْحَرَامِ',
        'referenceAr': 'سورة البقرة - الآية ١٩٨',
        'textEn': 'Then when you depart from Arafat, remember Allah at Al-Mash\'ar al-Haram.',
        'translitEn': "Fa-idha afadtum min 'Arafatin fadhkurullaha 'indal-Mash'aril-Haram.",
        'referenceEn': 'Surah Al-Baqarah (2:198)',
        'explanationEn': 'This is the only verse in the Quran that names Arafat directly, commanding pilgrims to stand and remember Allah there before departing toward Muzdalifah.',
        'explanationAr': 'هذه هي الآية الوحيدة في القرآن التي تسمي عرفة صراحةً، وتأمر الحجاج بالوقوف وذكر الله فيها قبل الانصراف إلى المزدلفة.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ عَبْدِ الرَّحْمَنِ بْنِ يَعْمَرَ رَضِيَ اللَّهُ عَنْهُ أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ قَالَ: «الْحَجُّ عَرَفَةُ...»',
          'translitEn': 'An Abdir-Rahmani-bni Ya\'mara radiya-allahu anhu anna-nabiyya salla-allahu alayhi wa sallama qala: Al-Hajju Arafah...',
          'referenceEn': 'Tirmidhi 889, Sunan Abi Dawud 1949',
          'textEn': 'Abdur-Rahman ibn Ya\'mar reported: The Prophet (ﷺ) said: "Hajj is Arafah. Whoever arrives before Fajr prayer on the night of Muzdalifah has completed his Hajj."',
          'explanationEn': 'Standing at Arafat is the single non-negotiable pillar (Rukn) of Hajj without which Hajj is invalid.',
          'sourceBook': 'Jami\' at-Tirmidhi',
          'sourceBookDesc': 'One of the six major Hadith books, compiled by Imam Abu Isa at-Tirmidhi.'
        },
        {
          'textAr': 'عَنْ عَمْرِو بْنِ شُعَيْبٍ عَنْ أَبِيهِ عَنْ جَدِّهِ أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ قَالَ: «خَيْرُ الدُّعَاءِ دُعَاءُ يَوْمِ عَرَفَةَ»',
          'translitEn': 'An Amri-bni Shu\'aybin an abeehi an jaddihi anna-nabiyya salla-allahu alayhi wa sallama qala: Khayru-d-du\'a\'i du\'a\'u yawmi Arafah.',
          'referenceEn': 'Jami\' at-Tirmidhi 3585',
          'textEn': 'Amr ibn Shuayb narrated from his father, from his grandfather, that the Prophet (ﷺ) said: "The best of supplications is the supplication on the Day of Arafah."',
          'explanationEn': 'Stresses the unique spiritual power of the supplications made during the afternoon of Arafah.',
          'sourceBook': 'Jami\' at-Tirmidhi',
          'sourceBookDesc': 'Hadith collection containing valuable classifications and details on chains of narration.'
        }
      ],
      'duas': [
        {
          'title': 'The Supreme Dua of Arafah',
          'arabic': 'لا إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
          'translit': 'La ilaha illallahu wahdahu la sharika lahu, lahul-mulku wa lahul-hamdu, wa huwa \'ala kulli shay\'in qadir.',
          'meaningEn': 'There is no deity worthy of worship except Allah, alone without partner. To Him belongs sovereignty and praise, and He has power over all things.',
          'meaningAr': 'أفضل ما قال النبي صلى الله عليه وسلم والنبيون من قبله عشية عرفة: التوحيد والتمجيد لله وحده.',
        },
        {
          'title': 'Sincere Repentance Prayer',
          'arabic': 'اللَّهُمَّ إِنِّي ظَلَمْتُ نَفْسِي ظُلْمًا كَثِيرًا وَلا يَغْفِرُ الذُّنُوبَ إِلاَّ أَنْتَ فَاغْفِرْ لِي مَغْفِرَةً مِنْ عِنْدِكَ',
          'translit': 'Allahumma inni dhalamtu nafsi dhulman katheeraw-wa la yaghfiru-dh-dhunuba illa anta faghfir li maghfiratam-min \'indik',
          'meaningEn': 'O Allah, I have wronged myself greatly, and none forgives sins except You, so grant me forgiveness from You.',
          'meaningAr': 'دعاء بالاستغفار وطلب التوبة والرحمة.',
        }
      ]
    },

    'muzdalifah': {
      'titleEn': 'Muzdalifah (Night of 10th Dhul Hijjah)',
      'titleAr': 'المزدلفة (ليلة العاشر من ذي الحجة)',
      'day': 'Night following Arafah (9th-10th Dhul Hijjah)',
      'dayAr': 'ليلة ١٠ ذو الحجة - المبيت بالمزدلفة',
      'overviewEn': 'Immediately after sunset on 9th Dhul Hijjah, pilgrims travel from Arafat to Muzdalifah without praying Maghrib at Arafat. Upon arrival in Muzdalifah, Maghrib and Isha are prayed together combined and shortened (Jam\' al-Ta\'khir). Pilgrims spend the night under the open sky, resting, performing Fajr at twilight, and collecting pebbles for Rami.',
      'overviewAr': 'بعد غروب شمس يوم عرفة مباشرة، ينطلق الحجاج إلى المزدلفة بهدوء وسكينة، ولا يصلون المغرب بعرفة. عند الوصول للمزدلفة يصلون المغرب ثلاث ركعات والعشاء ركعتين جمع تأخير بأذان وإقامتين. ويبيتون الليل تحت السماء، ثم يصلون الفجر بالمشعر الحرام ويجمعون الجمار.',
      'overviewArTranslit': "Ba'da ghuroobi shamsi yawmi 'Arafata mubasharatan, yantaliqul-hujjaju ilal-Muzdalifati bi-hudooin wa sakeenah, wa la yusalloonal-maghriba bi-'Arafah. 'Indal-wusooli lil-Muzdalifati yusalloonal-maghriba thalatha rak'aatin wal-'isha'a rak'atayni jam'a ta'kheerin bi-adhanin wa iqamatayn. Wa yabeetoonal-layla tahtas-sama', thumma yusalloonal-fajra bil-mash'aril-harami wa yajma'oonal-jimar.",
      'overviewArMeaning': "Immediately after the sunset of the Day of Arafah, pilgrims depart for Muzdalifah with calmness and serenity, and they do not pray Maghrib at Arafat. Upon arrival in Muzdalifah, they pray Maghrib (three units) and Isha (two units) combined (at the later time) and shortened with one Adhan and two Iqamahs. They spend the night under the open sky, then pray Fajr at Al-Mash'ar al-Haram and collect stoning pebbles.",
      'actionDetails': [
        {
          'title': 'Depart Arafat calmly after sunset without praying Maghrib.',
          'details': 'Once the sun sets, leave Arafat in a calm and dignified manner. Do not pray Maghrib until you reach Muzdalifah, even if you are delayed.',
          'glossary': [
            {'term': 'Muzdalifah', 'meaning': 'An open area near Makkah where pilgrims spend the night after departing Arafat.'}
          ]
        },
        {
          'title': 'Pray Maghrib and Isha combined at Muzdalifah.',
          'details': 'Pray Maghrib (3 Rakat) and Isha (shortened to 2 Rakat) combined (Jam\' al-Ta\'khir) during Isha time with 1 Adhan and 2 separate Iqamahs.',
          'glossary': [
            {'term': 'Jam\' al-Ta\'khir', 'meaning': 'Combining two prayers in the later prayer\'s time.'}
          ]
        },
        {
          'title': 'Collect pebbles for stoning (Rami).',
          'details': 'Collect small pebbles (around the size of a chickpea/bean) from Muzdalifah. You need 7 pebbles for the 10th, and 21 pebbles for each of the subsequent days.',
          'glossary': [
            {'term': 'Rami', 'meaning': 'The ritual of throwing pebbles at the stone pillars in Mina.'}
          ]
        },
        {
          'title': 'Spend the night sleeping under the open sky.',
          'details': 'Mabeet (staying the night) at Muzdalifah is an obligatory duty (Wajib). Spend the night resting under the open sky in preparation for the busy day of Eid.',
          'glossary': [
            {'term': 'Mabeet', 'meaning': 'Staying overnight in a designated location as a part of Hajj.'},
            {'term': 'Wajib', 'meaning': 'An obligatory ritual in Hajj, omission requires animal sacrifice but Hajj remains valid.'}
          ]
        },
        {
          'title': 'Offer Fajr early at twilight, make Dua, and depart for Mina before sunrise.',
          'details': 'Offer Fajr prayer at its earliest time. Stand at the sacred monument (Al-Mash\'ar al-Haram) making intense Duas until the sky becomes bright, then depart for Mina before the sun rises.',
          'glossary': [
            {'term': 'Al-Mash\'ar al-Haram', 'meaning': 'The sacred site/monument in Muzdalifah where pilgrims stand to make Dua.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'فَإِذَا أَفَضْتُم مِّنْ عَرَفَاتٍ فَاذْكُرُوا اللَّهَ عِندَ الْمَشْعَرِ الْحَرَامِ ۖ وَاذْكُرُوهُ كَمَا هَدَاكُمْ وَإِن كُنتُم مِّن قَبْلِهِ لَمِنَ الضَّالِّينَ',
        'referenceAr': 'سورة البقرة - الآية ١٩٨',
        'textEn': 'Then when you depart from Arafat, remember Allah at al-Mash\'ar al-Haram. And remember Him as He has guided you, for indeed, you were before that among those astray.',
        'translitEn': "Fa-idha afadtum min 'Arafatin fadhkurullaha 'indal-Mash'aril-Haram, wadhkuruhu kama hadakum wa in kuntum min qablihi laminal-dallin.",
        'referenceEn': 'Surah Al-Baqarah (2:198)',
        'explanationEn': 'Allah explicitly orders pilgrims departing from Arafat to stop and engage in His Remembrance at Al-Mash\'ar Al-Haram in Muzdalifah.',
        'explanationAr': 'تأمر الآية الكريمة بذكر الله عند المشعر الحرام بالمزدلفة فور الإفاضة من عرفات.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ عَبْدِ اللَّهِ بْنِ مَسْعُودٍ رَضِيَ اللَّهُ عَنْهُ قَالَ: مَا رَأَيْتُ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ صَلَّى صَلاَةً إِلاَّ لِوَقْتِهَا إِلاَّ صَلاَتَيْنِ: جَمَعَ بَيْنَ الْمَغْرِبِ وَالْعِشَاءِ بِجَمْعٍ (الْمُزْدَلِفَةِ)...',
          'translitEn': 'An Abdillahi-bni Mas\'udin radiya-allahu anhu qala: Ma ra\'aytu rasula-llahi salla-allahu alayhi wa sallama salla salatan illa liwaqtiha illa salatayni: jama\'a bayna-l-maghribi wal-isha\'i bi-Jam\'in...',
          'referenceEn': 'Sahih al-Bukhari 1675, Sahih Muslim 1280',
          'textEn': 'Ibn Mas\'ud reported: "I never saw the Messenger of Allah (ﷺ) offer any prayer out of its time except two: He combined Maghrib and Isha at Muzdalifah, and he offered Fajr prayer on that day earlier than its usual time (at twilight)."',
          'explanationEn': 'Highlights the mandatory sunnah of delaying Maghrib until arriving at Muzdalifah and offering Fajr early at twilight.',
          'sourceBook': 'Sahih al-Bukhari & Sahih Muslim',
          'sourceBookDesc': 'Authentic compilations forming the dual basis of Sunni legal consensus.'
        },
        {
          'textAr': 'عَنْ أُسَامَةَ بْنِ زَيْدٍ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ سَارَ حِينَ دَفَعَ مِنْ عَرَفَةَ بِالْعَنَقِ فَإِذَا وَجَدَ فَجْوَةً نَصَّ',
          'translitEn': 'An Usamata-bni Zaydin radiya-allahu anhuma anna-nabiyya salla-allahu alayhi wa sallama sara heena dafa\'a min Arafata bil-anaqi fa-idha wajada fajwatan nassa.',
          'referenceEn': 'Sahih al-Bukhari 1666',
          'textEn': 'Usama ibn Zayd narrated that the Prophet (ﷺ) walked at a moderate pace while departing from Arafat, but when he found space, he went fast.',
          'explanationEn': 'Underlines the Sunnah of traveling calmly with composure, avoiding running or pushing others in crowds.',
          'sourceBook': 'Sahih al-Bukhari',
          'sourceBookDesc': 'Compiled by Imam Bukhari, the most trusted authority on Prophetic narrations.'
        }
      ],
      'duas': [
        {
          'title': 'Dua at Al-Mash\'ar Al-Haram',
          'arabic': 'اللَّهُمَّ كَمَا وَقَفْتَنَا فِيهِ وَأَرَيْتَنَا إِيَّاهُ فَوَفِّقْنَا لِذِكْرِكَ كَمَا هَدَيْتَنَا، وَاغْفِرْ لَنَا وَارْحَمْنَا كَمَا وَعَدْتَنَا',
          'translit': 'Allahumma kama waqaftana fihi wa araytana iyyahu fawaffiqna lidhikrika kama hadaytana, waghfir lana warhamna kama wa’adtana.',
          'meaningEn': 'O Allah, just as You enabled us to stand here and showed it to us, grant us success in remembering You as You guided us, and forgive us and have mercy on us as You promised us.',
          'meaningAr': 'دعاء الثناء والاستغفار عند المشعر الحرام بالمزدلفة قبل طلوع الشمس.',
        },
        {
          'title': 'Dua of Forgiveness and Ease',
          'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
          'translit': 'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina \'adhaban-nar.',
          'meaningEn': 'Our Lord, grant us good in this world and good in the Hereafter and protect us from the punishment of the Fire.',
          'meaningAr': 'دعاء شامل بالخير والسلامة من العذاب.'
        }
      ]
    },

    'rami1': {
      'titleEn': 'Rami al-Jamarat (10th Dhul Hijjah - Yawm an-Nahr)',
      'titleAr': 'رمي جمرة العقبة (١٠ ذو الحجة - يوم النحر)',
      'day': '10th Dhul Hijjah (Eid al-Adha)',
      'dayAr': '١٠ ذو الحجة (يوم عيد الأضحى المبارك)',
      'overviewEn': 'On the morning of 10th Dhul Hijjah (Yawm an-Nahr), pilgrims return from Muzdalifah to Mina to pelt only the largest pillar, Jamarat al-Aqabah (Al-Jamrah Al-Kubra). Pilgrims throw 7 pebbles individually while saying "Allahu Akbar" with each throw. This symbolizes rejecting Shaytan and remaining steadfast in faith.',
      'overviewAr': 'صباح يوم العاشر من ذي الحجة (يوم النحر)، يتجه الحجاج إلى منى لرمي جمرة العقبة الكبرى فقط بسبع حصيات متعاقبة، يكبر الحاج مع كل حصاة قائلًا: "الله أكبر"، مقطعاً التلبية مع أول حصاة، اقتداءً بإبراهيم عليه السلام في دحر الشيطان.',
      'overviewArTranslit': "Sabaha yawmil-'ashiri min Dhil-Hijjah (yawman-nahr), yatawajjahul-hujjaju ila Mina liramyi Jamratil-'Aqabatil-Kubra faqat bi-sab'i hasayaatin muta'aqibah, yukabbirul-haajju ma'a kulli hasatin qa'ilan: 'Allahu Akbar', muqti'anit-talbiyata ma'a awwali hasah, iqtida'an bi-Ibraheema 'alayhis-salamu fee dahris-shaytan.",
      'overviewArMeaning': "On the morning of the tenth of Dhul Hijjah (the Day of Sacrifice), pilgrims head to Mina to stone only the largest pillar (Jamarat al-Aqabah) with seven consecutive pebbles, declaring 'Allahu Akbar' (Allah is the Greatest) with each pebble, stopping the Talbiyah with the first pebble, following the example of Ibrahim (peace be upon him) in rejecting the devil.",
      'actionDetails': [
        {
          'title': 'Arrive in Mina from Muzdalifah in the morning.',
          'details': 'Walk or take transport to Mina during the forenoon (Dhuha) of the 10th of Dhul Hijjah.',
          'glossary': [
            {'term': 'Dhuha', 'meaning': 'The forenoon period between sunrise and noon.'}
          ]
        },
        {
          'title': 'Pelt ONLY the Big Pillar (Jamarat al-Aqabah) with 7 pebbles.',
          'details': 'Walk to the Jamarat bridge. Stand facing the large pillar and throw 7 pebbles one by one. Do not pelt the other two pillars on this day.',
          'glossary': [
            {'term': 'Jamarat al-Aqabah', 'meaning': 'The largest of the three pillars representing the location where Shaytan was resisted by Ibrahim (AS).'}
          ]
        },
        {
          'title': 'Say "Allahu Akbar" with every single thrown pebble.',
          'details': 'Raise your right hand for each throw and recite "Allahu Akbar" (Allah is the Greatest) while throwing. Ensure the pebble hits the pillar or lands in the surrounding basin.',
          'glossary': [
            {'term': 'Allahu Akbar', 'meaning': 'The declaration that Allah is the Greatest.'}
          ]
        },
        {
          'title': 'Stop reciting Talbiyah upon throwing the first pebble.',
          'details': 'The continuous recitation of the Talbiyah (which started when entering Ihram) is officially stopped when the very first pebble is thrown at Jamarat al-Aqabah.',
          'glossary': [
            {'term': 'Talbiyah', 'meaning': 'The chant: Labbayk Allahumma Labbayk.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'وَمَن يُعَظِّمْ شَعَائِرَ اللَّهِ فَإِنَّهَا مِن تَقْوَى الْقُلُوبِ',
        'referenceAr': 'سورة الحج - الآية ٣٢',
        'textEn': 'And whoever honors the symbols of Allah - indeed, it is from the piety of hearts.',
        'translitEn': 'Wa may-yu\'azzim sha\'a\'irallahi fa-innaha min taqwal-qulub.',
        'referenceEn': 'Surah Al-Hajj (22:32)',
        'explanationEn': 'The act of stoning is preserved through the Sunnah. This verse establishes the broader principle that honouring the symbols and rites Allah has appointed for Hajj is an act of piety.',
        'explanationAr': 'رمي الجمار وتعظيم مناسك الحج من دلالات تقوى القلوب وإجلال أمر الله.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ جَابِرٍ رَضِيَ اللَّهُ عَنْهُ قَالَ: «رَأَيْتُ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ يَرْمِي الْجَمْرَةَ ضُحًى يَوْمَ النَّحْرِ، وَهُوَ عَلَى نَاقَتِهِ يَقُولُ: لِتَأْخُذُوا مَنَاسِكَكُمْ...»',
          'translitEn': 'An Jabir radiya-allahu anhu qala: Ra\'aytu-nabiyya salla-allahu alayhi wa sallama yarmi-l-jamrata duhan yawma-n-nahri wa huwa ala naqatihi yaqul: Lita\'khudhu manasikakum...',
          'referenceEn': 'Sahih Muslim 1297',
          'textEn': 'Jabir reported: "I saw the Prophet (ﷺ) throwing pebbles at Jamarat al-Aqabah in the forenoon on the Day of Sacrifice, saying: Take your rituals from me, for I do not know whether I will perform Hajj after this Hajj of mine."',
          'explanationEn': 'This establishes the timing (Dhuha) and fundamental rule that all Hajj rituals must mirror the Prophet’s demonstration.',
          'sourceBook': 'Sahih Muslim',
          'sourceBookDesc': 'Authentic collection of Hadith compiled by Imam Muslim.'
        },
        {
          'textAr': 'عَنِ ابْنِ عَبَّاسٍ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ قَالَ فِي حَجِّهِ: «عَلَيْكُمْ بِحَصَى الْخَذْفِ...»',
          'translitEn': 'An ibni Abbas radiya-allahu anhuma anna-nabiyya salla-allahu alayhi wa sallama qala fi hajjihi: Alaykum bihasal-khadhfi...',
          'referenceEn': 'Sahih Muslim 1298',
          'textEn': 'Ibn Abbas reported that the Prophet (ﷺ) said: "Pelt with pebbles the size of clay-balls (for stoning) and avoid excess in religion..."',
          'explanationEn': 'Warns against using overly large stones or showing aggression, defining the proper size of pebbles to be used (size of a bean).',
          'sourceBook': 'Sahih Muslim',
          'sourceBookDesc': 'One of the six major books of Hadith compiled by Imam Muslim.'
        }
      ],
      'duas': [
        {
          'title': 'Dua with each pebble thrown',
          'arabic': 'اللَّهُ أَكْبَرُ، اللَّهُمَّ اجْعَلْهُ حَجًّا مَبْرُورًا وَذَنْبًا مَغْفُورًا',
          'translit': 'Allahu Akbar, Allahumma-j’alhu hajjan mabruran wa dhanban maghfura.',
          'meaningEn': 'Allah is the Greatest. O Allah, make it an accepted Hajj and a forgiven sin.',
          'meaningAr': 'التكبير عند رمي كل حصاة والدعاء بالقبول ومغفرة الذنوب.',
        },
        {
          'title': 'Short praise upon each throw',
          'arabic': 'اللَّهُ أَكْبَرُ رَغْمًا لِلشَّيْطَانِ وَرِضًى لِلرَّحْمَنِ',
          'translit': 'Allahu Akbar, raghman lish-shaytani wa ridan lir-Rahman',
          'meaningEn': 'Allah is the Greatest, in rejection of Shaytan and in pursuit of the Merciful\'s pleasure.',
          'meaningAr': 'ذكر الله تكبيراً لدحر الشيطان والتقرب للرحمن.'
        }
      ]
    },

    'qurbani': {
      'titleEn': 'Qurbani (Hady Sacrifice) & Halq / Taqsir',
      'titleAr': 'الهدي والحلق أو التقصير',
      'day': '10th Dhul Hijjah (Yawm an-Nahr)',
      'dayAr': '١٠ ذو الحجة (يوم النحر)',
      'overviewEn': 'After Rami on the 10th of Dhul Hijjah, pilgrims performing Hajj Tamattu or Qiran offer the Hady (animal sacrifice). Afterwards, male pilgrims shave their heads completely (Halq - preferred) or trim hair evenly (Taqsir). Female pilgrims trim a fingertip length of their hair. At this point, Tahallul al-Asghar (first partial deconsecration) is achieved.',
      'overviewAr': 'بعد رمي جمرة العقبة يوم النحر، يقوم المتمتع والمقرن بذبْح الهدي. ثم يحلق الرجل رأسه (وهو الأفضل) أو يقصره، وتقصر المرأة من أطراف شعرها قدر أنملة (حوالي ٢ سم). وبذلك يتحلل الحاج التحلل الأول (التحلل الأصغر) فيحل له كل شيء حرم عليه بالإحرام إلا النساء.',
      'overviewArTranslit': "Ba'da ramyi Jamratil-'Aqabati yawman-nahr, yaqoomul-mutamatti'u wal-muqrinu bidhabhil-hady. Thumma yahliqur-rajulu ra'sahu (wa huwal-afdal) aw yuqassiruh, wa tuqassirul-mar'atu min atraafi sha'riha qadra anmula (hawalay 2 cm). Wa bidhalika yatahallalul-haajjut-tahallulal-awwal (at-tahallulal-asghar) fayahi-llu lahu kullu shay'in hurrima 'alayhi bil-ihraami illan-nisa'.",
      'overviewArMeaning': "After stoning Jamarat al-Aqabah on the Day of Sacrifice, pilgrims performing Tamattu' and Qiran offer the animal sacrifice (Hady). Then, the man shaves his head (which is preferred) or trims it, and the woman trims the ends of her hair by a fingertip length (about 2 cm). With this, the pilgrim achieves the first deconsecration (al-Tahallul al-Asghar), making everything permissible that was prohibited during Ihram, except marital relations.",
      'actionDetails': [
        {
          'title': 'Slaughter the Hady (sheep, goat, or 1/7 of camel/cow).',
          'details': 'Offer the animal sacrifice (usually arranged beforehand through electronic vouchers). This is obligatory for Tamattu\' and Qiran pilgrims.',
          'glossary': [
            {'term': 'Hady', 'meaning': 'The sacrificial animal offered by pilgrims as gratitude during Hajj.'},
            {'term': 'Qurbani', 'meaning': 'The act of slaughtering a sacrifice.'}
          ]
        },
        {
          'title': 'Men: Shave head completely (Halq) or trim hair evenly (Taqsir).',
          'details': 'Shaving completely is highly recommended. Barbers are available around Mina and Makkah. If you trim, ensure it is cut evenly all around your head.',
          'glossary': [
            {'term': 'Halq', 'meaning': 'Shaving the head completely.'},
            {'term': 'Taqsir', 'meaning': 'Trimming/shortening the hair.'}
          ]
        },
        {
          'title': 'Women: Trim a fingertip length from the ends of hair.',
          'details': 'Women gather their hair together and clip about a fingertip\'s length (1.5 to 2 cm) from the ends.',
          'glossary': [
            {'term': 'Fingertip length', 'meaning': 'The mandatory measure of trimming hair for women.'}
          ]
        },
        {
          'title': 'Attain Tahallul al-Asghar and change out of Ihram clothes.',
          'details': 'Once you pelt the Jamrah and shave/trim your hair, you enter the state of partial deconsecration (Tahallul al-Asghar). You can now wear regular sewn clothes and apply perfume.',
          'glossary': [
            {'term': 'Tahallul al-Asghar', 'meaning': 'The first stage of deconsecration where all Ihram prohibitions are lifted except marital relations.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'وَفَدَيْنَاهُ بِذِبْحٍ عَظِيمٍ',
        'referenceAr': 'سورة الصافات - الآية ١٠٧',
        'textEn': 'And We ransomed him with a great sacrifice.',
        'translitEn': "Wa fadaynahu bidhib-hin 'azim.",
        'referenceEn': 'Surah As-Saffat (37:107)',
        'explanationEn': 'This verse is the origin of the Qurbani itself: after Ibrahim (AS) and his son Ismail (AS) submitted fully to Allah\'s command, Allah ransomed Ismail\'s life with an animal sacrifice. Every Hady offered during Hajj Tamattu\' or Qiran re-enacts that ransom in gratitude.',
        'explanationAr': 'هذه الآية هي أصل مشروعية الأضحية والهدي، حيث فدى الله إسماعيل عليه السلام بذبح عظيم بعد امتثاله وأبيه لأمر الله.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ أَبِي هُرَيْرَةَ رَضِيَ اللَّهُ عَنْهُ قَالَ: قَالَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ: «اللَّهُمَّ اغْفِرْ لِلْمُحَلِّقِينَ»، قَالُوا: وَلِلْمُقَصِّرِينَ يَا رَسُولَ اللَّهِ؟...',
          'translitEn': 'An Abi Hurairah radiya-allahu anhu qala: Qala rasulu-llahi salla-allahu alayhi wa sallama: Allahumma-ghfir lil-muhalliqina. Qalu: Wa lil-muqassirina ya rasula-llahi?...',
          'referenceEn': 'Sahih al-Bukhari 1727 & Sahih Muslim 1301',
          'textEn': 'Abu Hurairah reported: The Messenger of Allah (ﷺ) prayed: "O Allah, forgive those who shave their heads!" They asked: "And those who shorten, O Messenger of Allah?" He repeated: "O Allah, forgive those who shave!" They asked again, and on the third or fourth time he added: "And those who shorten."',
          'explanationEn': 'Demonstrates the superior reward for men who shave their heads completely (Halq) compared to trimming.',
          'sourceBook': 'Sahih al-Bukhari & Sahih Muslim',
          'sourceBookDesc': 'The standard of authentic prophetic statements.'
        },
        {
          'textAr': 'عَنْ أَنَسِ بْنِ مَالِكٍ رَضِيَ اللَّهُ عَنْهُ أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ أَتَى مِنًى فَنَحَرَ ثُمَّ حَلَقَ',
          'translitEn': 'An Anasib-ni Malik radiya-allahu anhu anna-nabiyya salla-allahu alayhi wa sallama ata Mina fanahara thumma halaqa.',
          'referenceEn': 'Sahih Muslim 1302',
          'textEn': 'Anas reported: "The Messenger of Allah (ﷺ) came to Mina, pelted the Jamrah, slaughtered his sacrifice, and then shaved his head."',
          'explanationEn': 'Establishes the chronological sequence of rituals on the Day of Eid: Pelting, Sacrifice, then Shaving/Trimming.',
          'sourceBook': 'Sahih Muslim',
          'sourceBookDesc': 'Authentic collection of Hadith compiled by Imam Muslim.'
        }
      ],
      'duas': [
        {
          'title': 'Dua Upon Shaving/Trimming Hair',
          'arabic': 'الْحَمْدُ لِلَّهِ عَلَى مَا هَدَانَا، اللَّهُمَّ ثَبِّتْنِي عَلَى الْهُدَى وَاغْفِرْ لِي وَلِوَالِدَيَّ',
          'translit': 'Alhamdu lillahi \'ala ma hadana, Allahumma thabbitni \'alal-huda waghfir li wa li-walidayya',
          'meaningEn': 'Praise be to Allah for guiding us. O Allah, keep me firm upon guidance and forgive me and my parents.',
          'meaningAr': 'حمد الله على توفيقه لإتمام النسك والدعاء بالثبات والمغفرة.',
        },
        {
          'title': 'Dua upon offering Sacrifice',
          'arabic': 'بِسْمِ اللَّهِ وَاللَّهُ أَكْبَرُ، اللَّهُمَّ تَقَبَّلْ مِنِّي',
          'translit': 'Bismillahi wallahu Akbar, Allahumma taqabbal minni',
          'meaningEn': 'In the name of Allah, Allah is the Greatest. O Allah, accept it from me.',
          'meaningAr': 'التسمية والتكبير عند تقديم القربان لله تعالى.'
        }
      ]
    },

    'tawaf_ifadah': {
      'titleEn': 'Tawaf al-Ifadah (Tawaf al-Ziyarah) & Sa’i',
      'titleAr': 'طواف الإفاضة والسعي',
      'day': '10th Dhul Hijjah or Days of Tashreeq',
      'dayAr': '١٠ ذو الحجة أو أيام التشريق',
      'overviewEn': 'Tawaf al-Ifadah is a core, mandatory pillar (Rukn) of Hajj without which Hajj remains incomplete. Pilgrims travel from Mina to Makkah to circumambulate the Kaaba 7 times. After Tawaf, pilgrims perform Sa\'i between Safa and Marwah (for Tamattu pilgrims and those who did not perform Sa\'i earlier). Completing this grants Tahallul al-Akbar (complete deconsecration).',
      'overviewAr': 'طواف الإفاضة هو ركن من أركان الحج لا يتم الحج إلا به. يتجه الحاج إلى مكة للطواف حول الكعبة ٧ أشواط، ثم يصلي ركعتين خلف المقام، ويسعى بين الصفا والمروة ٧ أشواط (للمتمتع ولمن لم يسعَ مع طواف القدوم). وبتمام طواف الإفاضة والسعي يتحلل الحاج التحلل الأكبر (الكامل) فيحل له كل شيء حتى النساء.',
      'overviewArTranslit': "Tawaful-ifadah huwa ruknum-min arkaanil-hajji la yatimmul-hajju illa bih. Yatawajjahul-haajju ila Makkata lit-tawaafi hawlal-Ka'bati sab'ata ashwaat, thumma yusallee rak'atayni khalfal-maqam, wa yas'a baynas-Safa wal-Marwata sab'ata ashwaatin (lil-mutamatti'i wa liman lam yas'a ma'a tawafil-qudoom). Wa bitamami tawafil-ifadah was-sa'yi yatahallalul-haajjut-tahallulal-akbar (al-kaamil) fayahi-llu lahu kullu shay'in hattan-nisa'.",
      'overviewArMeaning': "Tawaf al-Ifadah is a pillar among the pillars of Hajj, without which Hajj is not complete. The pilgrim heads to Makkah to circumambulate the Kaaba seven times, then performs two units of prayer behind the Station (Maqam Ibrahim), and walks between Safa and Marwah seven times (for those performing Tamattu' and those who did not perform Sa'i with Tawaf al-Qudum). By completing Tawaf al-Ifadah and Sa'i, the pilgrim achieves the major deconsecration (al-Tahallul al-Akbar), making everything permissible, including marital relations.",
      'actionDetails': [
        {
          'title': 'Perform 7 circuits around the Kaaba (Tawaf al-Ifadah).',
          'details': 'Proceed to the Grand Mosque in Makkah and circumambulate the Kaaba seven times counter-clockwise. Men do not need to uncover their shoulders (Idtiba) or walk briskly (Raml) on this Tawaf.',
          'glossary': [
            {'term': 'Tawaf al-Ifadah', 'meaning': 'The mandatory Hajj circumambulation around the Kaaba.'},
            {'term': 'Kaaba', 'meaning': 'The House of Allah.'}
          ]
        },
        {
          'title': 'Pray 2 Rakat behind Maqam Ibrahim.',
          'details': 'After completing 7 circuits, offer 2 units of prayer behind Maqam Ibrahim if possible, otherwise anywhere in Al-Masjid al-Haram.',
          'glossary': [
            {'term': 'Maqam Ibrahim', 'meaning': 'The standing place of Prophet Abraham.'}
          ]
        },
        {
          'title': 'Drink Zamzam water and make Dua.',
          'details': 'Go to the Zamzam drinking taps. Drink Zamzam water while standing, and make supplication.',
          'glossary': [
            {'term': 'Zamzam', 'meaning': 'The blessed well and water source in Makkah.'}
          ]
        },
        {
          'title': 'Perform Sa\'i between Safa and Marwah.',
          'details': 'Perform 7 laps of Sa\'i between Mount Safa and Mount Marwah. This is required for Tamattu\' pilgrims and those Qiran/Ifrad pilgrims who did not perform it after Tawaf al-Qudum.',
          'glossary': [
            {'term': 'Sa\'i', 'meaning': 'Walking seven times between the two hills.'}
          ]
        },
        {
          'title': 'Attain Tahallul al-Akbar (complete deconsecration).',
          'details': 'Once you complete this Tawaf (and Sa\'i where necessary), you achieve the state of complete deconsecration (Tahallul al-Akbar). All Ihram restrictions, including marital relations, are now lifted.',
          'glossary': [
            {'term': 'Tahallul al-Akbar', 'meaning': 'The second and complete stage of exiting Ihram.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'ثُمَّ لْيَقْضُوا تَفَثَهُمْ وَلْيُوفُوا نُذُورَهُمْ وَلْيَطَّوَّفُوا بِالْبَيْتِ الْعَتِيقِ',
        'referenceAr': 'سورة الحج - الآية ٢٩',
        'textEn': 'Then let them end their untidiness and fulfil their vows and perform Tawaf around the Ancient House.',
        'translitEn': "Thummal-yaqdu tafathahum wal-yufu nudhurahum wal-yattawwafu bil-Baytil-'Atiq.",
        'referenceEn': 'Surah Al-Hajj (22:29)',
        'explanationEn': 'This is the direct command to perform Tawaf. Tawaf al-Ifadah is the occasion on which every school of Islamic law agrees this verse is fulfilled as an absolute pillar (Rukn) of Hajj.',
        'explanationAr': 'هذا هو الأمر المباشر بالطواف، وطواف الإفاضة هو الركن الذي يتحقق فيه هذا الأمر، ولا يجزئ عنه دم إن تُرك.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ عَائِشَةَ رَضِيَ اللَّهُ عَنْهَا قَالَتْ: «أَفَاضَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ مِنْ آخِرِ يَوْمِهِ حِينَ صَلَّى الظُّهْرَ، ثُمَّ رَجَعَ إِلَى مِنًى»',
          'translitEn': 'An Aisha radiya-allahu anha qalat: Afada rasulu-llahi salla-allahu alayhi wa sallama min akhiri yawmihi heena salla-d-Duhra thumma raja\'a ila Mina.',
          'referenceEn': 'Sahih al-Bukhari 1733, Sahih Muslim 1218',
          'textEn': 'Aisha reported: "The Messenger of Allah (ﷺ) performed Tawaf al-Ifadah on the latter part of the day (10th) after praying Dhuhr, then he returned to Mina."',
          'explanationEn': 'Confirms that Tawaf al-Ifadah is performed on the 10th of Dhul Hijjah before returning to Mina for Tashreeq nights.',
          'sourceBook': 'Sahih al-Bukhari & Sahih Muslim',
          'sourceBookDesc': 'Highly authentic books containing verified reports of the Prophet\'s Farewell Pilgrimage.'
        },
        {
          'textAr': 'عَنِ ابْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ طَافَ يَوْمَ النَّحْرِ ثُمَّ رَجَعَ فَصَلَّى الظَّهْرَ بِمِنى',
          'translitEn': 'An ibni Umar radiya-allahu anhuma anna rasula-llahi salla-allahu alayhi wa sallama tafa yawman-nahri thumma raja\'a fasallad-Duhra bi-Mina.',
          'referenceEn': 'Sahih al-Bukhari 1734',
          'textEn': 'Ibn Umar reported: "The Messenger of Allah (ﷺ) performed Tawaf on the Day of Sacrifice (10th) and then returned and offered Dhuhr prayer in Mina."',
          'explanationEn': 'Demonstrates that the Prophet ﷺ completed the Tawaf al-Ifadah on the 10th of Dhul Hijjah itself, returning to Mina to lead the congregation.',
          'sourceBook': 'Sahih al-Bukhari',
          'sourceBookDesc': 'Compiled by Imam Bukhari, the most trusted authority on Prophetic narrations.'
        }
      ],
      'duas': [
        {
          'title': 'Dua during Tawaf al-Ifadah',
          'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
          'translit': 'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina \'adhaban-nar.',
          'meaningEn': 'Our Lord, grant us good in this world and good in the Hereafter and protect us from the punishment of the Fire.',
          'meaningAr': 'ربنا منحنا الخير في الدنيا والآخرة ونجنا من عذاب النار.',
        },
        {
          'title': 'Dua on Safa hill before Sa\'i',
          'arabic': 'أَبْدَأُ بِمَا بَدَأَ اللَّهُ بِهِ، إِنَّ الصَّفَا وَالْمَرْوَةَ مِن شَعَائِرِ اللَّهِ',
          'translit': 'Abda\'u bima bada\'allahu bihi. Innas-Safa wal-Marwata min sha\'a\'irillah.',
          'meaningEn': 'I begin with that which Allah began with. Indeed, Safa and Marwah are among the symbols of Allah.',
          'meaningAr': 'التكبير والبدء بالسعي اتباعاً للسنة المطهرة.'
        }
      ]
    },

    'rami_days': {
      'titleEn': 'Rami al-Jamarat (Days of Tashreeq - 11th, 12th, 13th)',
      'titleAr': 'رمي الجمار في أيام التشريق (١١، ١٢، ١٣ ذو الحجة)',
      'day': '11th, 12th, and optional 13th Dhul Hijjah',
      'dayAr': '١١ و١٢ و١٣ ذو الحجة - أيام التشريق',
      'overviewEn': 'Pilgrims remain in Mina during the Days of Tashreeq (11th, 12th, and optionally 13th Dhul Hijjah). Each afternoon AFTER Zawal (midday sun turn), pilgrims pelt all three Jamarat in order: Small (Al-Sugra), Medium (Al-Wusta), and Large (Al-Aqabah) with 7 pebbles each (21 total per day). Long supplications are made after the 1st and 2nd Jamarat.',
      'overviewAr': 'يقيم الحجاج بمنى أيام التشريق (١١، ١٢، و١٣ لمن تأخر). ويكون رمي الجمار الثلاث بعد زوال الشمس (بعد صلاة الظهر) كل يوم بترتيب: الجمرة الصغرى (٧ حصيات)، ثم الوسطى (٧ حصيات)، ثم العقبة الكبرى (٧ حصيات) بمجموع ٢١ حصاة يومياً. ويُسن الوقوف والدعاء الطويل بعد الصغرى والوسطى.',
      'overviewArTranslit': "Yuqeemul-hujjaju bi-Mina ayyamat-tashreeqi (11, 12, wa 13 liman ta'akhkhar). Wa yakoonu ramyu-jimarith-thalathi ba'da zawalis-shamsi (ba'da salatid-duhr) kullu yawmin bitarteeb: al-jamratus-sughra (7 hasayaat), thummal-wusta (7 hasayaat), thumma 'aqabatul-kubra (7 hasayaat) bimajmoo'i 21 hasatan yawmiyya. Wa yusannul-wuqoofu wad-du'a'ul-taweelu ba'das-sughra wal-wusta.",
      'overviewArMeaning': "Pilgrims stay in Mina during the Days of Tashreeq (11th, 12th, and 13th for those who delay departure). Stoning of the three pillars takes place after the decline of the sun (after Dhuhr prayer) each day in order: the Small Jamrah (seven pebbles), then the Medium Jamrah (seven pebbles), then the Large Jamrah (seven pebbles), totalling 21 pebbles daily. It is Sunnah to stand and make long supplications after the Small and Medium Jamarat.",
      'actionDetails': [
        {
          'title': 'Stay overnight in Mina during Tashreeq nights.',
          'details': 'Spend most of the night in your tent in Mina. This is a mandatory duty (Wajib) for all Tashreeq nights.',
          'glossary': [
            {'term': 'Days of Tashreeq', 'meaning': 'The 11th, 12th, and 13th of Dhul Hijjah spent in Mina.'},
            {'term': 'Mabeet', 'meaning': 'Staying the night in Mina.'}
          ]
        },
        {
          'title': 'Wait for Zawal (Dhuhr time) each day before starting Rami.',
          'details': 'Rami on the Days of Tashreeq can only be performed after the sun starts its decline (Zawal) at Dhuhr time. Stoning in the morning is invalid.',
          'glossary': [
            {'term': 'Zawal', 'meaning': 'Midday when the sun begins to decline from its peak.'}
          ]
        },
        {
          'title': 'Pelt the Small Jamrah and make a long Dua.',
          'details': 'Throw 7 pebbles one by one at the first (Small) pillar (Jamrah al-Sugra). Step aside, face the Qiblah, and make a long supplication with raised hands.',
          'glossary': [
            {'term': 'Jamrah al-Sugra', 'meaning': 'The first and smallest stoning pillar.'}
          ]
        },
        {
          'title': 'Pelt the Medium Jamrah and make a long Dua.',
          'details': 'Throw 7 pebbles one by one at the second (Medium) pillar (Jamrah al-Wusta). Step aside, face the Qiblah, and make another long supplication.',
          'glossary': [
            {'term': 'Jamrah al-Wusta', 'meaning': 'The middle stoning pillar.'}
          ]
        },
        {
          'title': 'Pelt the Large Jamrah and depart without stopping.',
          'details': 'Throw 7 pebbles one by one at the third (Large) pillar (Jamrah al-Aqabah). Depart immediately without stopping for Dua.',
          'glossary': [
            {'term': 'Jamrah al-Aqabah', 'meaning': 'The largest stoning pillar.'}
          ]
        },
        {
          'title': 'Option to depart Mina on the 12th before sunset (Ta\'ajjul).',
          'details': 'If you choose to leave early, you must pelt all three pillars on the 12th and depart Mina before sunset. If sunset catches you in Mina, you must stay until the 13th.',
          'glossary': [
            {'term': 'Ta\'ajjul', 'meaning': 'Hastening departure from Mina on the 12th of Dhul Hijjah.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'فَمَن تَعَجَّلَ فِي يَوْمَيْنِ فَلَا إِثْمَ عَلَيْهِ وَمَن تَأَخَّرَ فَلَا إِثْمَ عَلَيْهِ ۚ لِمَنِ اتَّقَىٰ ۗ وَاتَّقُوا اللَّهَ وَاعْلَمُوا أَنَّكُمْ إِلَيْهِ تُحْشَرُونَ',
        'referenceAr': 'سورة البقرة - الآية ٢٠٣',
        'textEn': 'Whoever hastens [his departure] in two days, there is no sin upon him; and whoever delays, there is no sin upon him - for him who fears Allah. And fear Allah and know that unto Him you will be gathered.',
        'translitEn': "Faman ta'ajjala fi yawmayni fala ithma 'alayh, wa man ta'akhkhara fala ithma 'alayhi limanit-taqa. Wattaqullaha wa'lamu annakum ilayhi tuhsharun.",
        'referenceEn': 'Surah Al-Baqarah (2:203)',
        'explanationEn': 'This verse gives the explicit permission pilgrims rely on to leave Mina early after the 12th (Ta\'ajjul) or stay for the 13th (Takhar).',
        'explanationAr': 'تبيح الآية التعجل في اليوم الثاني عشر أو التأخر لليوم الثالث عشر لمن اتقى الله.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ عَبْدِ اللَّهِ بْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّهُ كَانَ يَرْمِي الْجَمْرَةَ الدُّنْيَا بِسَبْعِ حَصَيَاتٍ، ثُمَّ يُكَبِّرُ عَلَى إِثْرِ كُلِّ حَصَاةٍ، ثُمَّ يَتَقَدَّمُ فَيُسْهِلُ فَيَقُومُ مُسْتَقْبِلَ الْقِبْلَةِ، فَيَقُومُ طَوِيلاً وَيَدْعُو وَيَرْفَعُ يَدَيْهِ...',
          'translitEn': 'An Abdillahi-bni Umar radiya-allahu anhuma annahu kana yarmi-l-jamrata-d-dunya bisab\'i hasayatin, thumma yukabbiru ala ithri kulli hasatin, thumma yataqaddamu fayushilu fayaqumu mustaqbila-l-qiblati, fayaqumu taweelan wa yad\'u wa yarfa\'u yadayhi...',
          'referenceEn': 'Sahih al-Bukhari 1751',
          'textEn': 'Narrated Ibn Umar: He used to stone the nearest Jamrah with 7 pebbles, saying Takbeer with each pebble. Then he would move forward, stand facing the Qiblah for a long time making Dua with raised hands... and say: "This is how I saw the Prophet (ﷺ) doing it."',
          'explanationEn': 'Details the Sunnah method of standing for prolonged Dua after the Small and Medium Jamarat during Tashreeq days.',
          'sourceBook': 'Sahih al-Bukhari',
          'sourceBookDesc': 'Authentic collection of Hadith compiled by Imam Al-Bukhari.'
        },
        {
          'textAr': 'عَنْ عَائِشَةَ رَضِيَ اللَّهُ عَنْهَا أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ أَخَّرَ الرَّمْيَ يَوْمَ النَّحْرِ حَتَّى زَالَتِ الشَّمْسُ',
          'translitEn': 'An Aisha radiya-allahu anha anna-nabiyya salla-allahu alayhi wa sallama akhara-r-ramya yawma-n-nahri hatta zalati-sh-shamsu.',
          'referenceEn': 'Sunan Abi Dawud 1949',
          'textEn': 'Aisha narrated: "The Prophet (ﷺ) delayed the stoning during the Days of Tashreeq until the sun had passed its meridian (Zawal)."',
          'explanationEn': 'Establishes that the legal time for stoning on the Days of Tashreeq starts at Zawal.',
          'sourceBook': 'Sunan Abi Dawud',
          'sourceBookDesc': 'One of the six major collections of Hadith, compiled by Imam Abu Dawud.'
        }
      ],
      'duas': [
        {
          'title': 'Dua Between Jamarat',
          'arabic': 'اللَّهُمَّ اغْفِرْ وَارْحَمْ، وَاعْفُ عَمَّا تَعْلَمُ، وَأَنْتَ الأَعَزُّ الأَكْرَمُ، اللَّهُمَّ آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
          'translit': 'Allahummaghfir warham, wa’fu \'amma ta’lam, wa antal-a’azzul-akram. Allahumma atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina \'adhaban-nar.',
          'meaningEn': 'O Allah forgive and have mercy, and pardon what You know, for You are the Most Mighty, Most Generous. O Allah grant us good in this world and the next and save us from the Fire.',
          'meaningAr': 'الدعاء والمناجاة الطويلة مستقبل القبلة بعد رمي الجمرة الصغرى والوسطى.',
        },
        {
          'title': 'Praise with each stoning',
          'arabic': 'اللَّهُ أَكْبَرُ، اللَّهُمَّ اجْعَلْهُ حَجًّا مَبْرُورًا',
          'translit': 'Allahu Akbar, Allahumma-j’alhu hajjan mabrura',
          'meaningEn': 'Allah is the Greatest. O Allah, make it an accepted Hajj.',
          'meaningAr': 'تكبير ودعاء بالقبول.'
        }
      ]
    },

    'tawaf_wida': {
      'titleEn': 'Tawaf al-Wida (Farewell Tawaf)',
      'titleAr': 'طواف الوداع',
      'day': 'Final action before leaving Makkah',
      'dayAr': 'آخر أعمال الحاج قبل مغادرة مكة',
      'overviewEn': 'Tawaf al-Wida (Farewell Tawaf) is the final compulsory obligation (Wajib) for every pilgrim before leaving the holy city of Makkah. It consists of 7 circuits around the Kaaba without Sa\'i. After completing Tawaf al-Wida, pilgrims pray 2 Rakat, drink Zamzam, and depart Makkah directly without lingering.',
      'overviewAr': 'طواف الوداع هو آخر واجبات الحج على كل آفاقي (من خارج مكة) قبل مغادرتها. يطوف الحاج ٧ أشواط حول البيت الحرام تحيةً ووداعاً للكعبة، ثم يصلي ركعتين، ويشرب من زمزم، وينطلق مسافراً إلى أهله دون إقامة أو مكوث بعده.',
      'overviewArTranslit': "Tawaful-wida'i huwa akhiru waajibaa-til-hajji 'ala kulli aafaaqiyyin (min khaariji Makkah) qabla mughaadaratiha. Yatooful-haajju sab'ata ashwaatin hawlal-baytil-harami tahiyyatan wa widaa'an lil-Ka'bah, thumma yusallee rak'atayni, wa yashrabu min Zamzam, wa yantaliqu musaafiran ila ahlihī doona iqaamatin aw mukoothin ba'dah.",
      'overviewArMeaning': "Tawaf al-Wida (Farewell Tawaf) is the last obligation of Hajj for every pilgrim from outside Makkah before leaving it. The pilgrim circumambulates seven times around the Sacred House as a greeting and farewell to the Kaaba, then prays two units of prayer, drinks from Zamzam, and departs directly to their family without residing or lingering after it.",
      'actionDetails': [
        {
          'title': 'Perform 7 circuits around the Kaaba as the last activity in Makkah.',
          'details': 'Before leaving Makkah to return home, proceed to the Grand Mosque and perform 7 rounds of Tawaf around the Kaaba. This is the absolute final act of Hajj.',
          'glossary': [
            {'term': 'Tawaf al-Wida', 'meaning': 'The Farewell Tawaf, performed just prior to leaving Makkah.'},
            {'term': 'Wajib', 'meaning': 'An obligatory duty.'}
          ]
        },
        {
          'title': 'No Raml (brisk walking) or Idtiba (shoulder uncovering) required.',
          'details': 'Raml and Idtiba are not performed during Tawaf al-Wida. Walk normally at a composed pace.',
          'glossary': [
            {'term': 'Idtiba', 'meaning': 'Uncovering the shoulder.'},
            {'term': 'Raml', 'meaning': 'Brisk walking.'}
          ]
        },
        {
          'title': 'Pray 2 Rakat behind Maqam Ibrahim.',
          'details': 'Pray 2 units of prayer after completing the 7 rounds, then drink Zamzam water.',
          'glossary': [
            {'term': 'Maqam Ibrahim', 'meaning': 'The standing place of Ibrahim (AS).'},
            {'term': 'Zamzam', 'meaning': 'The blessed water.'}
          ]
        },
        {
          'title': 'Depart Makkah immediately after completing Tawaf.',
          'details': 'Do not spend extra time shopping or staying in Makkah after completing this Tawaf. You should head directly to your transport to leave the city.',
          'glossary': [
            {'term': 'Exemption', 'meaning': 'Menstruating women are completely exempt from Tawaf al-Wida and do not need to perform it or pay a penalty.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'ثُمَّ لْيَقْضُوا تَفَثَهُمْ وَلْيُوفُوا نُذُورَهُمْ وَلْيَطَّوَّفُوا بِالْبَيْتِ الْعَتِيقِ',
        'referenceAr': 'سورة الحج - الآية ٢٩',
        'textEn': 'Then let them end their untidiness and fulfill their vows and perform Tawaf around the Ancient House.',
        'translitEn': "Thummal-yaqdu tafathahum wal-yufu nudhurahum wal-yattawwafu bil-Baytil-'Atiq.",
        'referenceEn': 'Surah Al-Hajj (22:29)',
        'explanationEn': 'General divine directive commanding believers to wrap up their pilgrimage rites with Tawaf around the sacred Kaaba.',
        'explanationAr': 'الأمر الرباني بختام المناسك بالطواف بالبيت العتيق تعظيماً له.',
      },
      'hadiths': [
        {
          'textAr': 'عَنِ ابْنِ عَبَّاسٍ رَضِيَ اللَّهُ عَنْهُمَا قَالَ: «أُمِرَ النَّاسُ أَنْ يَكُونَ آخِرُ عَهْدِهِمْ بِالْبَيْتِ، إِلاَّ أَنَّهُ خُفِّفَ عَنِ الْمَرْأَةِ الْحَائِضِ»',
          'translitEn': 'An ibni Abbas radiya-allahu anhuma qala: Umira-n-nasu an yakuna akhiru ahdihim bil-bayti, illa annahu khuffifa ani-l-mar\'ati-l-ha\'id.',
          'referenceEn': 'Sahih al-Bukhari 1755, Sahih Muslim 1327',
          'textEn': 'Ibn Abbas reported: "The people were ordered that their last action should be at the House (Kaaba), except that an exemption was granted for menstruating women."',
          'explanationEn': 'Establishes Tawaf al-Wida as a binding obligation for all departing pilgrims.',
          'sourceBook': 'Sahih al-Bukhari & Sahih Muslim',
          'sourceBookDesc': 'The dual pillars of authentic Hadith scholarship.'
        },
        {
          'textAr': 'عَنْ عَائِشَةَ رَضِيَ اللَّهُ عَنْهَا أَنَّ صَفِيَّةَ بِنْتَ حُيَيٍّ رَضِيَ اللَّهُ عَنْهَا حَاضَتْ بَعْدَ مَا أَفَاضَتْ... فَقَالَ النَّبِيُّ: «فَلْتَنْفِرْ إِذًا»',
          'translitEn': 'An Aisha radiya-allahu anha anna Safiyyata binta Huyayyin radiya-allahu anha hadat ba\'da ma afadat... Faqala-nabiyyu: Faltanfir idhan.',
          'referenceEn': 'Sahih al-Bukhari 1757',
          'textEn': 'Aisha narrated: "Safiyyah bint Huyayy menstruated after performing Tawaf al-Ifadah... The Prophet (ﷺ) said: She may depart then (without performing the Farewell Tawaf)."',
          'explanationEn': 'Confirms the legal exemption of menstruating women from performing the Farewell Tawaf.',
          'sourceBook': 'Sahih al-Bukhari',
          'sourceBookDesc': 'Compiled by Imam Bukhari, containing highly verified Prophetic narrations.'
        }
      ],
      'duas': [
        {
          'title': 'Dua of Departure & Farewell',
          'arabic': 'اللَّهُمَّ لا تَجْعَلْ هَذَا آخِرَ الْعَهْدِ بِبَيْتِكَ الْحَرَامِ، وَإِنْ جَعَلْتَهُ آخِرَ الْعَهْدِ فَاعْوَضْنِي عَنْهُ الْجَنَّةَ',
          'translit': 'Allahumma la taj’al hadha akhiral-\'ahdi bibaytikal-haram, wa in ja’altahu akhiral-\'ahdi fa’awwidni \'anhul-jannata',
          'meaningEn': 'O Allah, do not make this the last visit to Your Sacred House, and if You decree it to be the last, grant me Paradise in exchange.',
          'meaningAr': 'التوسل إلى الله ألا يكون هذا آخر العهد بالبيت الحرام والتضرع بالعودة والقبول.',
        },
        {
          'title': 'Dua for Safe Journey Home',
          'arabic': 'اللَّهُمَّ هَوِّنْ عَلَيْنَا سَفَرَنَا هَذَا وَاطْوِ عَنَّا بُعْدَهُ',
          'translit': 'Allahumma hawwin \'alayna safarana hadha watwi \'anna bu\'dah',
          'meaningEn': 'O Allah, make this journey easy for us and fold up its distance.',
          'meaningAr': 'دعاء السفر والعودة للوطن بعد إتمام المناسك.'
        }
      ]
    },

    'ihram_u': {
      'titleEn': 'Enter Ihram for Umrah',
      'titleAr': 'الإحرام للعمرة',
      'day': 'At Miqat',
      'dayAr': 'عند الميقات',
      'overviewEn': 'The first pillar of Umrah is entering Ihram at the designated Miqat with ritual purification, wearing Ihram garments, stating the Niyyah for Umrah ("Labbayk Allahumma Umrah"), and continuously reciting Talbiyah until seeing the Kaaba.',
      'overviewAr': 'أول أركان العمرة وهو الإحرام من الميقات بالطهارة والغسل ولبس ثياب الإحرام والتلفظ بالنية ("لَبَّيْكَ اللَّهُمَّ عُمْرَةً") ورفع الصوت بالتلبية حتى رؤية الكعبة.',
      'overviewArTranslit': "Awwalu arkaanil-'umrati wa huwal-ihramu minal-meeqati bit-taharati wal-ghusli wa lubsi thiyabil-ihrami wat-talaffuzu bin-niyyah ('Labbayk Allahumma 'Umrah') wa raf'is-sawti bit-talbiyati hatta ru'yatil-Ka'bah.",
      'overviewArMeaning': "The first pillar of Umrah is entering Ihram from the Miqat with purification, bathing (Ghusl), wearing the Ihram garments, uttering the intention ('Labbayk Allahumma Umrah'), and raising the voice with Talbiyah until seeing the Kaaba.",
      'actionDetails': [
        {
          'title': 'Ghusl & perfumes on body before Ihram.',
          'details': 'Perform Ghusl (ritual bath) before reaching the Miqat boundary. You may apply perfume to your body (not your Ihram clothes).',
          'glossary': [
            {'term': 'Ghusl', 'meaning': 'The full-body ritual bath taken for purification.'},
            {'term': 'Miqat', 'meaning': 'The boundary points where entering Ihram is required.'}
          ]
        },
        {
          'title': 'Wear Ihram sheets (men) or modest dress (women).',
          'details': 'Men wrap the lower Izar and upper Rida. Women wear simple, modest clothing without covering their faces or hands.',
          'glossary': [
            {'term': 'Izar', 'meaning': 'The unstitched lower garment wrapped around the waist.'},
            {'term': 'Rida', 'meaning': 'The unstitched upper garment covering the shoulders.'}
          ]
        },
        {
          'title': 'State Niyyah for Umrah.',
          'details': 'Declare intention clearly: "Labbayk Allahumma Umrah" (لَبَّيْكَ اللَّهُمَّ عُمْرَةً) at the Miqat.',
          'glossary': [
            {'term': 'Niyyah', 'meaning': 'Sincere internal intention.'}
          ]
        },
        {
          'title': 'Recite Talbiyah continuously.',
          'details': 'Chant "Labbayk Allahumma Labbayk..." regularly until you reach the Kaaba.',
          'glossary': [
            {'term': 'Talbiyah', 'meaning': 'The sacred pilgrim\'s chant.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'وَأَتِمُّوا الْحَجَّ وَالْعُمْرَةَ لِلَّهِ',
        'referenceAr': 'سورة البقرة - الآية ١٩٦',
        'textEn': 'And complete the Hajj and Umrah for Allah.',
        'translitEn': "Wa atimmul-hajja wal-'umrata lillah.",
        'referenceEn': 'Surah Al-Baqarah (2:196)',
        'explanationEn': 'Divine mandate commanding the sincere completion of Umrah rituals exclusively for Allah.',
        'explanationAr': 'وجوب إتمام العمرة وإخلاصها لله تعالى.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ أَبِي هُرَيْرَةَ رَضِيَ اللَّهُ عَنْهُ أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ قَالَ: «الْعُمْرَةُ إِلَى الْعُمْرَةِ كَفَّارَةٌ لِمَا بَيْنَهُمَا...»',
          'translitEn': 'An Abi Hurairah radiya-allahu anhu anna rasula-llahi salla-allahu alayhi wa sallama qala: Al-Umratu ilal-umrati kaffaratul-lima baynahuma...',
          'referenceEn': 'Sahih al-Bukhari 1773, Sahih Muslim 1349',
          'textEn': 'Abu Hurairah reported: The Messenger of Allah (ﷺ) said: "An Umrah to another Umrah is an expiation for whatever sins occur between them, and an accepted Hajj receives no reward less than Paradise."',
          'explanationEn': 'Highlights the immense spiritual purification and expiation of sins obtained through Umrah.',
          'sourceBook': 'Sahih al-Bukhari & Sahih Muslim',
          'sourceBookDesc': 'Authentic collections containing highly verified reports of the Prophet\'s statements.'
        },
        {
          'textAr': 'عَنْ أَنَسٍ رَضِيَ اللَّهُ عَنْهُ أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ اعْتَمَرَ أَرْبَعَ عُمَرٍ',
          'translitEn': 'An Anas radiya-allahu anhu anna-nabiyya salla-allahu alayhi wa sallama-\'tamara arba\'a umar.',
          'referenceEn': 'Sahih al-Bukhari 1778',
          'textEn': 'Anas narrated: "The Prophet (ﷺ) performed Umrah four times in his life, all of them in the month of Dhul Qi\'dah except the one performed with his Hajj."',
          'explanationEn': 'Establishes the legality and practice of performing multiple Umrahs.',
          'sourceBook': 'Sahih al-Bukhari',
          'sourceBookDesc': 'The primary source of authentic prophetic statements, compiled by Imam Al-Bukhari.'
        }
      ],
      'duas': [
        {
          'title': 'Intention for Umrah',
          'arabic': 'لَبَّيْكَ اللَّهُمَّ عُمْرَةً',
          'translit': 'Labbayk Allahumma \'Umrah',
          'meaningEn': 'Here I am O Allah, performing Umrah at Your service.',
          'meaningAr': 'التلبية والنية لأداء مناسك العمرة.',
        },
        {
          'title': 'Talbiyah chant',
          'arabic': 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لا شَرِيكَ لَكَ لَبَّيْكَ...',
          'translit': 'Labbayk Allahumma Labbayk, Labbayka la sharika laka labbayk...',
          'meaningEn': 'Here I am, O Allah, here I am...',
          'meaningAr': 'التلبية إعلاناً للتوحيد وإجابةً لنداء الله عز وجل.'
        }
      ]
    },

    'tawaf_u': {
      'titleEn': 'Tawaf of Umrah',
      'titleAr': 'طواف العمرة',
      'day': 'Around the Kaaba',
      'dayAr': 'حول الكعبة المشرفة',
      'overviewEn': 'Circumambulate the Holy Kaaba 7 times counter-clockwise, starting from the Black Stone. Men perform Idtiba and Raml in the first 3 rounds. Conclude with 2 Rakat behind Maqam Ibrahim and drinking Zamzam.',
      'overviewAr': 'الطواف حول الكعبة المشرفة ٧ أشواط يبدأ من الحجر الأسود وينتهي عنده، مع الاضطباع والرمل للرجال في الأشواط الثلاثة الأولى، يعقبه صلاة ركعتين خلف المقام والشرب من زمزم.',
      'overviewArTranslit': "At-tawaafu hawlal-Ka'batil-musharrafati sab'ata ashwaatin yabda'u minal-hajaril-aswadi wa yantahi 'indah, ma'al-idtiba'i war-ramali lir-rijaali fil-ashwaatith-thalathatil-oola, ya'qubuhu salatu rak'atayni khalfal-maqaami wash-shurbu min Zamzam.",
      'overviewArMeaning': "Circumambulating the Holy Kaaba seven times, starting and ending at the Black Stone, with Idtiba (uncovering the right shoulder) and Raml (brisk walking) for men in the first three rounds, followed by praying two units of prayer behind the Station (Maqam Ibrahim) and drinking from Zamzam.",
      'actionDetails': [
        {
          'title': '7 rounds around Kaaba starting from Black Stone.',
          'details': 'Align with the Black Stone corner of the Kaaba, raise your hand saying "Bismillahi Allahu Akbar" and complete seven counter-clockwise circuits.',
          'glossary': [
            {'term': 'Tawaf', 'meaning': 'The act of circling the Kaaba seven times.'},
            {'term': 'Hajar al-Aswad', 'meaning': 'The Black Stone.'}
          ]
        },
        {
          'title': 'Idtiba & Raml (men in first 3 rounds).',
          'details': 'Men uncover the right shoulder (Idtiba) and walk with quick, short steps (Raml) in the first 3 rounds of Tawaf. Walk normally for the remaining 4 rounds.',
          'glossary': [
            {'term': 'Idtiba', 'meaning': 'Uncovering the right shoulder.'},
            {'term': 'Raml', 'meaning': 'Brisk walking.'}
          ]
        },
        {
          'title': '2 Rakat at Maqam Ibrahim.',
          'details': 'Cover your shoulder, go behind the Station of Abraham and offer 2 units of prayer.',
          'glossary': [
            {'term': 'Maqam Ibrahim', 'meaning': 'The station of Abraham.'}
          ]
        },
        {
          'title': 'Drink Zamzam water.',
          'details': 'Stand and drink Zamzam water, then pour some over your head and make Dua.',
          'glossary': [
            {'term': 'Zamzam', 'meaning': 'The sacred well water.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'وَلْيَطَّوَّفُوا بِالْبَيْتِ الْعَتِيقِ',
        'referenceAr': 'سورة الحج - الآية ٢٩',
        'textEn': 'And perform Tawaf around the Ancient House.',
        'translitEn': "Wal-yattawwafu bil-Baytil-'Atiq.",
        'referenceEn': 'Surah Al-Hajj (22:29)',
        'explanationEn': 'Divine order to perform Tawaf around the sacred Kaaba.',
        'explanationAr': 'الأمر بالطواف بالبيت الحرام.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ عَبْدِ اللَّهِ بْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا قَالَ: «مَنْ طَافَ بِهَذَا الْبَيْتِ أُسْبُوعًا فَأَحْصَاهُ كَانَ كَعِتْقِ رَقَبَةٍ»',
          'translitEn': 'An ibni Umar radiya-allahu anhuma qala: Man tafa bihadhal-bayti usboo\'an fa\'ahsahu kana ka\'itqi raqabah.',
          'referenceEn': 'Jami\' at-Tirmidhi 959',
          'textEn': 'Ibn Umar reported: "Whoever performs Tawaf around this House seven times properly, it is equal to freeing a slave."',
          'explanationEn': 'Virtue and great reward of performing 7 rounds of Tawaf.',
          'sourceBook': 'Jami\' at-Tirmidhi',
          'sourceBookDesc': 'Hadith collection compiled by Imam Tirmidhi, known for its classification system.'
        },
        {
          'textAr': 'عَنِ ابْنِ عَبَّاسٍ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ طَافَ فِي عُمْرَتِهِ عَلَى بَعِيرٍ',
          'translitEn': 'An ibni Abbas radiya-allahu anhuma anna-nabiyya salla-allahu alayhi wa sallama tafa fi umratihi ala ba\'eer.',
          'referenceEn': 'Sahih al-Bukhari 1632',
          'textEn': 'Ibn Abbas narrated that the Prophet (ﷺ) performed Tawaf around the Kaaba on his camel during his Umrah.',
          'explanationEn': 'Confirms that performing Tawaf on a mount is permissible for those who have a valid health reason or disability.',
          'sourceBook': 'Sahih al-Bukhari',
          'sourceBookDesc': 'Highly authentic and respected collection of Hadith by Imam Al-Bukhari.'
        }
      ],
      'duas': [
        {
          'title': 'Dua Between Corners',
          'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
          'translit': 'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina \'adhaban-nar.',
          'meaningEn': 'Our Lord, grant us good in this world and the next and save us from Hellfire.',
          'meaningAr': 'الدعاء بين الركن اليماني والحجر الأسود.',
        },
        {
          'title': 'General remembrance during Tawaf',
          'arabic': 'سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلا إِلَهَ إِلاَّ اللَّهُ وَاللَّهُ أَكْبَرُ',
          'translit': 'Subhanallahi wal-hamdulillahi wa la ilaha illallahu wallahu Akbar',
          'meaningEn': 'Glory be to Allah, all praise is due to Allah, there is no deity worthy of worship except Allah, Allah is the Greatest.',
          'meaningAr': 'الذكر بالتسبيح والتحميد والتكبير والتوحيد.'
        }
      ]
    },

    'sai_u': {
      'titleEn': 'Sa’i of Umrah (Safa & Marwah)',
      'titleAr': 'سعي العمرة (الصفا والمروة)',
      'day': 'Between Safa and Marwah',
      'dayAr': 'بين الصفا والمروة',
      'overviewEn': 'Walk 7 times between the hills of Safa and Marwah, commencing at Safa and ending at Marwah. Men jog lightly between the green lights. Recite Dhikr and make personal supplications at both hills.',
      'overviewAr': 'السعي بين الصفا والمروة ٧ أشواط يبدأ بالصفا وينتهي بالمروة، يهرول الرجال بين العلمين الأخضرين، مع الإكثار من الذكر والدعاء عند كل جبل.',
      'overviewArTranslit': "As-sa'yu baynas-Safa wal-Marwata sab'ata ashwaatin yabda'u bis-Safa wa yantahi bil-Marwah, yuharwilur-rijaalu baynal-'alamaynil-akhdarayn, ma'al-ikthaari minadh-dhikri wad-du'a'i 'inda kulli jabal.",
      'overviewArMeaning': "Sa'i between Safa and Marwah is seven rounds, beginning at Safa and ending at Marwah, with men jogging between the two green markers, while increasing remembrance (Dhikr) and supplication (Dua) at each hill.",
      'actionDetails': [
        {
          'title': 'Begin at Safa facing Kaaba.',
          'details': 'Ascend the slope of Mount Safa, face the direction of the Kaaba, raise your hands, and praise Allah before starting.',
          'glossary': [
            {'term': 'Safa', 'meaning': 'The small hill where Sa\'i begins.'}
          ]
        },
        {
          'title': '7 laps (Safa to Marwah = 1, Marwah to Safa = 2).',
          'details': 'Walk from Safa to Marwah (lap 1), then from Marwah to Safa (lap 2). Conclude the 7th lap at Mount Marwah.',
          'glossary': [
            {'term': 'Lap', 'meaning': 'A single direction walk from one hill to the other.'}
          ]
        },
        {
          'title': 'Light jog for men between green marker lights.',
          'details': 'Men should jog briskly (Raml) when passing the green fluorescent lights. Walk normally elsewhere.',
          'glossary': [
            {'term': 'Raml', 'meaning': 'Quick, brisk pace.'}
          ]
        },
        {
          'title': 'Conclude at Marwah on the 7th lap.',
          'details': 'Upon reaching Mount Marwah on the 7th lap, face the Qiblah, make your final Dua, and complete the Sa\'i.',
          'glossary': [
            {'term': 'Marwah', 'meaning': 'The small hill where Sa\'i ends.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'إِنَّ الصَّفَا وَالْمَرْوَةَ مِن شَعَائِرِ اللَّهِ',
        'referenceAr': 'سورة البقرة - الآية ١٥٨',
        'textEn': 'Indeed, Safa and Marwah are among the symbols of Allah.',
        'translitEn': 'Innas-Safa wal-Marwata min sha\'a\'irillah.',
        'referenceEn': 'Surah Al-Baqarah (2:158)',
        'explanationEn': 'Safa and Marwah are established as sacred symbols for pilgrimage.',
        'explanationAr': 'اعتبار الصفا والمروة من شعائر الله.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ جَابِرٍ رَضِيَ اللَّهُ عَنْهُ قَالَ: فَبَدَأَ بِالصفَا فَرَقِيَ عَلَيْهِ حَتَّى رَأَى الْبَيْتَ فَاسْتَقْبَلَ الْقِبْلَةَ، فَوَحَّدَ اللَّهَ وَكَبَّرَهُ وَقَالَ: «أَبْدَأُ بِمَا بَدَأَ اللَّهُ بِهِ»',
          'translitEn': 'An Jabir radiya-allahu anhu qala: Fabada\'a bis-Safa faraqiya alayhi hatta ra\'ayal-bayta fastaqbalal-qiblata, fawahhada-llaha wakabbarahu wa qala: Abda\'u bima bada\'a-llahu bihi.',
          'referenceEn': 'Sahih Muslim 1218',
          'textEn': 'Jabir reported: Prophet (ﷺ) started at Safa, mounted it until he saw the Kaaba, faced Qiblah, praised Allah, and said: "I begin with that which Allah began with."',
          'explanationEn': 'The exact Sunnah guidance for initiating Sa\'i at Safa.',
          'sourceBook': 'Sahih Muslim',
          'sourceBookDesc': 'Authentic compilation containing the Farewell Pilgrimage details.'
        },
        {
          'textAr': 'عَنْ عَائِشَةَ رَضِيَ اللَّهُ عَنْهَا قَالَتْ: طَافَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ وَسَعَى بَيْنَ الصَّفَا وَالْمَرْوَةَ فَكَانَتْ سُنَّةً',
          'translitEn': 'An Aisha radiya-allahu anha qalat: Tafa rasulu-llahi salla-allahu alayhi wa sallama wa sa\'a baynas-Safa wal-Marwata fakanat sunnah.',
          'referenceEn': 'Sahih al-Bukhari 1643',
          'textEn': 'Aisha narrated: "The Messenger of Allah (ﷺ) performed Tawaf and Sa\'i between Safa and Marwah, and it became a Sunnah (obligatory tradition)."',
          'explanationEn': 'Confirms that the Sa\'i was practiced by the Prophet ﷺ and established as an permanent obligation for Umrah.',
          'sourceBook': 'Sahih al-Bukhari',
          'sourceBookDesc': 'Imam Bukhari Hadith collection, the highest standard of verification.'
        }
      ],
      'duas': [
        {
          'title': 'Dua on Safa & Marwah',
          'arabic': 'لا إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ...',
          'translit': 'La ilaha illallahu wahdahu la sharika lahu...',
          'meaningEn': 'There is no deity except Allah alone without partner...',
          'meaningAr': 'التوحيد والثناء عند الجبلين.',
        },
        {
          'title': 'Dua during walking',
          'arabic': 'رَبِّ اغْفِرْ وَارْحَمْ وَأَنْتَ الأَعَزُّ الأَكْرَمُ',
          'translit': 'Rabbighfir warham wa antal-a\'azzul-akram',
          'meaningEn': 'My Lord, forgive and show mercy, for You are the Most Mighty, Most Generous.',
          'meaningAr': 'الاستغفار وطلب الرحمة أثناء السعي.'
        }
      ]
    },

    'halq_u': {
      'titleEn': 'Halq / Taqsir (Completion of Umrah)',
      'titleAr': 'الحلق أو التقصير (إتمام العمرة)',
      'day': 'Final step of Umrah',
      'dayAr': 'آخر أعمال العمرة',
      'overviewEn': 'Complete Umrah by shaving the head (men - preferred) or trimming hair all around. Women trim a fingertip length. All Ihram prohibitions are lifted, and Umrah is completed!',
      'overviewAr': 'ختام مناسك العمرة بحلق رأس الرجل (وهو الأفضل) أو تقصيره، وتقصير المرأة قدر أنملة، وبذلك تحل العمرة بالكامل وتكتمل المناسك.',
      'overviewArTranslit': "Khitaamu manaasikil-'umrati bihalqi ra'sir-rajuli (wa huwal-afdal) aw taqseerihi, wa tuqassirul-mar'atu qadra anmula, wa bidhalika tahillul-'umratu bil-kaamili wa taktamilu-l-manaasik.",
      'overviewArMeaning': "Concluding the rituals of Umrah by shaving the man's head (which is preferred) or trimming it, and the woman trimming her hair by a fingertip length. With this, the restrictions of Umrah are completely lifted and the rituals are completed.",
      'actionDetails': [
        {
          'title': 'Men shave (Halq) or trim (Taqsir).',
          'details': 'Shave your entire head (optimal) or cut your hair evenly all around. This concludes the state of Ihram.',
          'glossary': [
            {'term': 'Halq', 'meaning': 'Shaving the head completely.'},
            {'term': 'Taqsir', 'meaning': 'Trimming the hair.'}
          ]
        },
        {
          'title': 'Women trim fingertip length.',
          'details': 'Women gather all their hair and clip about 1.5 to 2 cm (fingertip length) from the ends.',
          'glossary': [
            {'term': 'Fingertip length', 'meaning': 'The standard measure of trimming for women.'}
          ]
        },
        {
          'title': 'Ihram restrictions completely lifted.',
          'details': 'Once shaved or trimmed, all Ihram restrictions are completely lifted. You are now in the normal state (Halal) and can wear regular clothes.',
          'glossary': [
            {'term': 'Halal', 'meaning': 'The normal state of a person, free from the restrictions of Ihram.'}
          ]
        },
        {
          'title': 'Umrah is officially complete!',
          'details': 'You have successfully completed all the pillars of Umrah. Thank Allah for the opportunity and make Dua for acceptance.',
          'glossary': [
            {'term': 'Acceptance', 'meaning': 'Supplicating to Allah to accept the pilgrimage and forgive all shortcomings.'}
          ]
        }
      ],
      'quran': {
        'textAr': 'مُحَلِّقِينَ رُءُوسَكُمْ وَمُقَصِّرِينَ لَا تَخَافُونَ',
        'referenceAr': 'سورة الفتح - الآية ٢٧',
        'textEn': 'With your heads shaved and hair shortened, not fearing.',
        'referenceEn': 'Surah Al-Fath (48:27)',
        'explanationEn': 'Divine sanction of shaving and trimming to complete Umrah.',
        'explanationAr': 'مشروعية الحلق والتقصير لإتمام النسك.',
      },
      'hadiths': [
        {
          'textAr': 'عَنْ عَبْدِ اللَّهِ بْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ قَالَ: «رَحِمَ اللَّهُ الْمُحَلِّقِينَ»، قَالُوا: وَالْمُقَصِّرِينَ يَا رَسُولَ اللَّهِ؟...',
          'translitEn': 'An Abdillahi-bni Umar radiya-allahu anhuma anna rasula-llahi salla-allahu alayhi wa sallama qala: Rahimallahu-l-muhalliqeen. Qalu: Wal-muqassireena ya rasula-llahi?...',
          'referenceEn': 'Sahih al-Bukhari 1727',
          'textEn': 'The Prophet (ﷺ) invoked mercy thrice for those who shave their heads and then for those who shorten.',
          'explanationEn': 'Prophetic mercy for pilgrims upon shaving or trimming.',
          'sourceBook': 'Sahih al-Bukhari',
          'sourceBookDesc': 'Highly authentic collection by Imam Al-Bukhari.'
        },
        {
          'textAr': 'عَنِ ابْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ حَلَقَ رَأْسَهُ فِي عُمْرَةِ الْقَضَاءِ',
          'translitEn': 'An ibni Umar radiya-allahu anhuma anna rasula-llahi salla-allahu alayhi wa sallama halaqa rasahu fi umrati-l-qada\'.',
          'referenceEn': 'Sahih Muslim 1303',
          'textEn': 'Ibn Umar reported that the Prophet ﷺ shaved his head during the compensatory Umrah (Umrah al-Qada).',
          'explanationEn': 'Confirms that the Prophet ﷺ shaved his head during his Umrah performance, establishing it as the preferred practice.',
          'sourceBook': 'Sahih Muslim',
          'sourceBookDesc': 'Authentic collection of Hadith compiled by Imam Muslim.'
        }
      ],
      'duas': [
        {
          'title': 'Dua of Gratitude upon Completion',
          'arabic': 'الْحَمْدُ لِلَّهِ الَّذِي بِنِعْمَتِهِ تَتِمُّ الصَّالِحَاتُ',
          'translit': 'Alhamdu lillahil-ladhi bi-ni\'matihi tatimmus-salihat.',
          'meaningEn': 'Praise be to Allah by Whose grace good deeds are completed.',
          'meaningAr': 'شكر الله تعالى على التوفيق لإتمام العمرة.',
        },
        {
          'title': 'Dua for Acceptance of Umrah',
          'arabic': 'اللَّهُمَّ تَقَبَّلْ مِنَّا عُمْرَتَنَا وَاغْفِرْ لَنَا ذُنُوبَنَا',
          'translit': 'Allahumma taqabbal minna umratana waghfir lana dhunubana',
          'meaningEn': 'O Allah, accept our Umrah from us and forgive our sins.',
          'meaningAr': 'سؤال القبول والمغفرة.'
        }
      ]
    },
  };

    // ===== PACKING & DOCUMENT LISTS =====
  final List<String> _packingItems = [
    'Ihram cloths (2 sets, for men)',
    'Modest, comfortable clothing (for women)',
    'Sandals / slippers',
    'Money belt / travel pouch',
    'Small foldable prayer mat',
    'Umbrella or cap for sun protection',
    'Personal medicine & first-aid kit',
    'Unscented soap, shampoo & toiletries',
    'Power bank & charger',
    'Small backpack for daily use',
    'Reusable water bottle',
    'Copies of important documents',
  ];

  final List<String> _documentItems = [
    'Valid passport (6+ months validity)',
    'Hajj/Umrah visa',
    'Meningitis (ACYW135) vaccination certificate',
    'Return flight ticket',
    'Hotel / package booking confirmation',
    'Travel & health insurance',
    'Passport-size photographs',
    'Emergency contact list',
  ];

  // ===== DUAS =====
  final List<Map<String, String>> _duas = [
    {
      'title': 'Talbiyah',
      'arabic': 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ',
      'translit': 'Labbayk Allahumma Labbayk',
      'meaning': 'Here I am, O Allah, here I am, at Your service.',
    },
    {
      'title': 'Entering Ihram',
      'arabic': 'اللَّهُمَّ إِنِّي أُرِيدُ الْحَجَّ',
      'translit': 'Allahumma inni ureedul Hajja',
      'meaning': 'O Allah, I intend to perform Hajj — make it easy for me and accept it from me.',
    },
    {
      'title': 'Between Safa & Marwah',
      'arabic': 'رَبِّ اغْفِرْ وَارْحَمْ',
      'translit': 'Rabbighfir warham',
      'meaning': 'My Lord, forgive and have mercy.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tab = 0;
    _loadState();
  }

  void _initSegmentControllersForCurrentMode() {
    // Dispose any existing segment controllers first to prevent memory leaks
    for (final controller in _segmentControllers.values) {
      controller.dispose();
    }
    _segmentControllers.clear();
    _segmentAnimations.clear();

    final steps = _getActiveSteps();
    final segKeyPrefix = _mode == 'Hajj' ? 'hajj_$_hajjType' : 'umrah';

    for (int i = 0; i < steps.length - 1; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 750),
      );
      _segmentControllers['${segKeyPrefix}_$i'] = controller;
      _segmentAnimations['${segKeyPrefix}_$i'] =
          CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
      
      final done = (_mode == 'Hajj' ? _hajjRitualDone : _umrahRitualDone)[steps[i]['id']] ?? false;
      controller.value = done ? 1.0 : 0.0;
    }
  }

  @override
  void dispose() {
    for (final controller in _segmentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load cached states from SharedPreferences
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      _hajjType = prefs.getString('hajj_type') ?? 'Tamattu';
      _selectedHajjYear = prefs.getInt('hajj_selected_year') ?? 2026;
      final tripStartStr = prefs.getString('hajj_trip_start');
      final tripEndStr = prefs.getString('hajj_trip_end');
      _tripStartDate = tripStartStr != null ? DateTime.tryParse(tripStartStr) : null;
      _tripEndDate = tripEndStr != null ? DateTime.tryParse(tripEndStr) : null;

      final historyJson = prefs.getString('hajj_history');
      if (historyJson != null) {
        try {
          final List list = jsonDecode(historyJson);
          _history = list.map((e) => CompletedPilgrimage.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        } catch (_) {}
      }

      // Load all Hajj steps
      final allHajjStepsList = [
        ..._hajjStepsTamattu,
        ..._hajjStepsQiran,
        ..._hajjStepsIfrad
      ];
      for (final s in allHajjStepsList) {
        _hajjRitualDone[s['id']!] = prefs.getBool('hajj_${s['id']}') ?? false;
      }

      for (final s in _umrahSteps) {
        _umrahRitualDone[s['id']!] = prefs.getBool('umrah_${s['id']}') ?? false;
      }
      for (final item in _packingItems) {
        _packingDone[item] = prefs.getBool(_packKey(item)) ?? false;
      }
      for (final item in _documentItems) {
        _documentsDone[item] = prefs.getBool(_docKey(item)) ?? false;
      }
    });

    // 2. Fetch from Firestore users/{uid} directly
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['hajjUmrah'] != null) {
            final hajjUmrah = data['hajjUmrah'] as Map<String, dynamic>;
            final remoteHajjType = hajjUmrah['hajjType'] as String?;
            final remoteHajjRitual = hajjUmrah['hajjRitualDone'] as Map<String, dynamic>?;
            final remoteUmrahRitual = hajjUmrah['umrahRitualDone'] as Map<String, dynamic>?;
            final remotePacking = hajjUmrah['packingDone'] as Map<String, dynamic>?;
            final remoteDocuments = hajjUmrah['documentsDone'] as Map<String, dynamic>?;
            final remoteHajjYear = hajjUmrah['selectedHajjYear'] as int?;
            if (remoteHajjYear != null) {
              _selectedHajjYear = remoteHajjYear;
              prefs.setInt('hajj_selected_year', remoteHajjYear);
            }
            final remoteTripStart = hajjUmrah['tripStartDate'] as String?;
            final remoteTripEnd = hajjUmrah['tripEndDate'] as String?;
            final remoteHistory = hajjUmrah['history'] as List<dynamic>?;

            if (remoteTripStart != null) {
              _tripStartDate = DateTime.tryParse(remoteTripStart);
              prefs.setString('hajj_trip_start', remoteTripStart);
            }
            if (remoteTripEnd != null) {
              _tripEndDate = DateTime.tryParse(remoteTripEnd);
              prefs.setString('hajj_trip_end', remoteTripEnd);
            }
            if (remoteHistory != null) {
              try {
                _history = remoteHistory.map((e) => CompletedPilgrimage.fromJson(Map<String, dynamic>.from(e as Map))).toList();
                prefs.setString('hajj_history', jsonEncode(_history.map((e) => e.toJson()).toList()));
              } catch (_) {}
            }

            setState(() {
              if (remoteHajjType != null) {
                _hajjType = remoteHajjType;
                prefs.setString('hajj_type', remoteHajjType);
              }

              if (remoteHajjRitual != null) {
                remoteHajjRitual.forEach((key, val) {
                  if (val is bool) {
                    _hajjRitualDone[key] = val;
                    prefs.setBool('hajj_$key', val);
                  }
                });
              }

              if (remoteUmrahRitual != null) {
                remoteUmrahRitual.forEach((key, val) {
                  if (val is bool) {
                    _umrahRitualDone[key] = val;
                    prefs.setBool('umrah_$key', val);
                  }
                });
              }

              if (remotePacking != null) {
                remotePacking.forEach((key, val) {
                  if (val is bool) {
                    _packingDone[key] = val;
                    final item = _packingItems.firstWhere((i) => i == key, orElse: () => "");
                    if (item.isNotEmpty) {
                      prefs.setBool('pack_${item.hashCode}', val);
                    } else {
                      final hash = int.tryParse(key);
                      if (hash != null) {
                        final matchedItem = _packingItems.firstWhere((i) => i.hashCode == hash, orElse: () => "");
                        if (matchedItem.isNotEmpty) {
                          _packingDone[matchedItem] = val;
                          prefs.setBool('pack_${matchedItem.hashCode}', val);
                        }
                      }
                    }
                  }
                });
              }

              if (remoteDocuments != null) {
                remoteDocuments.forEach((key, val) {
                  if (val is bool) {
                    _documentsDone[key] = val;
                    final item = _documentItems.firstWhere((i) => i == key, orElse: () => "");
                    if (item.isNotEmpty) {
                      prefs.setBool('doc_${item.hashCode}', val);
                    } else {
                      final hash = int.tryParse(key);
                      if (hash != null) {
                        final matchedItem = _documentItems.firstWhere((i) => i.hashCode == hash, orElse: () => "");
                        if (matchedItem.isNotEmpty) {
                          _documentsDone[matchedItem] = val;
                          prefs.setBool('doc_${matchedItem.hashCode}', val);
                        }
                      }
                    }
                  }
                });
              }
            });
          }
        }
      } catch (e) {
        debugPrint("Error loading Hajj/Umrah state from Firestore: $e");
      }
    }

    _initSegmentControllersForCurrentMode();
  }

  Future<void> _updateFirestoreHajjUmrah() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'hajjUmrah': {
          'hajjType': _hajjType,
          'hajjRitualDone': _hajjRitualDone,
          'umrahRitualDone': _umrahRitualDone,
          'packingDone': {
            for (final e in _packingDone.entries) _packKey(e.key): e.value,
          },
          'documentsDone': {
            for (final e in _documentsDone.entries) _docKey(e.key): e.value,
          },
          'selectedHajjYear': _selectedHajjYear,
          'tripStartDate': _tripStartDate?.toIso8601String(),
          'tripEndDate': _tripEndDate?.toIso8601String(),
          'history': _history.map((e) => e.toJson()).toList(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating Hajj/Umrah state in Firestore: $e");
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  String _packKey(String item) {
    return 'pack_${item.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}';
  }

  String _docKey(String item) {
    return 'doc_${item.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}';
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

  // ===== HEADER =====
  Widget _buildHeader() {
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor = _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.55);

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
            child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hajj & Umrah Planner',
                    style: GoogleFonts.poppins(
                        fontSize: 15.5, fontWeight: FontWeight.bold, color: textColor)),
                Text('Rituals, packing & documents',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: subtextColor)),
              ],
            ),
          ),
          _buildModeToggle(),
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

  Widget _buildModeToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ['Hajj', 'Umrah'].map((m) {
        final bool selected = _mode == m;
        return GestureDetector(
          onTap: () {
            if (_mode != m) {
              setState(() {
                _mode = m;
                _initSegmentControllersForCurrentMode();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? (_isDarkMode ? AppColors.dustyBlueTeal : AppColors.navyBlue)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              m,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : (_isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.6)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  HajjSeasonInfo get _activeHajjSeason {
    return _hajjSeasons.firstWhere(
      (s) => s.year == _selectedHajjYear,
      orElse: () => _hajjSeasons[2], // Default 2026
    );
  }

  Future<void> _pickTripDates() async {
    if (_mode == 'Hajj') {
      _showHajjSeasonSchedulerDialog();
    } else {
      _showUmrahDateRangePicker();
    }
  }

  void _showHajjSeasonSchedulerDialog() {
    int tempYear = _selectedHajjYear;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isDark = _isDarkMode;
          final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
          final textC = isDark ? Colors.white : AppColors.navyBlue;
          final subC = isDark ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.65);

          final season = _hajjSeasons.firstWhere((s) => s.year == tempYear, orElse: () => _hajjSeasons[2]);

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mosque_rounded, color: Color(0xFFD4AF37), size: 30),
                ),
                const SizedBox(height: 10),
                Text(
                  'Select Hajj Season & Schedule',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textC),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Hajj occurs strictly on 8th–13th Dhul Hijjah',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFB8860B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Hajj Year (Islamic Season):',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: textC)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _hajjSeasons.map((s) {
                        final isSel = s.year == tempYear;
                        return ChoiceChip(
                          label: Text('${s.year} (${s.hijriYear})',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                color: isSel ? Colors.white : textC,
                              )),
                          selected: isSel,
                          selectedColor: AppColors.navyBlue,
                          backgroundColor: isDark ? Colors.white10 : const Color(0xFFEDF2F7),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => tempYear = s.year);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_rounded, size: 15, color: Color(0xFFB8860B)),
                              const SizedBox(width: 6),
                              Text('Official Core Hajj Days (8–13 Dhul Hijjah):',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: textC)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${DateFormat('dd MMM, yyyy').format(season.coreStartDate)} – ${DateFormat('dd MMM, yyyy').format(season.coreEndDate)}',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFB8860B)),
                          ),
                          const SizedBox(height: 4),
                          Text('• 8th Dhul Hijjah: Mina (Tarwiyah)\n• 9th Dhul Hijjah: Arafah & Muzdalifah\n• 10th–13th Dhul Hijjah: Jamarat, Qurbani, Tawaf',
                              style: GoogleFonts.inter(fontSize: 10.5, color: subC, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Hajj Type note based on currently selected _hajjType
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _hajjType == 'Tamattu'
                            ? AppColors.midTeal.withValues(alpha: 0.08)
                            : AppColors.navyBlue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _hajjType == 'Tamattu'
                              ? AppColors.midTeal.withValues(alpha: 0.3)
                              : AppColors.navyBlue.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _hajjType == 'Tamattu' ? Icons.alt_route_rounded : Icons.route_rounded,
                            size: 14,
                            color: _hajjType == 'Tamattu' ? AppColors.midTeal : AppColors.navyBlue,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _hajjType == 'Tamattu'
                                  ? 'Tamattu\' (selected): Perform Umrah first, exit Ihram, then re-enter Ihram for Hajj on 8th Dhul Hijjah. Most common for overseas pilgrims.'
                                  : _hajjType == 'Qiran'
                                      ? 'Qiran (selected): Combine Hajj & Umrah in one Ihram — no exit between them. Requires a Hady (animal sacrifice).'
                                      : 'Ifrad (selected): Hajj only — no Umrah combined. Pilgrims from Makkah commonly perform this type.',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: _hajjType == 'Tamattu' ? AppColors.midTeal : textC,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range_rounded, size: 14),
                            label: Text('Set Travel / Package Period (Optional)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textC,
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final range = await _pickConstrainedHajjDateRange(season);
                              if (range != null) {
                                setModalState(() {
                                  _tripStartDate = range.start;
                                  _tripEndDate = range.end;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey))),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedHajjYear = tempYear;
                    _tripStartDate ??= season.coreStartDate;
                    _tripEndDate ??= season.coreEndDate;
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('hajj_selected_year', _selectedHajjYear);
                  await prefs.setString('hajj_trip_start', _tripStartDate!.toIso8601String());
                  await prefs.setString('hajj_trip_end', _tripEndDate!.toIso8601String());
                  await _updateFirestoreHajjUmrah();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🕋 Hajj $_selectedHajjYear (${season.hijriYear}) schedule confirmed!',
                        style: GoogleFonts.inter(fontSize: 12.5),
                      ),
                      backgroundColor: const Color(0xFFB8860B),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Confirm Schedule', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<DateTimeRange?> _pickConstrainedHajjDateRange(HajjSeasonInfo season) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: season.seasonEarliestFlight,
      lastDate: season.seasonLatestReturn,
      initialDateRange: DateTimeRange(
        start: season.coreStartDate.subtract(const Duration(days: 7)),
        end: season.coreEndDate.add(const Duration(days: 7)),
      ),
      helpText: 'Select Flights within ${season.year} Hajj Season',
      confirmText: 'Confirm Range',
      builder: (context, child) {
        final outerBg = _isDarkMode ? const Color(0xFF000000) : const Color(0xFFE8E8E8);
        return Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F7F5),
            colorScheme: ColorScheme.light(
              primary: AppColors.navyBlue,
              onPrimary: Colors.white,
              surface: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              onSurface: _isDarkMode ? Colors.white : AppColors.navyBlue,
            ),
          ),
          child: Container(
            color: outerBg,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: child!,
              ),
            ),
          ),
        );
      },
    );
    return picked;
  }

  Future<void> _showUmrahDateRangePicker() async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: _tripStartDate ?? now,
      end: _tripEndDate ?? now.add(const Duration(days: 14)),
    );

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      initialDateRange: initialRange,
      helpText: 'Select Umrah Departure and Return Dates',
      confirmText: 'Save Schedule',
      builder: (context, child) {
        final outerBg = _isDarkMode ? const Color(0xFF000000) : const Color(0xFFE8E8E8);
        return Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F7F5),
            colorScheme: ColorScheme.light(
              primary: AppColors.midTeal,
              onPrimary: Colors.white,
              surface: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              onSurface: _isDarkMode ? Colors.white : AppColors.navyBlue,
            ),
          ),
          child: Container(
            color: outerBg,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: child!,
              ),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _tripStartDate = picked.start;
        _tripEndDate = picked.end;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hajj_trip_start', picked.start.toIso8601String());
      await prefs.setString('hajj_trip_end', picked.end.toIso8601String());
      await _updateFirestoreHajjUmrah();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Umrah schedule saved: ${DateFormat('dd MMM, yyyy').format(picked.start)} – ${DateFormat('dd MMM, yyyy').format(picked.end)}',
              style: GoogleFonts.inter(fontSize: 12.5),
            ),
            backgroundColor: AppColors.midTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showCompleteJourneyDialog(int completedCount, int totalCount) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = _isDarkMode;
          final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
          final textC = isDark ? Colors.white : AppColors.navyBlue;
          final subC = isDark ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.65);

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.midTeal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: AppColors.midTeal, size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  'حَجّاً مَبْرُوراً وَسَعْياً مَشْكُوراً',
                  style: GoogleFonts.amiri(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.midTeal,
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete & Archive Journey',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textC,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'May Allah accept your $_mode! This will save your completed pilgrimage with dates into your Journey History and refresh all checklists for future trips.',
                    style: GoogleFonts.inter(fontSize: 12.5, color: subC, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pilgrimage:', style: GoogleFonts.inter(fontSize: 12, color: subC)),
                            Text('$_mode ${_mode == 'Hajj' ? '($_hajjType - $_selectedHajjYear)' : ''}',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: textC)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Rituals Completed:', style: GoogleFonts.inter(fontSize: 12, color: subC)),
                            Text('$completedCount / $totalCount',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                          ],
                        ),
                        if (_tripStartDate != null && _tripEndDate != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Trip Dates:', style: GoogleFonts.inter(fontSize: 12, color: subC)),
                              Text(
                                '${DateFormat('dd MMM').format(_tripStartDate!)} – ${DateFormat('dd MMM, yyyy').format(_tripEndDate!)}',
                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: textC),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add a Personal Memory / Note (Optional):',
                    style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: textC),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: 12.5, color: textC),
                    decoration: InputDecoration(
                      hintText: 'e.g. Performed with family, Al-Haram tour agency',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: subC),
                      filled: true,
                      fillColor: isDark ? Colors.white10 : const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _archiveJourney(
                    note: noteController.text.trim(),
                    completedRituals: completedCount,
                    totalRituals: totalCount,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                child: Text(
                  'Confirm & Archive',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _archiveJourney({
    required String note,
    required int completedRituals,
    required int totalRituals,
  }) async {
    final newEntry = CompletedPilgrimage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mode: _mode,
      hajjType: _mode == 'Hajj' ? '$_hajjType ($_selectedHajjYear)' : '-',
      completionDate: DateTime.now(),
      startDate: _tripStartDate,
      endDate: _tripEndDate,
      note: note,
      completedRituals: completedRituals,
      totalRituals: totalRituals,
    );

    setState(() {
      _history.insert(0, newEntry);
      _hajjRitualDone.clear();
      _umrahRitualDone.clear();
      _packingDone.clear();
      _documentsDone.clear();
      _tripStartDate = null;
      _tripEndDate = null;
      _initSegmentControllersForCurrentMode();
      _tab = 5; // Switch to History tab to see result!
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hajj_history', jsonEncode(_history.map((e) => e.toJson()).toList()));
    await prefs.remove('hajj_trip_start');
    await prefs.remove('hajj_trip_end');

    final allHajjStepsList = [..._hajjStepsTamattu, ..._hajjStepsQiran, ..._hajjStepsIfrad];
    for (final s in allHajjStepsList) {
      await prefs.remove('hajj_${s['id']}');
    }
    for (final s in _umrahSteps) {
      await prefs.remove('umrah_${s['id']}');
    }
    for (final item in _packingItems) {
      await prefs.remove(_packKey(item));
    }
    for (final item in _documentItems) {
      await prefs.remove(_docKey(item));
    }

    await _updateFirestoreHajjUmrah();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🌟 ${newEntry.mode} successfully archived in History! Checklists are now fresh for your next journey.',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.restart_alt_rounded, color: AppColors.coralOrange, size: 24),
            const SizedBox(width: 8),
            Text('Reset Checklists?',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
          ],
        ),
        content: Text(
          'Are you sure you want to uncheck all rituals, packing items, and documents for this $_mode without saving to history?',
          style: GoogleFonts.inter(fontSize: 13, color: _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _hajjRitualDone.clear();
                _umrahRitualDone.clear();
                _packingDone.clear();
                _documentsDone.clear();
                _initSegmentControllersForCurrentMode();
              });
              final prefs = await SharedPreferences.getInstance();
              final allHajjStepsList = [..._hajjStepsTamattu, ..._hajjStepsQiran, ..._hajjStepsIfrad];
              for (final s in allHajjStepsList) {
                await prefs.remove('hajj_${s['id']}');
              }
              for (final s in _umrahSteps) {
                await prefs.remove('umrah_${s['id']}');
              }
              for (final item in _packingItems) {
                await prefs.remove(_packKey(item));
              }
              for (final item in _documentItems) {
                await prefs.remove(_docKey(item));
              }
              await _updateFirestoreHajjUmrah();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All checklists have been reset.', style: GoogleFonts.inter(fontSize: 12.5)),
                    backgroundColor: AppColors.coralOrange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coralOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Reset', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTripScheduleCard() {
    final isDark = _isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textC = isDark ? Colors.white : AppColors.navyBlue;
    final subC = isDark ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.65);
    final isHajj = _mode == 'Hajj';

    String statusText = isHajj ? 'Hajj $_selectedHajjYear (${_activeHajjSeason.hijriYear})' : 'Umrah schedule not set';
    IconData statusIcon = isHajj ? Icons.mosque_rounded : Icons.flight_takeoff_rounded;
    Color statusColor = isHajj ? const Color(0xFFD4AF37) : AppColors.midTeal;

    final targetStart = isHajj ? (_tripStartDate ?? _activeHajjSeason.coreStartDate) : _tripStartDate;
    final targetEnd = isHajj ? (_tripEndDate ?? _activeHajjSeason.coreEndDate) : _tripEndDate;

    if (targetStart != null && targetEnd != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(targetStart.year, targetStart.month, targetStart.day);
      final end = DateTime(targetEnd.year, targetEnd.month, targetEnd.day);

      if (today.isBefore(start)) {
        final days = start.difference(today).inDays;
        statusText = isHajj
            ? 'Hajj $_selectedHajjYear: In $days day${days == 1 ? '' : 's'}'
            : 'Departure in $days day${days == 1 ? '' : 's'}';
        statusColor = const Color(0xFF2E7D32);
      } else if (today.isAfter(end)) {
        statusText = isHajj ? 'Hajj $_selectedHajjYear completed' : 'Umrah dates completed';
        statusColor = isHajj ? const Color(0xFFD4AF37) : AppColors.midTeal;
      } else {
        final currentDay = today.difference(start).inDays + 1;
        final totalDays = end.difference(start).inDays + 1;
        statusText = isHajj ? 'Hajj In Progress (Day $currentDay of $totalDays)' : 'Umrah in Progress';
        statusIcon = Icons.location_on_rounded;
        statusColor = AppColors.coralOrange;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isHajj ? const Color(0xFFD4AF37).withValues(alpha: 0.35) : AppColors.midTeal.withValues(alpha: 0.2),
          width: 1.2,
        ),
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
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _pickTripDates,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_calendar_rounded, size: 13, color: textC),
                      const SizedBox(width: 4),
                      Text(
                        isHajj ? 'Hajj Season' : (_tripStartDate != null ? 'Change' : 'Set Dates'),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textC),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isHajj)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tamattu-specific two-phase banner
                if (_hajjType == 'Tamattu') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.midTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.alt_route_rounded, size: 14, color: AppColors.midTeal),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tamattu\' = 2 Phases: Umrah first (exit Ihram), then re-enter Ihram for Hajj on 8th Dhul Hijjah',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.midTeal, fontWeight: FontWeight.w600, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Core Hajj Days (8–13 Dhul Hijjah): ${DateFormat('dd MMM').format(_activeHajjSeason.coreStartDate)} – ${DateFormat('dd MMM, yyyy').format(_activeHajjSeason.coreEndDate)}',
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: textC),
                      ),
                    ),
                  ],
                ),
                if (_tripStartDate != null && _tripEndDate != null && !_tripStartDate!.isAtSameMomentAs(_activeHajjSeason.coreStartDate))
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Travel Period: ${DateFormat('dd MMM').format(_tripStartDate!)} – ${DateFormat('dd MMM, yyyy').format(_tripEndDate!)}',
                      style: GoogleFonts.inter(fontSize: 11, color: subC),
                    ),
                  ),
              ],
            )
          else if (_tripStartDate != null && _tripEndDate != null)
            Text(
              '${DateFormat('dd MMMM, yyyy').format(_tripStartDate!)} – ${DateFormat('dd MMMM, yyyy').format(_tripEndDate!)}',
              style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: textC),
            )
          else
            Text(
              'Select any travel dates throughout the year for your Umrah journey.',
              style: GoogleFonts.inter(fontSize: 11.5, color: subC, height: 1.35),
            ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _buildRitualsTab();
      case 1:
        return _buildPackingTab();
      case 2:
        return _buildDocumentsTab();
      case 3:
        return _buildDuasTab();
      case 4:
        return _buildMistakesTab();
      case 5:
        return _buildHistoryTab();
      default:
        return _buildRitualsTab();
    }
  }

  // ===== RITUALS TAB =====
  Widget _buildRitualsTab() {
    final steps = _getActiveSteps();
    final doneMap = _mode == 'Hajj' ? _hajjRitualDone : _umrahRitualDone;
    final prefix = _mode == 'Hajj' ? 'hajj_' : 'umrah_';
    final segKeyPrefix = _mode == 'Hajj' ? 'hajj_$_hajjType' : 'umrah';
    final images = _mode == 'Hajj' ? _hajjStepImages : _umrahStepImages;
    
    // Ensure animation controllers exist for the current mode/type
    if (_segmentAnimations.length != (steps.isNotEmpty ? steps.length - 1 : 0) ||
        (steps.length > 1 && !_segmentAnimations.containsKey('${segKeyPrefix}_0'))) {
      _initSegmentControllersForCurrentMode();
    }

    // Compute progress specifically for the active steps of this mode/type
    int completedCount = 0;
    for (final s in steps) {
      if (doneMap[s['id']] == true) {
        completedCount++;
      }
    }

    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor = _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.6);
    final pathColor = _isDarkMode ? Colors.white24 : AppColors.navyBlue.withValues(alpha: 0.28);

    const double rowHeight = 210;
    const double nodeSize = 64;
    const double sidePad = 16;
    const double topOffset = 36;

    return ListView(
      key: ValueKey('rituals_${_mode}_$_hajjType'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildTripScheduleCard(),
        _buildProgressCard(completedCount, steps.length, '$_mode Progress'),
        if (_mode == 'Hajj') ...[
          const SizedBox(height: 16),
          _buildHajjTypeSelector(),
        ],
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final totalHeight = steps.isEmpty
                ? 0.0
                : (topOffset + nodeSize / 2 + rowHeight * (steps.length - 1) + 80);

            final centers = List.generate(steps.length, (i) {
              final isLeft = i.isEven;
              final cx = isLeft ? sidePad + nodeSize / 2 : width - sidePad - nodeSize / 2;
              final cy = topOffset + nodeSize / 2 + rowHeight * i;
              return Offset(cx, cy);
            });

            final segmentAnimations = List<Animation<double>>.generate(
              steps.length > 1 ? steps.length - 1 : 0,
              (i) => _segmentAnimations['${segKeyPrefix}_$i'] ?? const AlwaysStoppedAnimation<double>(0.0),
            );

            return SizedBox(
              width: width,
              height: totalHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge(segmentAnimations),
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _JourneyPathPainter(
                            points: centers,
                            progresses: segmentAnimations.map((a) => a.value).toList(),
                            baseColor: pathColor,
                            glowColor: AppColors.midTeal,
                          ),
                        );
                      },
                    ),
                  ),
                  for (int i = 0; i < steps.length; i++) ...[
                    _buildJourneyNode(
                      center: centers[i],
                      nodeSize: nodeSize,
                      imagePath: images[steps[i]['id']],
                      isDone: doneMap[steps[i]['id']] ?? false,
                      isLocked: i > 0 &&
                          !(doneMap[steps[i]['id']] ?? false) &&
                          !(doneMap[steps[i - 1]['id']] ?? false),
                      stepNumber: i + 1,
                      cardBg: cardBg,
                      onTap: () {
                        final id = steps[i]['id'] ?? '';
                        if (id.isEmpty) return;
                        final alreadyDone = doneMap[id] ?? false;

                        if (!alreadyDone) {
                          if (i > 0) {
                            final prevId = steps[i - 1]['id'] ?? '';
                            final prevDone = doneMap[prevId] ?? false;
                            if (!prevDone) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Complete "${steps[i - 1]['title'] ?? 'previous step'}" first'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: AppColors.coralOrange,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                          }
                        } else {
                          if (i < steps.length - 1) {
                            final nextId = steps[i + 1]['id'] ?? '';
                            final nextDone = doneMap[nextId] ?? false;
                            if (nextDone) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Uncheck "${steps[i + 1]['title'] ?? 'next step'}" first'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: AppColors.coralOrange,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                          }
                        }

                        final newVal = !alreadyDone;
                        setState(() => doneMap[id] = newVal);
                        _saveBool('$prefix$id', newVal);
                        _updateFirestoreHajjUmrah();

                        if (i < steps.length - 1) {
                          final controller = _segmentControllers['${segKeyPrefix}_$i'];
                          if (controller != null) {
                            if (newVal) {
                              controller.forward();
                            } else {
                              controller.reverse();
                            }
                          }
                        }
                      },
                    ),
                    _buildJourneyCard(
                      center: centers[i],
                      isLeft: i.isEven,
                      width: width,
                      nodeSize: nodeSize,
                      sidePad: sidePad,
                      stepId: steps[i]['id'] ?? '',
                      title: steps[i]['title'] ?? '',
                      guideline: steps[i]['desc'] ?? '',
                      isDone: doneMap[steps[i]['id']] ?? false,
                      cardBg: cardBg,
                      textColor: textColor,
                      subtextColor: subtextColor,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildCompletionActionBanner(completedCount, steps.length),
      ],
    );
  }

  Widget _buildHajjTypeSelector() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Select Hajj Type',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildTypeChip('Tamattu', 'Tamattu\'', 'Umrah + Hajj'),
              _buildTypeChip('Qiran', 'Qiran', 'Combined'),
              _buildTypeChip('Ifrad', 'Ifrad', 'Hajj Only'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, String title, String subtitle) {
    final isSelected = _hajjType == type;
    final activeBg = _isDarkMode ? AppColors.midTeal : AppColors.navyBlue;
    final inactiveBg = Colors.transparent;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_hajjType != type) {
            setState(() {
              _hajjType = type;
              _initSegmentControllersForCurrentMode();
            });
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('hajj_type', type);
            });
            _updateFirestoreHajjUmrah();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (_isDarkMode ? Colors.white70 : AppColors.navyBlue),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 8.5,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.8)
                      : (_isDarkMode ? Colors.white38 : AppColors.navyBlue.withValues(alpha: 0.55)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJourneyNode({
    required Offset center,
    required double nodeSize,
    required String? imagePath,
    required bool isDone,
    required bool isLocked,
    required int stepNumber,
    required Color cardBg,
    required VoidCallback onTap,
  }) {
    return Positioned(
      left: center.dx - nodeSize / 2,
      top: center.dy - nodeSize / 2,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: isLocked ? 0.5 : 1.0,
              child: Container(
                width: nodeSize,
                height: nodeSize,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cardBg,
                  border: Border.all(
                    color: isDone
                        ? AppColors.midTeal
                        : (_isDarkMode ? Colors.white24 : AppColors.navyBlue.withValues(alpha: 0.2)),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imagePath != null
                          ? Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Container(
                                color: AppColors.navyBlue.withValues(alpha: 0.08),
                                child: const Icon(Icons.mosque_rounded, color: AppColors.navyBlue),
                              ),
                            )
                          : Container(
                              color: AppColors.navyBlue.withValues(alpha: 0.08),
                              child: const Icon(Icons.mosque_rounded, color: AppColors.navyBlue),
                            ),
                      if (isDone)
                        Container(
                          color: AppColors.midTeal.withValues(alpha: 0.55),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
                        ),
                      if (isLocked)
                        Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? AppColors.midTeal : AppColors.coralOrange,
                  border: Border.all(color: cardBg, width: 2),
                ),
                child: Center(
                  child: Text('$stepNumber',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyCard({
    required Offset center,
    required bool isLeft,
    required double width,
    required double nodeSize,
    required double sidePad,
    required String stepId,
    required String title,
    required String guideline,
    required bool isDone,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
  }) {
    final cardWidth = width - nodeSize - sidePad * 2 - 16;
    final left = isLeft ? (sidePad + nodeSize + 12) : sidePad;

    return Positioned(
      left: left,
      top: center.dy - 62,
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone ? AppColors.midTeal.withValues(alpha: 0.4) : (_isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.transparent),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDone ? AppColors.midTeal : textColor,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 1,
              color: (_isDarkMode ? Colors.white : AppColors.navyBlue).withValues(alpha: 0.08),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 12, color: AppColors.midTeal),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    guideline,
                    style: GoogleFonts.inter(fontSize: 10.5, color: subtextColor, height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ----- VIEW DETAILS BUTTON -----
            InkWell(
              onTap: () => _openRitualDetailPage(context, stepId),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.midTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.midTeal.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 12, color: AppColors.midTeal),
                    const SizedBox(width: 5),
                    Text(
                      'View Details',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.midTeal,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppColors.midTeal),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== RITUAL DETAILS — OPEN MOBILE DETAIL PAGE =====
  void _openRitualDetailPage(BuildContext context, String stepId) {
    final detail = _ritualDetails[stepId];
    if (detail == null) return;

    final imagePath = _mode == 'Hajj'
        ? _hajjStepImages[stepId]
        : _umrahStepImages[stepId];

    final screenSize = MediaQuery.of(context).size;
    final isWideScreen = screenSize.width > 600;

    if (isWideScreen) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Ritual Detail',
        barrierColor: Colors.black.withValues(alpha: 0.65),
        transitionDuration: const Duration(milliseconds: 350),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
        pageBuilder: (context, animation, secondaryAnimation) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 400,
                height: 800,
                constraints: BoxConstraints(
                  maxWidth: screenSize.width * 0.92,
                  maxHeight: screenSize.height * 0.92,
                ),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: HajjRitualDetailScreen(
                  detail: detail,
                  imagePath: imagePath,
                  isDarkMode: _isDarkMode,
                ),
              ),
            ),
          );
        },
      );
    } else {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              HajjRitualDetailScreen(
            detail: detail,
            imagePath: imagePath,
            isDarkMode: _isDarkMode,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    }
  }

  // ===== PACKING TAB =====
  Widget _buildPackingTab() {
    final completed = _packingDone.values.where((v) => v).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildProgressCard(completed, _packingItems.length, 'Packing Progress'),
        const SizedBox(height: 16),
        ..._packingItems.map((item) => _buildChecklistTile(
              label: item,
              isDone: _packingDone[item] ?? false,
              onTap: () {
                final newVal = !(_packingDone[item] ?? false);
                setState(() => _packingDone[item] = newVal);
                _saveBool(_packKey(item), newVal);
                _updateFirestoreHajjUmrah();
              },
              icon: Icons.checkroom_rounded,
            )),
      ],
    );
  }

  // ===== DOCUMENTS TAB =====
  Widget _buildDocumentsTab() {
    final completed = _documentsDone.values.where((v) => v).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildProgressCard(completed, _documentItems.length, 'Document Progress'),
        const SizedBox(height: 16),
        ..._documentItems.map((item) => _buildChecklistTile(
              label: item,
              isDone: _documentsDone[item] ?? false,
              onTap: () {
                final newVal = !(_documentsDone[item] ?? false);
                setState(() => _documentsDone[item] = newVal);
                _saveBool(_docKey(item), newVal);
                _updateFirestoreHajjUmrah();
              },
              icon: Icons.description_rounded,
            )),
      ],
    );
  }

  // ===== DUAS TAB =====
  Widget _buildDuasTab() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor = _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.65);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: _duas.map((dua) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppColors.midTeal, size: 18),
                  const SizedBox(width: 8),
                  Text(dua['title']!,
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                dua['arabic']!,
                style: GoogleFonts.amiri(
                    fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.midTeal, height: 1.6),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Text(
                dua['translit']!,
                style: GoogleFonts.inter(
                    fontSize: 12, fontStyle: FontStyle.italic, color: subtextColor),
              ),
              const SizedBox(height: 6),
              Text(
                dua['meaning']!,
                style: GoogleFonts.inter(fontSize: 12, color: textColor, height: 1.35),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProgressCard(int completed, int total, String label) {
    final double progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDarkMode
              ? [const Color(0xFF1E3A3A), const Color(0xFF0F2626)]
              : [AppColors.navyBlue, const Color(0xFF1F3A52)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.75))),
              Text('$completed / $total',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.coralOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionActionBanner(int completedCount, int totalCount) {
    final isDoneAll = completedCount == totalCount && totalCount > 0;
    final isDark = _isDarkMode;

    // Hajj season validation: archive only allowed if within valid season window
    bool isHajjSeasonActive = true;
    String hajjSeasonWarning = '';
    if (_mode == 'Hajj') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final season = _activeHajjSeason;
      // Allow archiving if today is within season (earliest flight → latest return)
      isHajjSeasonActive = !today.isBefore(season.seasonEarliestFlight) &&
          !today.isAfter(season.seasonLatestReturn);
      if (!isHajjSeasonActive) {
        final coreStart = season.coreStartDate;
        final coreEnd = season.coreEndDate;
        hajjSeasonWarning =
            'Hajj ${season.year} season: ${DateFormat('dd MMM').format(season.seasonEarliestFlight)} – ${DateFormat('dd MMM, yyyy').format(season.seasonLatestReturn)}\n'
            'Core days: ${DateFormat('dd MMM').format(coreStart)} – ${DateFormat('dd MMM, yyyy').format(coreEnd)}\n'
            'You can use the checklist to prepare, but archiving is only allowed within the Hajj season.';
      }
    }

    final canArchive = _mode == 'Umrah' || isHajjSeasonActive;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDoneAll
              ? [const Color(0xFFB8860B), const Color(0xFFD4AF37)]
              : (isDark
                  ? [const Color(0xFF1E1E1E), const Color(0xFF282828)]
                  : [Colors.white, const Color(0xFFF7F9FC)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDoneAll ? Colors.amberAccent : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDoneAll ? Colors.white.withValues(alpha: 0.25) : AppColors.midTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDoneAll ? Icons.celebration_rounded : Icons.task_alt_rounded,
                  color: isDoneAll ? Colors.white : AppColors.midTeal,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDoneAll ? 'All Rituals Completed! 🎉' : 'Finish or Restart Journey',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDoneAll ? Colors.white : (_isDarkMode ? Colors.white : AppColors.navyBlue),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDoneAll
                          ? 'Save to your Journey History and prepare fresh for next time.'
                          : 'Archive your journey when finished or reset progress anytime.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDoneAll ? Colors.white.withValues(alpha: 0.88) : (_isDarkMode ? Colors.white60 : AppColors.navyBlue.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Show warning banner if Hajj season validation fails
          if (!canArchive && hajjSeasonWarning.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDoneAll
                    ? Colors.black.withValues(alpha: 0.22)
                    : AppColors.coralOrange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDoneAll
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.coralOrange.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: isDoneAll ? Colors.white : AppColors.coralOrange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hajjSeasonWarning,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: isDoneAll
                            ? Colors.white
                            : (isDark ? Colors.orange.shade200 : AppColors.coralOrange),
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canArchive
                      ? () => _showCompleteJourneyDialog(completedCount, totalCount)
                      : null,
                  icon: Icon(
                    canArchive ? Icons.bookmark_added_rounded : Icons.lock_clock_rounded,
                    size: 16,
                  ),
                  label: Text(
                    canArchive ? 'Complete & Archive' : 'Archive — Outside Hajj Season',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canArchive
                        ? (isDoneAll ? Colors.white : AppColors.midTeal)
                        : (isDark ? Colors.white12 : Colors.grey.shade200),
                    foregroundColor: canArchive
                        ? (isDoneAll ? const Color(0xFF8B6508) : Colors.white)
                        : Colors.grey,
                    disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _showResetConfirmDialog,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDoneAll ? Colors.white70 : (_isDarkMode ? Colors.white24 : Colors.black26)),
                  foregroundColor: isDoneAll ? Colors.white : (_isDarkMode ? Colors.white70 : AppColors.navyBlue),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Reset', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPenaltyGlossaryModal() {
    final isDark = _isDarkMode;
    final bgC = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textC = isDark ? Colors.white : AppColors.navyBlue;
    final subC = isDark ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.65);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: bgC,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.dustyBlueTeal.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: AppColors.midTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Understanding Hajj Penalties',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textC,
                          ),
                        ),
                        Text(
                          'Dam vs. Fidyah vs. Repeat Explained',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppColors.midTeal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Scrollable Terms Content
              Expanded(
                child: ListView(
                  children: [
                    // Term 1: Dam
                    _buildGlossaryItem(
                      icon: Icons.priority_high_rounded,
                      iconColor: AppColors.coralOrange,
                      title: '1. Dam (دم / Mandatory Sacrifice)',
                      badge: 'Compulsory Sacrifice (1 Sheep in Makkah)',
                      badgeColor: AppColors.coralOrange,
                      desc: 'Slaughtering one sheep or goat within the Haram boundary of Makkah and distributing its meat to the poor.\n\n'
                          '• When it applies: Required for omitting an obligatory act (Wajib) of Hajj or Umrah (e.g. crossing Miqat without Ihram, leaving Arafat before sunset, omitting Rami al-Jamarat, or leaving without Tawaf al-Wida).\n'
                          '• Note: Fasting or feeding is NOT an alternative for Dam unless the person is financially completely unable to afford the animal.',
                      isDark: isDark,
                      textC: textC,
                      subC: subC,
                    ),
                    const SizedBox(height: 12),

                    // Term 2: Fidyah of Choice
                    _buildGlossaryItem(
                      icon: Icons.tune_rounded,
                      iconColor: AppColors.dustyBlueTeal,
                      title: '2. Fidyah of Choice (فدية التخيير / Pick 1 of 3)',
                      badge: 'Flexible Choice (Pick ANY 1)',
                      badgeColor: AppColors.midTeal,
                      desc: 'Based on Surah Al-Baqarah (2:196) and the Hadith of Ka\'b ibn Ujrah (RA), when an Ihram restriction is breached (e.g. cutting hair/nails, wearing perfume, or men wearing stitched clothes), Allah in His mercy allows the pilgrim to choose ANY ONE of the following three options:\n\n'
                          '  Option 1: Fast for 3 days (can be done anywhere, even back home).\n'
                          '  Option 2: Feed 6 poor persons in Makkah (half Sa\' / ~1.5 kg of food each).\n'
                          '  Option 3: Sacrifice 1 sheep in Makkah for the poor.\n\n'
                          '• Why it is called "Choice": You are 100% free to choose whichever option is easiest for you.',
                      isDark: isDark,
                      textC: textC,
                      subC: subC,
                      isHighlighted: true,
                    ),
                    const SizedBox(height: 12),

                    // Term 3: Repeat / Valid Circuit
                    _buildGlossaryItem(
                      icon: Icons.replay_rounded,
                      iconColor: AppColors.midTeal,
                      title: '3. Repeat the Rite (إعادة النسك)',
                      badge: 'Redo in Pure State',
                      badgeColor: AppColors.midTeal,
                      desc: 'Re-performing an invalid circuit or lap to make the ritual valid.\n\n'
                          '• When it applies: If Tawaf was performed without Wudu, or if any round of Tawaf passed inside the Hateem (Hijr Ismail), that circuit does not count and must simply be repeated in a valid manner without slaughtering an animal.',
                      isDark: isDark,
                      textC: textC,
                      subC: subC,
                    ),
                    const SizedBox(height: 12),

                    // Term 4: Sincere Istighfar
                    _buildGlossaryItem(
                      icon: Icons.spa_outlined,
                      iconColor: AppColors.dustyBlueTeal,
                      title: '4. Sincere Istighfar (استغفار / Repentance)',
                      badge: 'No Penalty',
                      badgeColor: AppColors.dustyBlueTeal,
                      desc: 'For inadvertent forgetfulness (e.g. smelling scented soap by mistake and washing it off immediately, or a hair falling accidentally while scratching), there is no penalty or sacrifice required by scholarly consensus; simply make sincere Istighfar.',
                      isDark: isDark,
                      textC: textC,
                      subC: subC,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlossaryItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String badge,
    required Color badgeColor,
    required String desc,
    required bool isDark,
    required Color textC,
    required Color subC,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.midTeal.withValues(alpha: isDark ? 0.12 : 0.08)
            : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF7F9FB)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? AppColors.midTeal.withValues(alpha: 0.4)
              : (isDark ? Colors.white12 : Colors.black12),
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: GoogleFonts.inter(fontSize: 11, color: subC, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ===== MISTAKES & FIDYAH TAB (STYLED LIKE ZAKAT RULES) =====
  Widget _buildMistakesTab() {
    final isDark = _isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textC = isDark ? Colors.white : AppColors.navyBlue;
    final subC = isDark ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.65);

    const categories = ['All', 'Ihram', 'Tawaf & Sa\'i', 'Arafat & Mina', 'Rami & Qurbani'];

    final filteredMistakes = _hajjMistakes.where((m) {
      final matchesCategory = _mistakeCategoryFilter == 'All' || m.category == _mistakeCategoryFilter;
      final q = _mistakeSearchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          m.title.toLowerCase().contains(q) ||
          m.mistakeDesc.toLowerCase().contains(q) ||
          m.remedy.toLowerCase().contains(q) ||
          m.kaffarahType.toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // 1. Zakat-style Grand Header Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A2E40), const Color(0xFF0F1E2B)]
                  : [AppColors.navyBlue, const Color(0xFF243E54)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.navyBlue.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hajj Mistakes & Fidyah Guide',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'أَحْكَامُ الْحَجِّ وَالْفِدْيَةِ فِي الشَّرِيعَةِ الإِسْلَامِيَّةِ',
                          style: GoogleFonts.amiri(
                            color: AppColors.dustyBlueTeal,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Comprehensive fiqh guide covering common mistakes, required penalties (Dam vs. Fidyah of Choice), and authentic Quranic & Hadith rulings.',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              // Mini Status Badges
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildHeroMiniBadge(
                    label: 'Dam (Sacrifice)',
                    dotColor: AppColors.coralOrange,
                  ),
                  _buildHeroMiniBadge(
                    label: 'Fidyah (Pick 1 of 3)',
                    dotColor: AppColors.dustyBlueTeal,
                  ),
                  _buildHeroMiniBadge(
                    label: 'Repeat Rite',
                    dotColor: AppColors.midTeal,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Interactive Penalty Glossary Banner
        GestureDetector(
          onTap: _showPenaltyGlossaryModal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2833) : AppColors.dustyBlueTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : AppColors.dustyBlueTeal.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.midTeal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.midTeal),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What is Dam vs. Fidyah of Choice?',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textC,
                        ),
                      ),
                      Text(
                        'Tap to understand how Fidyah (Fast / Feed / Sacrifice) works.',
                        style: GoogleFonts.inter(fontSize: 10.5, color: subC),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.midTeal),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 3. Search Field
        TextField(
          onChanged: (val) => setState(() => _mistakeSearchQuery = val),
          style: GoogleFonts.inter(fontSize: 13, color: textC),
          decoration: InputDecoration(
            hintText: 'Search mistakes, rituals, or penalties...',
            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: subC),
            prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppColors.midTeal),
            suffixIcon: _mistakeSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                    onPressed: () => setState(() => _mistakeSearchQuery = ''),
                  )
                : null,
            filled: true,
            fillColor: cardBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : AppColors.dustyBlueTeal.withValues(alpha: 0.25),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : AppColors.dustyBlueTeal.withValues(alpha: 0.25),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.midTeal, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 4. Category Filter Chips (Themed Pills)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSel = _mistakeCategoryFilter == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _mistakeCategoryFilter = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel
                          ? (isDark ? AppColors.dustyBlueTeal : AppColors.navyBlue)
                          : (isDark ? const Color(0xFF1E2833) : AppColors.dustyBlueTeal.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSel
                            ? (isDark ? AppColors.dustyBlueTeal : AppColors.navyBlue)
                            : (isDark ? Colors.white24 : AppColors.dustyBlueTeal.withValues(alpha: 0.35)),
                        width: isSel ? 1.4 : 1,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        color: isSel
                            ? (isDark ? AppColors.navyBlue : Colors.white)
                            : (isDark ? Colors.white70 : AppColors.navyBlue),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // 5. Mistakes Cards
        if (filteredMistakes.isEmpty)
          Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 40, color: subC),
                  const SizedBox(height: 10),
                  Text(
                    'No matching rulings found',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: textC),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try searching with another keyword or selecting "All".',
                    style: GoogleFonts.inter(fontSize: 12, color: subC),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredMistakes.map((m) => _buildMistakeCard(m, cardBg, textC, subC)),
      ],
    );
  }

  Widget _buildHeroMiniBadge({required String label, required Color dotColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMistakeCard(HajjMistake m, Color cardBg, Color textC, Color subC) {
    final isDark = _isDarkMode;
    final isWajib = m.severity.contains('Dam') || m.severity.contains('Wajib');
    final iconColor = isWajib ? AppColors.coralOrange : AppColors.midTeal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : AppColors.navyBlue.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isWajib ? Icons.priority_high_rounded : Icons.info_outline_rounded,
              color: iconColor,
              size: 17,
            ),
          ),
          title: Text(
            m.title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    m.severity,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
                Text(
                  '• ${m.category}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: subC,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          children: [
            Container(
              height: 1,
              color: isDark ? Colors.white10 : AppColors.navyBlue.withValues(alpha: 0.06),
              margin: const EdgeInsets.only(bottom: 12),
            ),

            // 1. Mistake Description Section
            _buildMistakeDetailSection(
              icon: Icons.help_outline_rounded,
              iconColor: AppColors.coralOrange,
              title: 'What is the mistake?',
              content: m.mistakeDesc,
              textC: textC,
              subC: subC,
            ),
            const SizedBox(height: 10),

            // 2. Remedy & Required Penalty Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.midTeal.withValues(alpha: isDark ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.midTeal.withValues(alpha: isDark ? 0.35 : 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 15, color: AppColors.midTeal),
                      const SizedBox(width: 6),
                      Text(
                        'Remedy & Required Penalty:',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.midTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    m.remedy,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: textC,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black38 : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: AppColors.midTeal.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(Icons.label_important_rounded, size: 13, color: AppColors.midTeal),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Required: ${m.kaffarahType}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.midTeal,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3. Quran Reference Card (Compact & Aesthetic)
            _buildQuranReferenceCard(
              arabicText: m.arabicAyah,
              englishText: m.englishAyah,
              reference: m.quranRef,
            ),
            const SizedBox(height: 6),

            // 4. Hadith Reference Card (Compact & Aesthetic)
            _buildHadithReferenceCard(
              arabicText: m.arabicHadith,
              englishText: m.englishHadith,
              reference: m.hadithRef,
            ),
            const SizedBox(height: 8),

            // 5. Fiqh Guidance Note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.dustyBlueTeal.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppColors.midTeal),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Fiqh Guidance: ${m.fiqhExplanation}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: textC.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuranReferenceCard({
    required String arabicText,
    required String englishText,
    required String reference,
  }) {
    final isDark = _isDarkMode;
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.midTeal.withValues(alpha: isDark ? 0.20 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.midTeal.withValues(alpha: isDark ? 0.35 : 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.midTeal,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded, color: Colors.white, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      'QURAN',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reference,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF80CBC4) : AppColors.midTeal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            arabicText,
            textAlign: TextAlign.right,
            style: GoogleFonts.amiri(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFA5D6A7) : const Color(0xFF0D3B2E),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '"$englishText"',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHadithReferenceCard({
    required String arabicText,
    required String englishText,
    required String reference,
  }) {
    final isDark = _isDarkMode;
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navyBlue.withValues(alpha: isDark ? 0.20 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.navyBlue.withValues(alpha: isDark ? 0.35 : 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.navyBlue,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_rounded, color: Colors.white, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      'HADITH',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reference,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF90CAF9) : AppColors.navyBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            arabicText,
            textAlign: TextAlign.right,
            style: GoogleFonts.amiri(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF90CAF9) : AppColors.navyBlue,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '"$englishText"',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMistakeDetailSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required Color textC,
    required Color subC,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13.5, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: textC),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            content,
            style: GoogleFonts.inter(fontSize: 10.5, color: subC, height: 1.4),
          ),
        ),
      ],
    );
  }

  // ===== REWARD OF HAJJ & UMRAH CARD =====
  Widget _buildRewardOfHajjCard() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyBlue, Color(0xFF132433)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.dustyBlueTeal.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyBlue.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.dustyBlueTeal.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stars_rounded, color: AppColors.dustyBlueTeal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The Reward of Hajj & Umrah',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Immense Virtues & Blessings',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.dustyBlueTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Quote (Italicized Hadith)
          Text(
            '"Whoever performs Hajj for the sake of Allah and does not commit obscenity or evil deeds will return as sinless as the day his mother gave birth to him."',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '— Prophet Muhammad (ﷺ) [Sahih al-Bukhari 1521, Sahih Muslim 1350]',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: AppColors.dustyBlueTeal,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Inner Container with Key Virtues
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                _buildVirtueRow(
                  icon: Icons.stars_rounded,
                  title: 'No Reward Other than Paradise',
                  desc: 'The accepted Hajj (Hajj Mabrur) has no reward other than Jannah. (Sahih al-Bukhari 1773)',
                ),
                const SizedBox(height: 10),
                _buildVirtueRow(
                  icon: Icons.shield_outlined,
                  title: 'Removes Poverty & Sins',
                  desc: 'Perform Hajj and Umrah consecutively, for they eradicate poverty and sins as the furnace removes impurity from iron. (Tirmidhi 810)',
                ),
                const SizedBox(height: 10),
                _buildVirtueRow(
                  icon: Icons.favorite_border_rounded,
                  title: 'Honored Guests of Allah',
                  desc: 'Pilgrims are the guests of Allah: if they pray, He responds; if they seek forgiveness, He pardons them. (Ibn Majah 2892)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtueRow({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.dustyBlueTeal.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: AppColors.dustyBlueTeal),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.78), height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== HISTORY TAB =====
  Widget _buildHistoryTab() {
    final isDark = _isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.navyBlue;
    final subtextColor = isDark ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.65);

    if (_history.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : AppColors.navyBlue.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_edu_rounded,
                    size: 46,
                    color: isDark ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Past Journeys Yet',
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'When you complete your Hajj or Umrah, click "Complete & Archive" to save your sacred memories and pilgrimage dates here.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: subtextColor, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _tab = 0),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text('Go to Current Planner', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                _buildRewardOfHajjCard(),
              ],
            ),
          ),
        ],
      );
    }

    final hajjCount = _history.where((p) => p.mode == 'Hajj').length;
    final umrahCount = _history.where((p) => p.mode == 'Umrah').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Summary Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E3A3A), const Color(0xFF0F2626)]
                  : [AppColors.navyBlue, const Color(0xFF1F3A52)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('$hajjCount', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                  Text('Hajj Completed', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                ],
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              Column(
                children: [
                  Text('$umrahCount', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Umrah Completed', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                ],
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              Column(
                children: [
                  Text('${_history.length}', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                  Text('Total Journeys', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Completed Pilgrimages',
              style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor)),
        ),
        ..._history.map((item) {
          final isHajj = item.mode == 'Hajj';
          final badgeColor = isHajj ? const Color(0xFFD4AF37) : AppColors.midTeal;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(isHajj ? Icons.mosque_rounded : Icons.flight_takeoff_rounded, size: 13, color: badgeColor),
                              const SizedBox(width: 5),
                              Text(
                                '${item.mode} ${isHajj && item.hajjType != '-' ? '(${item.hajjType})' : ''}',
                                style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: badgeColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            title: Text('Delete this record?',
                                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                            content: Text('Are you sure you want to remove this ${item.mode} from history?',
                                style: GoogleFonts.inter(fontSize: 12.5, color: subtextColor)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey))),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  setState(() => _history.removeWhere((h) => h.id == item.id));
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('hajj_history', jsonEncode(_history.map((e) => e.toJson()).toList()));
                                  await _updateFirestoreHajjUmrah();
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                child: Text('Delete', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.event_available_rounded, size: 14, color: AppColors.midTeal),
                    const SizedBox(width: 6),
                    Text(
                      'Completed on ${DateFormat('dd MMMM, yyyy').format(item.completionDate)}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                    ),
                  ],
                ),
                if (item.startDate != null && item.endDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.date_range_rounded, size: 14, color: subtextColor),
                      const SizedBox(width: 6),
                      Text(
                        'Trip Period: ${DateFormat('dd MMM').format(item.startDate!)} – ${DateFormat('dd MMM, yyyy').format(item.endDate!)}',
                        style: GoogleFonts.inter(fontSize: 11.5, color: subtextColor),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 14, color: subtextColor),
                    const SizedBox(width: 6),
                    Text(
                      'Rituals: ${item.completedRituals} / ${item.totalRituals} Done',
                      style: GoogleFonts.inter(fontSize: 11.5, color: subtextColor),
                    ),
                  ],
                ),
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '"${item.note}"',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: textColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildChecklistTile({
    required String label,
    required bool isDone,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.midTeal : cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone ? AppColors.midTeal : (_isDarkMode ? Colors.white38 : AppColors.navyBlue.withValues(alpha: 0.25)),
                    width: 1.6,
                  ),
                ),
                child: isDone ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 16, color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.35)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDone
                        ? (_isDarkMode ? Colors.white38 : AppColors.navyBlue.withValues(alpha: 0.4))
                        : textColor,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== JOURNEY PATH PAINTER =====
class _JourneyPathPainter extends CustomPainter {
  final List<Offset> points;
  final List<double> progresses;
  final Color baseColor;
  final Color glowColor;

  static const Color _brightGreen = Color(0xFF6FE6A8);

  _JourneyPathPainter({
    required this.points,
    required this.progresses,
    required this.baseColor,
    required this.glowColor,
  });

  Offset _cubicPoint(Offset p0, Offset c0, Offset c1, Offset p1, double t) {
    final u = 1 - t;
    final tt = t * t;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * t;
    final x = uuu * p0.dx + 3 * uu * t * c0.dx + 3 * u * tt * c1.dx + ttt * p1.dx;
    final y = uuu * p0.dy + 3 * uu * t * c0.dy + 3 * u * tt * c1.dy + ttt * p1.dy;
    return Offset(x, y);
  }

  Path _partialCubic(Offset p0, Offset p1, double progress, {int steps = 28}) {
    final midY = (p0.dy + p1.dy) / 2;
    final c0 = Offset(p0.dx, midY);
    final c1 = Offset(p1.dx, midY);
    final path = Path()..moveTo(p0.dx, p0.dy);
    final segCount = (steps * progress).ceil().clamp(1, steps);
    for (int s = 1; s <= segCount; s++) {
      final t = (s / steps).clamp(0.0, progress);
      final pt = _cubicPoint(p0, c0, c1, p1, t);
      path.lineTo(pt.dx, pt.dy);
    }
    return path;
  }

  List<Offset> _partialCubicPoints(Offset p0, Offset p1, double progress, {int steps = 80}) {
    final midY = (p0.dy + p1.dy) / 2;
    final c0 = Offset(p0.dx, midY);
    final c1 = Offset(p1.dx, midY);
    final segCount = (steps * progress).ceil().clamp(1, steps);
    final pts = <Offset>[p0];
    for (int s = 1; s <= segCount; s++) {
      final t = (s / steps).clamp(0.0, progress);
      pts.add(_cubicPoint(p0, c0, c1, p1, t));
    }
    return pts;
  }

  void _drawDashedPolyline(
    Canvas canvas,
    List<Offset> pts,
    Paint paint, {
    double dashWidth = 6,
    double dashSpace = 7,
  }) {
    if (pts.length < 2) return;
    final cycle = dashWidth + dashSpace;
    double distanceIntoPattern = 0;

    for (int i = 0; i < pts.length - 1; i++) {
      final segStart = pts[i];
      final segEnd = pts[i + 1];
      final segLength = (segEnd - segStart).distance;
      if (segLength == 0) continue;

      double travelled = 0;
      while (travelled < segLength) {
        final posInCycle = distanceIntoPattern % cycle;
        final isDash = posInCycle < dashWidth;
        final remainInPhase = isDash ? (dashWidth - posInCycle) : (cycle - posInCycle);
        final stepLength = (segLength - travelled) < remainInPhase
            ? (segLength - travelled)
            : remainInPhase;

        final tStart = travelled / segLength;
        final tEnd = (travelled + stepLength) / segLength;
        final a = Offset.lerp(segStart, segEnd, tStart)!;
        final b = Offset.lerp(segStart, segEnd, tEnd)!;

        if (isDash) {
          canvas.drawLine(a, b, paint);
        }

        travelled += stepLength;
        distanceIntoPattern += stepLength;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final fullPath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midY = (p0.dy + p1.dy) / 2;
      fullPath.cubicTo(p0.dx, midY, p1.dx, midY, p1.dx, p1.dy);
    }

    final dashPaint = Paint()
      ..color = baseColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double dashWidth = 6;
    const double dashSpace = 7;

    for (final metric in fullPath.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          dashPaint,
        );
        distance += dashWidth + dashSpace;
      }
    }

    for (int i = 0; i < points.length - 1; i++) {
      final progress = i < progresses.length ? progresses[i] : 0.0;
      if (progress <= 0.001) continue;

      final p0 = points[i];
      final p1 = points[i + 1];
      final extracted = _partialCubic(p0, p1, progress);
      final sampledPts = _partialCubicPoints(p0, p1, progress);

      final haloPaint = Paint()
        ..color = _brightGreen.withValues(alpha: 0.20)
        ..strokeWidth = 20
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawPath(extracted, haloPaint);

      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.45)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawPath(extracted, glowPaint);

      final corePaint = Paint()
        ..color = _brightGreen
        ..strokeWidth = 4.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      _drawDashedPolyline(canvas, sampledPts, corePaint, dashWidth: 7, dashSpace: 6);

      if (progress < 1.0 && progress > 0.02) {
        final midY = (p0.dy + p1.dy) / 2;
        final leadPoint = _cubicPoint(p0, Offset(p0.dx, midY), Offset(p1.dx, midY), p1, progress);
        canvas.drawCircle(
          leadPoint,
          11,
          Paint()
            ..color = _brightGreen.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawCircle(leadPoint, 5.5, Paint()..color = _brightGreen);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _JourneyPathPainter oldDelegate) => true;
}