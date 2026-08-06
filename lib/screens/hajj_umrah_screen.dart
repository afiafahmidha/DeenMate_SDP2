import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/auth_header.dart'; // AppColors
import 'hajj_ritual_detail_screen.dart';

class HajjUmrahPlannerScreen extends StatefulWidget {
  const HajjUmrahPlannerScreen({super.key});

  @override
  State<HajjUmrahPlannerScreen> createState() => _HajjUmrahPlannerScreenState();
}

class _HajjUmrahPlannerScreenState extends State<HajjUmrahPlannerScreen>
    with TickerProviderStateMixin {
  int _tab = 0;
  static const _tabLabels = ['Rituals', 'Packing', 'Documents', 'Duas'];
  static const _tabIcons = [
    Icons.auto_awesome_rounded,
    Icons.local_offer_rounded,
    Icons.folder_open_rounded,
    Icons.chat_bubble_rounded,
  ];
  String _mode = 'Hajj'; // 'Hajj' or 'Umrah'
  String _hajjType = 'Tamattu'; // 'Tamattu', 'Qiran', or 'Ifrad'
  bool _isDarkMode = false;

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
      'overviewEn':
          'For Hajj al-Tamattu\', pilgrims re-enter the state of Ihram on the 8th of Dhul Hijjah from their hotel or residence in Makkah. It involves physical purification, putting on the Ihram garments, making the intention for Hajj, and chanting the Talbiyah.',
      'overviewAr':
          'بالنسبة لحج التمتع، يحرم الحاج بالحج ضحى يوم التروية (٨ ذو الحجة) من مكان إقامته في مكة المكرمة، حيث يغتسل ويتطيب ويلبس ملابس الإحرام وينوي الحج قائلاً: لَبَّيْكَ اللَّهُمَّ حَجًّا.',
      'keyActionsEn': [
        'Perform Ghusl (ritual bath) at your residence in Makkah.',
        'Wear Ihram garments (for men) or modest dress (for women).',
        'Offer 2 Rakah prayer if possible, then make intention: "Labbayk Allahumma Hajjah" (لَبَّيْكَ اللَّهُمَّ حَجًّا).',
        'Begin reciting Talbiyah: "Labbayk Allahumma Labbayk..."',
      ],
      'keyActionsAr': [
        'الاغتسال والتنظف في السكن بمكة المكرمة.',
        'لبس الإزار والرداء للرجال واللباس الساتر للمرأة.',
        'صلاة ركعتين ثم النية: "لَبَّيْكَ اللَّهُمَّ حَجًّا".',
        'البدء في التلبية ورفع الصوت بها للرجال.',
      ],
      'quran': {
        'textAr': 'وَأَتِمُّوا الْحَجَّ وَالْعُمْرَةَ لِلَّهِ',
        'referenceAr': 'سورة البقرة - الآية ١٩٦',
        'textEn': 'And complete the Hajj and Umrah for Allah.',
        'referenceEn': 'Surah Al-Baqarah (2:196)',
        'explanationEn': 'Divine command to complete the rituals of Hajj and Umrah sincerely for the sake of Allah.',
        'explanationAr': 'الأمر بوجوب إكمال أعمال الحج والعمرة وإخلاصها لله تعالى.',
      },
      'hadith': {
        'textAr': 'عَنْ جَابِرٍ رَضِيَ اللَّهُ عَنْهُ: «أَمَرَنَا النَّبِيُّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ لَمَّا حَلَلْنَا أَنْ نُحْرِمَ إِذَا تَوَجَّهْنَا إِلَى مِنًى، فَأَهْلَلْنَا مِنَ الأَبْطَحِ»',
        'referenceAr': 'صحيح البخاري وصحيح مسلم',
        'textEn': 'Jabir narrated: "The Prophet (ﷺ) commanded us to assume Ihram when we directed ourselves towards Mina; so we assumed Ihram from Al-Abtah (Makkah Residence)."',
        'referenceEn': 'Sahih al-Bukhari & Sahih Muslim',
        'explanationEn': 'This Hadith establishes that pilgrims performing Tamattu\' should enter Ihram for Hajj from their location of stay in Makkah on the 8th of Dhul Hijjah.',
        'explanationAr': 'يوضح الحديث سنة الإحرام بالحج من مكة عند التوجه إلى منى في يوم التروية.',
      },
      'dua': {
        'title': 'Intention for Hajj (Tamattu\')',
        'arabic': 'لَبَّيْكَ اللَّهُمَّ حَجًّا',
        'translit': 'Labbayk Allahumma Hajjah',
        'meaningEn': 'O Allah, I answer Your call to perform Hajj.',
        'meaningAr': 'التلفظ بالنية للدخول في مناسك الحج.',
      },
    },

    'ihram_qiran': {
      'titleEn': 'Enter Ihram for Hajj Qiran',
      'titleAr': 'الإحرام لحج القران',
      'day': 'At Miqat - Before entering the Haram boundaries',
      'dayAr': 'الميقات - قبل دخول حدود الحرم',
      'overviewEn':
          'In Hajj al-Qiran, the pilgrim enters the state of Ihram at the Miqat with the intention of performing both Umrah and Hajj combined. The pilgrim remains in Ihram without shaving or cutting hair after Umrah, staying in Ihram until the 10th of Dhul Hijjah.',
      'overviewAr':
          'حج القران هو أن يحرم الحاج بالعمرة والحج معاً من الميقات، أو يحرم بالعمرة ثم يدخل عليها الحج قبل الطواف. ويلتزم بمحظورات الإحرام ولا يتحلل منه بعد طواف القدوم وسعيه بل يبقى محرماً حتى يوم النحر.',
      'keyActionsEn': [
        'Perform Ghusl and wear Ihram garments at the Miqat.',
        'Make intention for both Hajj and Umrah: "Labbayk Allahumma Hajjah wa Umrah" (لَبَّيْكَ اللَّهُمَّ حَجًّا وَعُمْرَةً).',
        'Begin reciting Talbiyah and maintain Ihram restrictions throughout.',
      ],
      'keyActionsAr': [
        'الغسل والنظافة ولبس ملابس الإحرام في الميقات.',
        'النية للنسكين معاً: "لَبَّيْكَ اللَّهُمَّ حَجًّا وَعُمْرَةً".',
        'الاستمرار في التلبية والالتزام الكامل بمحظورات الإحرام.',
      ],
      'quran': {
        'textAr': 'فَمَن تَمَتَّعَ بِالْعُمْرَةِ إِلَى الْحَجِّ فَمَا اسْتَيْسَرَ مِنَ الْهَدْيِ',
        'referenceAr': 'سورة البقرة - الآية ١٩٦',
        'textEn': 'Then whoever performs Umrah [during the Hajj months] followed by Hajj, [offers] what can be obtained with ease of sacrificial animals.',
        'referenceEn': 'Surah Al-Baqarah (2:196)',
        'explanationEn': 'The Quran commands those who combine Umrah and Hajj (Tamattu\' or Qiran) to offer an animal sacrifice (Qurbani) out of gratitude.',
        'explanationAr': 'وجوب الهدي (ذبْح شاة) شُكراً لله على تيسير الجمع بين النسكين في سفرة واحدة.',
      },
      'hadith': {
        'textAr': 'عَنْ أَنَسٍ رَضِيَ اللَّهُ عَنْهُ قَالَ: سَمِعْتُ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ يَقُولُ: «لَبَّيْكَ عُمْرَةً وَحَجًّا»',
        'referenceAr': 'صحيح مسلم (١٢٥١)',
        'textEn': 'Anas reported: "I heard the Messenger of Allah (ﷺ) saying: Labbayk for Umrah and Hajj together."',
        'referenceEn': 'Sahih Muslim 1251',
        'explanationEn': 'This Hadith provides direct evidence for the legality of Qiran (combining Hajj and Umrah in one Ihram).',
        'explanationAr': 'دليل صريح على مشروعية حج القران وهو ما فعله النبي صلى الله عليه وسلم في حجته.',
      },
      'dua': {
        'title': 'Intention for Hajj Qiran',
        'arabic': 'لَبَّيْكَ اللَّهُمَّ حَجًّا وَعُمْرَةً',
        'translit': 'Labbayk Allahumma Hajjah wa \'Umrah',
        'meaningEn': 'O Allah, I answer Your call to perform Hajj and Umrah together.',
        'meaningAr': 'النية للجمع بين العمرة والحج في إحرام واحد.',
      },
    },

    'ihram_ifrad': {
      'titleEn': 'Enter Ihram for Hajj Ifrad',
      'titleAr': 'الإحرام لحج الإفراد',
      'day': 'At Miqat - Before entering the Haram boundaries',
      'dayAr': 'الميقات - قبل دخول حدود الحرم',
      'overviewEn':
          'Hajj al-Ifrad is performing Hajj alone, without Umrah. The pilgrim enters Ihram at the Miqat with the intention of Hajj only, performs Tawaf al-Qudum, and remains in the state of Ihram until the 10th of Dhul Hijjah. No sacrificial animal (Hady) is obligatory for Ifrad.',
      'overviewAr':
          'حج الإفراد هو أن يحرم الحاج بالحج وحده من الميقات قائلاً: لَبَّيْكَ اللَّهُمَّ حَجًّا. ويطوف للقدوم ويسعى للحج ويبقى على إحرامه حتى يوم النحر. ولا يجب عليه الهدي (ذبح فدية).',
      'keyActionsEn': [
        'Perform Ghusl and wear Ihram garments at the Miqat.',
        'Make intention for Hajj only: "Labbayk Allahumma Hajjah" (لَبَّيْكَ اللَّهُمَّ حَجًّا).',
        'Recite Talbiyah and strictly follow Ihram rules until the 10th of Dhul Hijjah.',
      ],
      'keyActionsAr': [
        'الاغتسال ولبس ثياب الإحرام في الميقات.',
        'النية للحج فقط: "لَبَّيْكَ اللَّهُمَّ حَجًّا".',
        'الالتزام بالتلبية ومحظورات الإحرام إلى يوم عيد الأضحى.',
      ],
      'quran': {
        'textAr': 'وَلِلَّهِ عَلَى النَّاسِ حِجُّ الْبَيْتِ مَنِ اسْتَتَاعَ إِلَيْهِ سَبِيلًا',
        'referenceAr': 'سورة آل عمران - الآية ٩٧',
        'textEn': 'And [due] to Allah from the people is a pilgrimage to the House - for whoever is able to find thereto a way.',
        'referenceEn': 'Surah Ali \'Imran (3:97)',
        'explanationEn': 'This general command shows Hajj itself is the core duty, which the Mufrid (pilgrim performing Ifrad) fulfills directly.',
        'explanationAr': 'وجوب الحج العيني على المستطيع مرة واحدة في العمر.',
      },
      'hadith': {
        'textAr': 'عَنْ عَائِشَةَ رَضِيَ اللَّهُ عَنْهَا قَالَتْ: «خَرَجْنَا مَعَ رَسُولِ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ... فَمِنَّا مَنْ أَهَلَّ بِعُمْرَةٍ، وَمِنَّا مَنْ أَهَلَّ بِحَجٍّ وَعُمْرَةٍ، وَمِنَّا مَنْ أَهَلَّ بِحَجٍّ مُفْرِدٍ»',
        'referenceAr': 'صحيح البخاري وصحيح مسلم',
        'textEn': 'Aisha narrated: "We set out with the Messenger of Allah (ﷺ)... some of us assumed Ihram for Umrah, some for both Hajj and Umrah, and some for Hajj only (Ifrad)."',
        'referenceEn': 'Sahih al-Bukhari & Sahih Muslim',
        'explanationEn': 'This confirms that all three types of Hajj (Tamattu\', Qiran, and Ifrad) are valid and were practiced by the Companions under the guidance of the Prophet.',
        'explanationAr': 'دليل على جواز الإفراد وتخيير الحاج بين الأنساك الثلاثة.',
      },
      'dua': {
        'title': 'Intention for Hajj Ifrad',
        'arabic': 'لَبَّيْكَ اللَّهُمَّ حَجًّا',
        'translit': 'Labbayk Allahumma Hajjah',
        'meaningEn': 'O Allah, I answer Your call to perform Hajj.',
        'meaningAr': 'النية لأداء الحج مفرداً.',
      },
    },

    'halq_ifrad': {
      'titleEn': 'Halq or Taqsir (Shaving or Trimming)',
      'titleAr': 'الحلق أو التقصير للمفرد',
      'day': '10th Dhul Hijjah (Yawm an-Nahr)',
      'dayAr': '١٠ ذو الحجة (يوم النحر)',
      'overviewEn':
          'After stoning Jamarat al-Aqabah on the 10th of Dhul Hijjah, the pilgrim performing Hajj Ifrad shaves or trims their hair to complete the first partial deconsecration (Tahallul al-Asghar). Because this is Hajj Ifrad, Qurbani (sacrifice) is not obligatory, so they proceed directly from stoning to shaving.',
      'overviewAr':
          'بعد رمي جمرة العقبة الكبرى يوم النحر، يقوم المفرد بحلق رأسه أو تقصيره مباشرة (حيث لا يجب عليه ذبح هدي) ليتحلل التحلل الأول، فيلبس ثيابه ويتطيب وتزول عنه محظورات الإحرام عدا النساء.',
      'keyActionsEn': [
        'Proceed directly to shave (Halq) or trim (Taqsir) hair after pelting.',
        'Men are highly recommended to shave completely.',
        'Women trim a fingertip length of hair.',
        'Achieve Tahallul al-Asghar and change into regular clothes.',
      ],
      'keyActionsAr': [
        'الحلق بالموسى للرجال وهو الأفضل، أو تقصير كامل الرأس.',
        'تقصير النساء قدر أنملة من أطراف الشعر.',
        'التحلل الأصغر ولبس المخيط والتطيب.',
      ],
      'quran': {
        'textAr': 'مُحَلِّقِينَ رُءُوسَكُمْ وَمُقَصِّرِينَ لَا تَخَافُونَ',
        'referenceAr': 'سورة الفتح - الآية ٢٧',
        'textEn': 'With your heads shaved and hair shortened, not fearing.',
        'referenceEn': 'Surah Al-Fath (48:27)',
        'explanationEn': 'Shaving and trimming are recognized by Allah as the sacred conclusion of the state of Ihram.',
        'explanationAr': 'مشروعية الحلق والتقصير لإنهاء الإحرام والتحلل.',
      },
      'hadith': {
        'textAr': 'عَنِ ابْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ حَلَقَ فِي حَجَّتِهِ',
        'referenceAr': 'صحيح البخاري وصحيح مسلم',
        'textEn': 'Ibn Umar narrated: "The Messenger of Allah (ﷺ) had his head shaved during his Hajj pilgrimage."',
        'referenceEn': 'Sahih al-Bukhari & Sahih Muslim',
        'explanationEn': 'Prophetic action showing head shaving is the optimal way to conclude the pilgrimage.',
        'explanationAr': 'اقتداء الحجاج بالنبي صلى الله عليه وسلم بالحلق يوم النحر.',
      },
      'dua': {
        'title': 'Dua of Gratitude upon Shaving',
        'arabic': 'الْحَمْدُ لِلَّهِ الَّذِي قَضَى عَنَّا نُسُكَنَا',
        'translit': 'Alhamdu lillahil-ladhi qada \'anna nusukana',
        'meaningEn': 'Praise be to Allah Who has enabled us to complete our rituals.',
        'meaningAr': 'الحمد والشكر لله على إتمام مناسك التحلل الأصغر.',
      },
    },

    'sai_h': {
      'titleEn': 'Sa’i of Hajj (Safa & Marwah)',
      'titleAr': 'سعي الحج (الصفا والمروة)',
      'day': '10th Dhul Hijjah or Days of Tashreeq',
      'dayAr': '١٠ ذو الحجة أو أيام التشريق',
      'overviewEn':
          'Sa’i of Hajj is a mandatory ritual consisting of walking seven times between the hills of Safa and Marwah. For Hajj Tamattu\', this Sa\'i is performed after Tawaf al-Ifadah. For Hajj Qiran and Ifrad, it is typically performed after Tawaf al-Qudum or Tawaf al-Ifadah.',
      'overviewAr':
          'سعي الحج هو المشي بين الصفا والمروة سبعة أشواط، وهو ركن من أركان الحج عند جمهور العلماء. يؤديه القارن والمفرد بعد طواف القدوم (أو طواف الإفاضة)، بينما يؤديه المتمتع بعد طواف الإفاضة وجوباً.',
      'keyActionsEn': [
        'Perform 7 laps starting from Safa and ending at Marwah.',
        'Safa to Marwah is 1 lap; Marwah to Safa is the 2nd lap.',
        'Men should jog/run briskly between the green lights (Raml).',
        'Make sincere Duas and remember Allah at the peaks of Safa and Marwah.',
      ],
      'keyActionsAr': [
        'السعي ٧ أشواط كاملة تبدأ بالصفا وتنتهي بالمروة.',
        'الذهاب من الصفا إلى المروة يعتبر شوطاً، والرجوع شوطاً آخر.',
        'يُسن للرجال الهرولة بين العلمين الأخضرين.',
        'الوقوف عند الصفا والمروة مستقبل القبلة والدعاء بالتكبير والتهليل.',
      ],
      'quran': {
        'textAr': 'إِنَّ الصَّفَا وَالْمَرْوَةَ مِن شَعَائِرِ اللَّهِ ۖ فَمَنْ حَجَّ الْبَيْتَ أَوِ اعْتَمَرَ فَلَا جُنَاحَ عَلَيْهِ أَن يَطَّوَّفَ بِهِمَا',
        'referenceAr': 'سورة البقرة - الآية ١٥٨',
        'textEn': 'Indeed, Safa and Marwah are among the symbols of Allah. So whoever makes Hajj to the House or performs Umrah - there is no blame upon him for walking between them.',
        'referenceEn': 'Surah Al-Baqarah (2:158)',
        'explanationEn': 'Allah establishes Safa and Marwah as sacred signs of His worship, honoring the persistence and faith of Hajar (peace be upon her).',
        'explanationAr': 'تبيّن الآية أن الصفا والمروة من شعائر الدين ومواضع العبادة، وتشرع السعي بينهما.',
      },
      'hadith': {
        'textAr': 'عَنْ جَابِرِ بْنِ عَبْدِ اللَّهِ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ قَالَ فِي سَعْيِهِ: «ابْدَءُوا بِمَا بَدَأَ اللَّهُ بِهِ» فَبَدَأَ بِالصَّفَا',
        'referenceAr': 'صحيح مسلم (١٢١٨)',
        'textEn': 'Jabir bin Abdullah reported: The Prophet (ﷺ) said regarding Sa’i: "Begin with that which Allah has begun with." So he started with Safa.',
        'referenceEn': 'Sahih Muslim 1218',
        'explanationEn': 'This Hadith confirms the obligation of starting the Sa’i from Mount Safa as demonstrated by the Prophet (ﷺ).',
        'explanationAr': 'يبين الحديث وجوب البداية بالصفا اقتداءً بفعله صلى الله عليه وسلم وتفسيره للقرآن.',
      },
      'dua': {
        'title': 'Dua on Safa & Marwah',
        'arabic': 'لا إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، لا إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ، أَنْجَزَ وَعْدَهُ، وَنَصَرَ عَبْدَهُ، وَهَزَمَ الأَحْزَابَ وَحْدَهُ',
        'translit': 'La ilaha illallahu wahdahu la sharika lahu, lahul-mulku wa lahul-hamdu, wa huwa \'ala kulli shay\'in qadir. La ilaha illallahu wahdahu, anjaza wa\'dahu, wa nasara \'abdahu, wa hazamal-ahzaba wahdah.',
        'meaningEn': 'There is no deity except Allah alone, without partner. To Him belongs sovereignty and praise, and He has power over all things. There is no deity except Allah alone, He fulfilled His promise, granted victory to His servant, and defeated the confederates alone.',
        'meaningAr': 'التكبير والتهليل والثناء على الله عند صعود جبل الصفا والمروة والاستقبال للقبلة.',
      },
    },

    'ihram': {
      'titleEn': 'Enter Ihram & Intention (Niyyah)',
      'titleAr': 'الإحرام والنية',
      'day': 'Miqat - Before entering the Haram boundaries',
      'dayAr': 'الميقات - قبل دخول حدود الحرم',
      'overviewEn':
          'Ihram is the sacred state a pilgrim enters to perform Hajj or Umrah. It involves specific physical purifications (Ghusl), wearing designated unstitched white sheets (for men), reciting the Niyyah (intention), and continuously chanting the Talbiyah. Once in Ihram, prohibitions such as cutting hair, applying perfume, clipping nails, and hunting apply until deconsecration.',
      'overviewAr':
          'الإحرام هو النية والنية في الدخول في النسك مع التجرُّد من المَخِيط للرجال. ويبدأ بالتطهر والغسل، ثم لبس رداء وإزار أبيضين نظيفين، بينما تلبس المرأة ما شاءت من اللباس الساتر دون تبرج، ثم التلفظ بالنية والالتزام بمحظورات الإحرام كَقَصّ الشعر والطيب والجدال.',
      'keyActionsEn': [
        'Perform Ghusl (ritual bath) and trim nails/mustache before Miqat.',
        'Wear 2 unstitched white sheets (Izar & Rida) for men; loose modest dress for women.',
        'Offer 2 Rakat Sunnah prayer at the Miqat.',
        'Make explicit intention: "Labbayk Allahumma Hajjah" (لَبَّيْكَ اللَّهُمَّ حَجًّا).',
        'Begin loud recitation of Talbiyah: "Labbayk Allahumma Labbayk..."',
      ],
      'keyActionsAr': [
        'الاغتسال والتطيب في البدن قبل الإحرام (للرجال والنساء).',
        'ارتداء ملابس الإحرام (إزار ورداء أبيضين غير محيطين للرجال).',
        'صلاة ركعتين سُنة الإحرام في الميقات.',
        'التلفظ بالنية: "لَبَّيْكَ اللَّهُمَّ حَجًّا" أو "لَبَّيْكَ عُمْرَةً".',
        'رفع الصوت بالتلبية للرجال ورفعها بقدر ما تسمع نفسها للنساء.',
      ],
      'quran': {
        'textAr':
            'الْحَجُّ أَشْهُرٌ مَّعْلُومَاتٌ ۚ فَمَن فَرَضَ فِيهِنَّ الْحَجَّ فَلَا رَفَثَ وَلَا فُسُوقَ وَلَا جِدَالَ فِي الْحَجِّ ۗ وَمَا تَفْعَلُوا مِنْ خَيْرٍ يَعْلَمْهُ اللَّهُ',
        'referenceAr': 'سورة البقرة - الآية ١٩٧',
        'textEn':
            'Hajj is [during] well-known months, so whoever has made Hajj obligatory upon himself therein [by entering the state of ihram], there is [to be for him] no sexual relations and no disobedience and no disputing during Hajj. And whatever good you do - Allah knows it.',
        'referenceEn': 'Surah Al-Baqarah (2:197)',
        'explanationEn':
            'Allah explicitly establishes that entering Ihram requires refraining from immoral actions, disputes, and earthly desires, elevating spiritual focus solely towards Allah.',
        'explanationAr':
            'توضح الآية الكريمة حرمة وقت الإحرام ووجوب اجتناب الرفث والفسوق والجدال بالباطل، ليتفرغ الحاج لذكر الله والتقوى.',
      },
      'hadith': {
        'textAr':
            'عَنْ عَبْدِ اللَّهِ بْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ سُئِلَ: مَا يَلْبَسُ الْمُحْرِمُ؟ فَقَالَ: «لاَ يَلْبَسُ الْقُمُصَ وَلاَ الْعَمَائِمَ وَلاَ السََّرَاوِيلاَتِ وَلاَ الْبَرَانِسَ وَلاَ الْخِفَافَ...»',
        'referenceAr': 'صحيح البخاري (١٥٤٢) وصحيح مسلم (١١٧٧)',
        'textEn':
            'Narrated Abdullah ibn Umar: A man asked the Prophet (ﷺ), "What should a pilgrim in Ihram wear?" The Prophet replied, "He should not wear shirts, turbans, trousers, hooded cloaks, or leather socks..."',
        'referenceEn': 'Sahih al-Bukhari 1542, Sahih Muslim 1177',
        'explanationEn':
            'This Hadith lays out the essential dress code for men in Ihram to strip away worldly status and distinctions before Almighty Allah.',
        'explanationAr':
            'يبين الحديث الشريف أحكام اللباس للمحرم وتجرده من المظاهر والطبقية، ليتساوى الجميع أمام الله تعالى.',
      },
      'dua': {
        'title': 'Intention & Talbiyah (التلبية والنية)',
        'arabic':
            'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لا شَرِيكَ لَكَ لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكُ، لا شَرِيكَ لَكَ',
        'translit':
            'Labbayk Allahumma Labbayk, Labbayka la sharika laka labbayk, innal-hamda wan-ni’mata laka wal-mulk, la sharika lak.',
        'meaningEn':
            'Here I am O Allah, here I am. Here I am, You have no partner, here I am. Verily all praise, grace, and sovereignty belong to You. You have no partner.',
        'meaningAr':
            'إجابة بعد إجابة لك يا الله، لا شريك لك، إن الحمد والنعمة والملك لك وحدك لا شريك لك.',
      },
    },

    'tawaf_qudum': {
      'titleEn': 'Tawaf al-Qudum (Arrival Tawaf)',
      'titleAr': 'طواف القدوم',
      'day': 'Upon arrival in Makkah',
      'dayAr': 'فور الوصول إلى مكة المكرمة',
      'overviewEn':
          'Tawaf al-Qudum is the welcome circumambulation performed around the Holy Kaaba upon reaching Makkah. Pilgrims circle the Kaaba seven times counter-clockwise, starting from the Black Stone (Hajar al-Aswad). For men, Idtiba (uncovering the right shoulder) and Raml (brisk walking in the first 3 rounds) are Sunnah.',
      'overviewAr':
          'طواف القدوم هو تحية البيت الحرام للمُفْرِد والمقترن فور وصولهما إلى مكة. يطوف الحاج سبعة أشواط يبدأ كل شوط من الحجر الأسود وينتهي عنده، ويُسن للرجال الانطباع (كشف الكتف الأيمن) والرَّمَل (الهرولة الخفيفة في الأشواط الثلاثة الأولى).',
      'keyActionsEn': [
        'Uncover the right shoulder (Idtiba) for men during Tawaf.',
        'Start each circuit at the Hajar al-Aswad pointing/touching and saying "Bismillahi Allahu Akbar".',
        'Perform Raml (quick brisk walking) in the first 3 rounds.',
        'Recite "Rabbana atina fid-dunya hasanatan..." between RUKN AL-YAMANI and HAJAR AL-ASWAD.',
        'Offer 2 Rakat behind Maqam Ibrahim upon completion.',
      ],
      'keyActionsAr': [
        'الاضطباع للرجل بكشف الكتف الأيمن أثناء الطواف.',
        'استلام الحجر الأسود أو الإشارة إليه قائلًا: "بسم الله والله أكبر".',
        'الرَّمَل (الإسراع في المشي مع تقارب الخطى) في الأشواط الثلاثة الأولى.',
        'الدعاء بين الركن اليماني والحجر الأسود: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ".',
        'صلاة ركعتين خلف مقام إبراهيم بعد الطواف.',
      ],
      'quran': {
        'textAr':
            'وَإِذْ جَعَلْنَا الْبَيْتَ مَثَابَةً لِّلنَّاسِ وَأَمْنًا وَاتَّخِذُوا مِن مَّقَامِ إِبْرَاهِيمَ مُصَلًّى',
        'referenceAr': 'سورة البقرة - الآية ١٢٥',
        'textEn':
            'And [remember] when We made the House a place of return for the people and [a place of] security. And take, [O believers], from the standing place of Abraham a place of prayer.',
        'referenceEn': 'Surah Al-Baqarah (2:125)',
        'explanationEn':
            'Allah commands believers to make the Sanctuary a place of worship and to pray behind Maqam Ibrahim after performing Tawaf.',
        'explanationAr':
            'أمر الله تعالى بتعظيم الكعبة وأداء الصلاة عند مقام إبراهيم عليه السلام تخليداً لذكراه واقتداءً بالأنبياء.',
      },
      'hadith': {
        'textAr':
            'عَنْ جَابِرِ بْنِ عَبْدِ اللَّهِ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ لَمَّا قَدِمَ مَكَّةَ أَتَى الْحَجَرَ فَاسْتَلَمَهُ فََرَمَلَ ثَلاَثًا وَمَشَى أَرْبَعًا، ثُمَّ تَقَدَّمَ إِلَى مَقَامِ إِبْرَاهِيمَ فَقَرَأَ: {وَاتَّخِذُوا مِنْ مَقَامِ إِبْرَاهِيمَ مُصَلًّى}',
        'referenceAr': 'صحيح مسلم (١٢١٨)',
        'textEn':
            'Jabir bin Abdullah reported: When Allah’s Messenger (ﷺ) came to Makkah, he touched the Black Stone, then walked briskly (Raml) for three circuits and walked normally for four. Then he proceeded to Maqam Ibrahim and recited: "Take from the standing place of Abraham a place of prayer."',
        'referenceEn': 'Sahih Muslim 1218',
        'explanationEn':
            'This Hadith details the exact Sunnah method of Tawaf al-Qudum as demonstrated by Prophet Muhammad (ﷺ).',
        'explanationAr':
            'يوضح الحديث هيئة طواف النبي صلى الله عليه وسلم وصفة الرمل والصلاة خلف المقام.',
      },
      'dua': {
        'title': 'Dua Between Yamani Corner & Black Stone',
        'arabic':
            'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
        'translit':
            'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina \'adhaban-nar.',
        'meaningEn':
            'Our Lord, grant us good in this world and good in the Hereafter and protect us from the punishment of the Fire.',
        'meaningAr':
            'ربنا منحنا الخير في الدنيا والآخرة ونجنا من عذاب النار.',
      },
    },

    'mina1': {
      'titleEn': 'Day of Tarwiyah (8th Dhul Hijjah)',
      'titleAr': 'يوم التروية (٨ ذو الحجة)',
      'day': '8th Dhul Hijjah - Stay in Mina',
      'dayAr': '٨ ذو الحجة - المبيت بمنى',
      'overviewEn':
          'The Day of Tarwiyah marks the official start of Hajj. Pilgrims move to the tent city of Mina in the morning. They perform Dhuhr, Asr, Maghrib, Isha, and Fajr of the 9th Dhul Hijjah in Mina, shortening 4-rak’at prayers to 2 rak’at (Qasr) without combining them. Pilgrims spend the night in spiritual preparation and remembrance.',
      'overviewAr':
          'يوم التروية هو بداية أعمال الحج الفعلية. يتوجه الحجاج إلى منى في الصباح، ويصلون فيها الظهر والعصر والمغرب والعشاء وفجر يوم عرفة، يقصرون الصلاة الرباعية ركعتين دون جمع، ويبيتون في منى اتباعاً لسنة النبي صلى الله عليه وسلم.',
      'keyActionsEn': [
        'Enter Ihram from residence if not already in Ihram.',
        'Depart for Mina after sunrise on 8th Dhul Hijjah.',
        'Pray Dhuhr, Asr, Maghrib, Isha, and Fajr at Mina (Qasr: shortened to 2 rakah, no combining).',
        'Recite Talbiyah continuously and engage in Dhikr & Qur\'an recitation.',
        'Spend the entire night at Mina resting for the Day of Arafah.',
      ],
      'keyActionsAr': [
        'الإحرام بالحج لمن كان حلالاً بمكة صباح يوم التروية.',
        'الخروج إلى منى والتلبية طوال الطريق.',
        'أداء الصلوات الخمس بمنى (الظهر والعصر والمغرب والعشاء وفجر ٩ ذو الحجة) قصراً بلا جمع.',
        'الإكثار من الذكر والاستغفار والتلبية وقراءة القرآن.',
        'المبيت بمنى ليلة عرفة وهو سنة مؤكدة.',
      ],
      'quran': {
        'textAr':
            'وَاذْكُرُوا اللَّهَ فِي أَيَّامٍ مَّعْدُودَاتٍ ۚ فَمَن تَعَجَّلَ فِي يَوْمَيْنِ فَلَا إِثْمَ عَلَيْهِ وَمَن تَأَخَّرَ فَلَا إِثْمَ عَلَيْهِ ۚ لِمَنِ اتَّقَىٰ',
        'referenceAr': 'سورة البقرة - الآية ٢٠٣',
        'textEn':
            'And remember Allah during specific numbered days. Then whoever hastens [his departure] in two days, there is no sin upon him; and whoever delays, there is no sin upon him - for him who fears Allah.',
        'referenceEn': 'Surah Al-Baqarah (2:203)',
        'explanationEn':
            'The numbered days refer to the days spent in Mina, highlighting the importance of constant Remembrance (Dhikr) of Allah during this stay.',
        'explanationAr':
            'الأيام المعدودات هي أيام التشريق ومنى، وأمر الله فيها بإكثار الذكر والتقوى.',
      },
      'hadith': {
        'textAr':
            'عَنْ جَابِرٍ رَضِيَ اللَّهُ عَنْهُ فِي صِفَةِ حَجَّةِ النَّبِيِّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ: «فَلَمَّا كَانَ يَوْمُ التَّرْوِيَةِ تَوَجَّهُوا إِلَى مِنًى، فَرَكِبَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، فَصَلَّى بِهَا الظُّهْرَ وَالْعَصْرَ وَالْمَغْرِبَ وَالْعِشَاءَ وَالْفَجْرَ، ثُمَّ مَكَثَ قَلِيلاً حَتَّى طَلَعَتِ الشَّمْسُ...»',
        'referenceAr': 'صحيح مسلم (١٢١٨)',
        'textEn':
            'Jabir (RA) narrated regarding the Prophet’s Hajj: "When the Day of Tarwiyah arrived, they turned towards Mina. The Messenger of Allah (ﷺ) rode there and offered Dhuhr, Asr, Maghrib, Isha, and Fajr prayers. Then he waited until sunrise..."',
        'referenceEn': 'Sahih Muslim 1218',
        'explanationEn':
            'This establishes the Sunnah of traveling to Mina on the 8th and performing shortened prayers before advancing to Arafah.',
        'explanationAr':
            'يؤكد الحديث حرص النبي صلى الله عليه وسلم على المبيت بمنى وأداء الصلوات الخمس مقصورة فيها.',
      },
      'dua': {
        'title': 'Dua of Remembrance in Mina',
        'arabic':
            'اللَّهُمَّ إِلَيْكَ تَوَجَّهْتُ، وَوَجْهَكَ أَرَدْتُ، فَاجْعَلْ ذَنْبِي مَغْفُوراً، وَحَجِّي مَبْرُوراً، وَارْحَمْنِي وَلا تُخَيِّبْنِي',
        'translit':
            'Allahumma ilayka tawajjahtu, wa wajhaka aradtu, faj’al dhanbi maghfuran, wa hajji mabruran, warhamni wa la tukhayyibni.',
        'meaningEn':
            'O Allah, unto You I have turned, and Your Countenance I seek. Forgive my sins, accept my Hajj, show mercy upon me, and do not disappoint me.',
        'meaningAr':
            'اللهم إني توجهت إليك وابتغيت وجهك الكريم، فاغفر ذنبي واجعل حجي مبروراً وارحمني.',
      },
    },

    'arafat': {
      'titleEn': 'Day of Arafah (9th Dhul Hijjah) - Core of Hajj',
      'titleAr': 'يوم عرفة (٩ ذو الحجة) - ركن الحج الأعظم',
      'day': '9th Dhul Hijjah - Standing at Arafat (Wuquf)',
      'dayAr': '٩ ذو الحجة - الوقوف بعرفة',
      'overviewEn':
          'The Day of Arafah is the pinnacle and supreme ritual of Hajj ("Hajj is Arafah"). Pilgrims move from Mina to the plain of Arafat. Standing at Arafat (Wuquf) takes place from Dhuhr until Maghrib. Dhuhr and Asr are prayed together combined and shortened (Jam\' & Qasr) at Dhuhr time. Pilgrims spend the entire afternoon crying, seeking forgiveness, and making earnest Duas.',
      'overviewAr':
          'يوم عرفة هو العيد الأكبر والحج الأعظم ("الحج عرفة"). يتوجه الحجاج من منى إلى عرفات. يبدأ وقت الوقوف من زوال الشمس (الظهر) حتى غروبها. يصلى الظهر والعصر جمع تقديم وقصراً بأذان وإقامتين. ويقضي الحاج ما بعد الظهر إلى الغروب بالتضرع والدعاء والبكاء لله تعالى.',
      'keyActionsEn': [
        'Travel to Arafat after sunrise on the 9th Dhul Hijjah.',
        'Pray Dhuhr & Asr combined and shortened (Jam\' al-Taqdeem) at Dhuhr time with 1 Adhan and 2 Iqamahs.',
        'Stand at Mount Arafat / Plains of Arafat facing Qiblah with raised hands until sunset.',
        'Make maximum Duas, Istighfar, Qur\'an recitation, and recite the best Dua of Arafah.',
        'Do NOT leave Arafat before sunset.',
      ],
      'keyActionsAr': [
        'الانتقال من منى إلى عرفة بعد طلوع شمس يوم التاسع.',
        'صلاة الظهر والعصر جمع تقديم وقصراً في وقت الظهر بأذان وإقامتين.',
        'الوقوف بعرفة مستقبلاً القبلة داعياً رافعاً اليدين حتى غروب الشمس.',
        'الإكثار من التضرع والاستغفار وقول: "لا إله إلا الله وحده لا شريك له...".',
        'عدم الانصراف من عرفة إلا بعد غروب الشمس بالكلية.',
      ],
      'quran': {
        'textAr':
            'الْيَوْمَ أَكْمَلْتُ لَكُمْ دِينَكُمْ وَأَتْمَمْتُ عَلَيْكُمْ نِعْمَتِي وَرَضِيتُ لَكُمُ الْإِسْلَامَ دِينًا',
        'referenceAr': 'سورة المائدة - الآية ٣ (نزلت بعرفة)',
        'textEn':
            'This day I have perfected for you your religion and completed My favor upon you and have approved for you Islam as your religion.',
        'referenceEn': 'Surah Al-Ma\'idah (5:3)',
        'explanationEn':
            'This monumental verse was revealed to Prophet Muhammad (ﷺ) on the Day of Arafah at Jabal al-Rahmah, signifying the completion of divine revelation.',
        'explanationAr':
            'نزلت هذه الآية العظيمة على النبي صلى الله عليه وسلم وهو واقف بعرفة يوم الجمعة، إعلاناً بتمام الدين وكمال النعمة.',
      },
      'hadith': {
        'textAr':
            'عَنْ عَبْدِ الرَّحْمَنِ بْنِ يَعْمَرَ رَضِيَ اللَّهُ عَنْهُ أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ قَالَ: «الْحَجُّ عَرَفَةُ، فَمَنْ جَاءَ قَبْلَ صَلاَةِ الْفَجْرِ مِنْ لَيْلَةِ جَمْعٍ فَقَدْ تَمَّ حَجُّهُ»',
        'referenceAr': 'سنن الترمذي (٨٨٩) وسنن أبا داود (١٩٤٩)',
        'textEn':
            'Abdur-Rahman ibn Ya\'mar reported: The Prophet (ﷺ) said: "Hajj is Arafah. Whoever arrives before Fajr prayer on the night of Muzdalifah has completed his Hajj."',
        'referenceEn': 'Jami\' at-Tirmidhi 889, Sunan Abi Dawud 1949',
        'explanationEn':
            'Standing at Arafat is the single non-negotiable pillar (Rukn) of Hajj without which Hajj is invalid.',
        'explanationAr':
            'يبين الحديث أن الوقوف بعرفة هو الركن الأعظم للحج، وبدونه لا يصح الحج.',
      },
      'dua': {
        'title': 'The Supreme Dua of Arafah (خَيْرُ الدُّعَاءِ دُعَاءُ يَوْمِ عَرَفَةَ)',
        'arabic':
            'لا إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        'translit':
            'La ilaha illallahu wahdahu la sharika lahu, lahul-mulku wa lahul-hamdu, wa huwa \'ala kulli shay\'in qadir.',
        'meaningEn':
            'There is no deity worthy of worship except Allah, alone without partner. To Him belongs sovereignty and praise, and He has power over all things.',
        'meaningAr':
            'أفضل ما قال النبي صلى الله عليه وسلم والنبيون من قبله عشية عرفة: التوحيد والتمجيد لله وحده.',
      },
    },

    'muzdalifah': {
      'titleEn': 'Muzdalifah (Night of 10th Dhul Hijjah)',
      'titleAr': 'المزدلفة (ليلة العاشر من ذي الحجة)',
      'day': 'Night following Arafah (9th-10th Dhul Hijjah)',
      'dayAr': 'ليلة ١٠ ذو الحجة - المبيت بالمزدلفة',
      'overviewEn':
          'Immediately after sunset on 9th Dhul Hijjah, pilgrims travel from Arafat to Muzdalifah without praying Maghrib at Arafat. Upon arrival in Muzdalifah, Maghrib and Isha are prayed together combined and shortened (Jam\' al-Ta\'khir). Pilgrims spend the night under the open sky, resting, performing Fajr at twilight, and collecting pebbles for Rami.',
      'overviewAr':
          'بعد غروب شمس يوم عرفة مباشرة، ينطلق الحجاج إلى المزدلفة بهدوء وسكينة، ولا يصلون المغرب بعرفة. عند الوصول للمزدلفة يصلون المغرب ثلاث ركعات والعشاء ركعتين جمع تأخير بأذان وإقامتين. ويبيتون الليل تحت السماء، ثم يصلون الفجر بالمشعر الحرام ويجمعون الجمار.',
      'keyActionsEn': [
        'Depart Arafat calmly after sunset without praying Maghrib at Arafat.',
        'Pray Maghrib (3 rakah) and Isha (2 rakah) combined at Muzdalifah (Jam\' al-Ta\'khir).',
        'Collect 7, 21, or 49+ small pebbles (size of a chickpea/bean) for Rami.',
        'Spend the night sleeping/resting at Muzdalifah until Fajr (Wajib).',
        'Offer Fajr prayer early at twilight, make Dua at Al-Mash\'ar Al-Haram, then depart for Mina before sunrise.',
      ],
      'keyActionsAr': [
        'الانصراف من عرفة بعد الغروب بسكينة ودون استعجال.',
        'صلاة المغرب ثلاثاً والعشاء قصراً جمع تأخير عند الوصول للمزدلفة.',
        'التقاط حصى الجمار (حجم حمصة تقريباً) من المزدلفة أو منى.',
        'المبيت بالمزدلفة حتى صلاة الفجر (وهو واجب عند جمهور العلماء).',
        'صلاة الفجر في أول وقتها ثم التضرع عند المشعر الحرام والانطلاق إلى منى قبل طلوع الشمس.',
      ],
      'quran': {
        'textAr':
            'فَإِذَا أَفَضْتُم مِّنْ عَرَفَاتٍ فَاذْكُرُوا اللَّهَ عِندَ الْمَشْعَرِ الْحَرَامِ ۖ وَاذْكُرُوهُ كَمَا هَدَاكُمْ وَإِن كُنتُم مِّن قَبْلِهِ لَمَِنَ الضَّالِّينَ',
        'referenceAr': 'سورة البقرة - الآية ١٩٨',
        'textEn':
            'Then when you depart from Arafat, remember Allah at al-Mash\'ar al-Haram. And remember Him as He has guided you, for indeed, you were before that among those astray.',
        'referenceEn': 'Surah Al-Baqarah (2:198)',
        'explanationEn':
            'Allah explicitly orders pilgrims departing from Arafat to stop and engage in His Remembrance at Al-Mash\'ar Al-Haram in Muzdalifah.',
        'explanationAr':
            'تأمر الآية الكريمة بذكر الله عند المشعر الحرام بالمزدلفة فور الإفاضة من عرفات.',
      },
      'hadith': {
        'textAr':
            'عَنْ عَبْدِ اللَّهِ بْنِ مَسْعُودٍ رَضِيَ اللَّهُ عَنْهُ قَالَ: مَا رَأَيْتُ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ صَلَّى صَلاَةً إِلاَّ لِوَقْتِهَا إِلاَّ صَلاَتَيْنِ: جَمَعَ بَيْنَ الْمَغْرِبِ وَالْعِشَاءِ بِجَمْعٍ (الْمُزْدَلِفَةِ)، وَصَلَّى الْفَجْرَ يَوْمَئِذٍ قَبْلَ وَقْتِهَا الْمُعْتَادِ',
        'referenceAr': 'صحيح البخاري (١٦٧٥) وصحيح مسلم (١٢٨٠)',
        'textEn':
            'Ibn Mas\'ud reported: "I never saw the Messenger of Allah (ﷺ) offer any prayer out of its time except two: He combined Maghrib and Isha at Muzdalifah, and he offered Fajr prayer on that day earlier than its usual time (at twilight)."',
        'referenceEn': 'Sahih al-Bukhari 1675, Sahih Muslim 1280',
        'explanationEn':
            'Highlights the mandatory sunnah of delaying Maghrib until arriving at Muzdalifah and offering Fajr early at twilight.',
        'explanationAr':
            'يبين الحديث استثناء النبي صلى الله عليه وسلم لصلاتي المغرب والعشاء بجمعهما بالمزدلفة وصلاة الفجر بغلس.',
      },
      'dua': {
        'title': 'Dua at Al-Mash\'ar Al-Haram (دعاء المشعر الحرام)',
        'arabic':
            'اللَّهُمَّ كَمَا وَقَفْتَنَا فِيهِ وَأَرَيْتَنَا إِيَّاهُ فَوَفِّقْنَا لِذِكْرِكَ كَمَا هَدَيْتَنَا، وَاغْفِرْ لَنَا وَارْحَمْنَا كَمَا وَعَدْتَنَا',
        'translit':
            'Allahumma kama waqaftana fihi wa araytana iyyahu fawaffiqna lidhikrika kama hadaytana, waghfir lana warhamna kama wa’adtana.',
        'meaningEn':
            'O Allah, just as You enabled us to stand here and showed it to us, grant us success in remembering You as You guided us, and forgive us and have mercy on us as You promised us.',
        'meaningAr':
            'دعاء الثناء والاستغفار عند المشعر الحرام بالمزدلفة قبل طلوع الشمس.',
      },
    },

    'rami1': {
      'titleEn': 'Rami al-Jamarat (10th Dhul Hijjah - Yawm an-Nahr)',
      'titleAr': 'رمي جمرة العقبة (١٠ ذو الحجة - يوم النحر)',
      'day': '10th Dhul Hijjah (Eid al-Adha)',
      'dayAr': '١٠ ذو الحجة (يوم عيد الأضحى المبارك)',
      'overviewEn':
          'On the morning of 10th Dhul Hijjah (Yawm an-Nahr), pilgrims return from Muzdalifah to Mina to pelt only the largest pillar, Jamarat al-Aqabah (Al-Jamrah Al-Kubra). Pilgrims throw 7 pebbles individually while saying "Allahu Akbar" with each throw. This symbolizes rejecting Shaytan and remaining steadfast in faith.',
      'overviewAr':
          'صباح يوم العاشر من ذي الحجة (يوم النحر)، يتجه الحجاج إلى منى لرمي جمرة العقبة الكبرى فقط بسبع حصيات متعاقبة، يكبر الحاج مع كل حصاة قائلًا: "الله أكبر"، مقطعاً التلبية مع أول حصاة، اقتداءً بإبراهيم عليه السلام في دحر الشيطان.',
      'keyActionsEn': [
        'Arrive in Mina from Muzdalifah in the morning (Dhuha time).',
        'Pelt ONLY the Big Pillar (Jamarat al-Aqabah) with 7 pebbles.',
        'Say "Allahu Akbar" with every single thrown pebble.',
        'Stop reciting Talbiyah upon throwing the first pebble of Jamarat al-Aqabah.',
        'Ensure pebbles land inside the basin (Marma).',
      ],
      'keyActionsAr': [
        'الوصول إلى منى من المزدلفة ضحى يوم النحر.',
        'رمي الجمرة الكبرى (جمرة العقبة) فقط بـ ٧ حصيات متعاقبة.',
        'التكبير مع كل حصاة: "الله أكبر".',
        'قطع التلبية مع بداية رمي أول حصاة من جمرة العقبة.',
        'التأكد من وقوع الحصى داخل حوض الجمرة.',
      ],
      'quran': {
        'textAr':
            'وَمَن يُعَظِّمْ شَعَائِرَ اللَّهِ فَإِنَّهَا مِن تَقْوَى الْقُلُوبِ',
        'referenceAr': 'سورة الحج - الآية ٣٢',
        'textEn':
            'And whoever honors the symbols of Allah - indeed, it is from the piety of hearts.',
        'referenceEn': 'Surah Al-Hajj (22:32)',
        'explanationEn':
            'Throwing pebbles at the Jamarat is among the sacred symbols (Sha’a’ir) of Allah performed to commemorate Ibrahim’s steadfastness.',
        'explanationAr':
            'رمي الجمار وتعظيم مناسك الحج من دلالات تقوى القلوب وإجلال أمر الله.',
      },
      'hadith': {
        'textAr':
            'عَنْ جَابِرٍ رَضِيَ اللَّهُ عَنْهُ قَالَ: «رَأَيْتُ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ يَرْمِي الْجَمْرَةَ ضُحًى يَوْمَ النَّحْرِ، وَوَهْوَ عَلَى نَاقَتِهِ يَقُولُ: لِتَأْخُذُوا مَنَاسِكَكُمْ، فَإِنِّي لاَ أَدْرِي لَعَلِّي لاَ أَحُجُّ بَعْدَ حَجَّتِي هَذِهِ»',
        'referenceAr': 'صحيح مسلم (١٢٩٧)',
        'textEn':
            'Jabir reported: "I saw the Prophet (ﷺ) throwing pebbles at Jamarat al-Aqabah in the forenoon on the Day of Sacrifice, saying: Take your rituals from me, for I do not know whether I will perform Hajj after this Hajj of mine."',
        'referenceEn': 'Sahih Muslim 1297',
        'explanationEn':
            'This establishes the timing (Dhuha) and fundamental rule that all Hajj rituals must mirror the Prophet’s demonstration.',
        'explanationAr':
            'أمر النبي صلى الله عليه وسلم الأمة بالأخذ عنه في أفعال الحج ومناسك الرمي.',
      },
      'dua': {
        'title': 'Takbeer During Rami (التكبير عند الرمي)',
        'arabic':
            'اللَّهُ أَكْبَرُ، اللَّهُمَّ اجْعَلْهُ حَجًّا مَبْرُورًا وَذَنْبًا مَغْفُورًا',
        'translit':
            'Allahu Akbar, Allahumma-j’alhu hajjan mabruran wa dhanban maghfura.',
        'meaningEn':
            'Allah is the Greatest. O Allah, make it an accepted Hajj and a forgiven sin.',
        'meaningAr':
            'التكبير عند رمي كل حصاة والدعاء بالقبول ومغفرة الذنوب.',
      },
    },

    'qurbani': {
      'titleEn': 'Qurbani (Hady Sacrifice) & Halq / Taqsir',
      'titleAr': 'الهدي والحلق أو التقصير',
      'day': '10th Dhul Hijjah (Yawm an-Nahr)',
      'dayAr': '١٠ ذو الحجة (يوم النحر)',
      'overviewEn':
          'After Rami on the 10th of Dhul Hijjah, pilgrims performing Hajj Tamattu or Qiran offer the Hady (animal sacrifice). Afterwards, male pilgrims shave their heads completely (Halq - preferred) or trim hair evenly (Taqsir). Female pilgrims trim a fingertip length of their hair. At this point, Tahallul al-Asghar (first partial deconsecration) is achieved.',
      'overviewAr':
          'بعد رمي جمرة العقبة يوم النحر، يقوم المتمتع والمقرن بذبْح الهدي. ثم يحلق الرجل رأسه (وهو الأفضل) أو يقصره، وتقصر المرأة من أطراف شعرها قدر أنملة (حوالي ٢ سم). وبذلك يتحلل الحاج التحلل الأول (التحلل الأصغر) فيحل له كل شيء حرم عليه بالإحرام إلا النساء.',
      'keyActionsEn': [
        'Slaughter the Hady (sheep, goat, or 1/7 of camel/cow) for Tamattu/Qiran pilgrims.',
        'Men: Shave head completely (Halq) or trim hair evenly all around (Taqsir).',
        'Women: Trim a fingertip length (approx 1.5 - 2 cm) from the ends of hair.',
        'Attain Tahallul al-Asghar: Change out of Ihram garments into regular clothes.',
        'All Ihram prohibitions lifted EXCEPT marital relations until Tawaf al-Ifadah.',
      ],
      'keyActionsAr': [
        'ذبح الهدي للمتمتع والمقرن (شاة أو سبع بدنة/بقرة).',
        'الحلق للرجال بالموسى (وهو الأفضل) أو التقصير لجميع الرأس.',
        'تقصير المرأة من كل ضفيرة أو من طرف شعرها قدر أنملة.',
        'التحلل الأصغر (التحلل الأول): لبس الثياب العادية والتطيب.',
        'إباحة محظورات الإحرام عدا النساء حتى طواف الإفاضة.',
      ],
      'quran': {
        'textAr':
            'لَّقَدْ صَدَقَ اللَّهُ رَسُولَهُ الرُّؤْيَا بِالْحَقِّ ۖ لَتَدْخُلُنَّ الْمَسْجِدَ الْحَرَامَ إِن شَاءَ اللَّهُ آمِنِينَ مُحَلِّقِينَ رُءُوسَكُمْ وَمُقَصِّرِينَ لَا تَخَافُونَ',
        'referenceAr': 'سورة الفتح - الآية ٢٧',
        'textEn':
            'Certainly has Allah showed to His Messenger the vision in truth. You will surely enter al-Masjid al-Haram, if Allah wills, in safety, with your heads shaved and hair shortened, not fearing.',
        'referenceEn': 'Surah Al-Fath (48:27)',
        'explanationEn':
            'Quranic prophecy highlighting head shaving (Halq) and shortening (Taqsir) as sacred symbols marking the completion of pilgrimage.',
        'explanationAr':
            'بشر الله نبيه بدخول المسجد الحرام وأداء النسك مع الحلق والتقصير.',
      },
      'hadith': {
        'textAr':
            'عَنْ أَبِي هُرَيْرَةَ رَضِيَ اللَّهُ عَنْهُ قَالَ: قَالَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ: «اللَّهُمَّ اغْفِرْ لِلْمُحَلِّقِينَ»، قَالُوا: وَلِلْمُقَصِّرِينَ يَا رَسُولَ اللَّهِ؟ قَالَ: «اللَّهُمَّ اغْفِرْ لِلْمُحَلِّقِينَ»، قَالُوا: وَلِلْمُقَصِّرِينَ يَا رَسُولَ اللَّهِ؟ قَالَ: «وَلِلْمُقَصِّرِينَ» فِي الثَّالِثَةِ أَوْ الرَّابِعَةِ',
        'referenceAr': 'صحيح البخاري (١٧٢٧) وصحيح مسلم (١٣٠١)',
        'textEn':
            'Abu Hurairah reported: The Messenger of Allah (ﷺ) prayed: "O Allah, forgive those who shave their heads!" They asked: "And those who shorten, O Messenger of Allah?" He repeated: "O Allah, forgive those who shave!" They asked again, and on the third or fourth time he added: "And those who shorten."',
        'referenceEn': 'Sahih al-Bukhari 1727, Sahih Muslim 1301',
        'explanationEn':
            'Demonstrates the superior reward for men who shave their heads completely (Halq) compared to trimming.',
        'explanationAr':
            'فضل الحلق ومضاعفة الدعاء للمحلقين ثلاثاً بالرحمة والمغفرة.',
      },
      'dua': {
        'title': 'Dua Upon Shaving/Trimming Hair',
        'arabic':
            'الْحَمْدُ لِلَّهِ عَلَى مَا هَدَانَا، اللَّهُمَّ ثَبِّتْنِي عَلَى الْهُدَى وَاغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُسْلِمِينَ أَجْمَعِينَ',
        'translit':
            'Alhamdu lillahi \'ala ma hadana, Allahumma thabbitni \'alal-huda waghfir li wa li-walidayya wa lil-muslimina ajma\'in.',
        'meaningEn':
            'Praise be to Allah for guiding us. O Allah, keep me firm upon guidance and forgive me, my parents, and all Muslims.',
        'meaningAr':
            'حمد الله على توفيقه لإتمام النسك والدعاء بالثبات والمغفرة.',
      },
    },

    'tawaf_ifadah': {
      'titleEn': 'Tawaf al-Ifadah (Tawaf al-Ziyarah) & Sa’i',
      'titleAr': 'طواف الإفاضة والسعي',
      'day': '10th Dhul Hijjah or Days of Tashreeq',
      'dayAr': '١٠ ذو الحجة أو أيام التشريق',
      'overviewEn':
          'Tawaf al-Ifadah is a core, mandatory pillar (Rukn) of Hajj without which Hajj remains incomplete. Pilgrims travel from Mina to Makkah to circumambulate the Kaaba 7 times. After Tawaf, pilgrims perform Sa\'i between Safa and Marwah (for Tamattu pilgrims and those who did not perform Sa\'i earlier). Completing this grants Tahallul al-Akbar (complete deconsecration).',
      'overviewAr':
          'طواف الإفاضة هو ركن من أركان الحج لا يتم الحج إلا به. يتجه الحاج إلى مكة للطواف حول الكعبة ٧ أشواط، ثم يصلي ركعتين خلف المقام، ويسعى بين الصفا والمروة ٧ أشواط (للمتمتع ولمن لم يسعَ مع طواف القدوم). وبتمام طواف الإفاضة والسعي يتحلل الحاج التحلل الأكبر (الكامل) فيحل له كل شيء حتى النساء.',
      'keyActionsEn': [
        'Perform 7 circuits around the Kaaba (Tawaf al-Ifadah).',
        'Pray 2 Rakah behind Maqam Ibrahim.',
        'Drink Zamzam water and make Dua.',
        'Perform Sa\'i between Mount Safa and Mount Marwah (7 laps starting at Safa, ending at Marwah).',
        'Attain Tahallul al-Akbar (complete deconsecration): All restrictions including marital relations lifted.',
      ],
      'keyActionsAr': [
        'الطواف حول الكعبة المشرفة ٧ أشواط (طواف الإفاضة).',
        'صلاة ركعتين خلف مقام إبراهيم والشرب من ماء زمزم.',
        'السعي بين الصفا والمروة ٧ أشواط يبدأ بالصفا وينتهي بالمروة.',
        'التحلل الأكبر (التحلل الكامل) الذي يبيح كل محظورات الإحرام بما فيها النساء.',
        'العودة إلى منى للمبيت بها بقية أيام التشريق.',
      ],
      'quran': {
        'textAr':
            'إِنَّ الصَّفَا وَالْمَرْوَةَ مِن شَعَائِرِ اللَّهِ ۖ فَمَنْ حَجَّ الْبَيْتَ أَوِ اعْتَمَرَ فَلَا جُنَاحَ عَلَيْهِ أَن يَطَّوَّفَ بِهِمَا',
        'referenceAr': 'سورة البقرة - الآية ١٥٨',
        'textEn':
            'Indeed, Safa and Marwah are among the symbols of Allah. So whoever makes Hajj to the House or performs Umrah - there is no blame upon him for walking between them.',
        'referenceEn': 'Surah Al-Baqarah (2:158)',
        'explanationEn':
            'Allah enshrines Sa\'i between Safa and Marwah as an obligatory symbol commemorating Hajar’s devotion to saving baby Ismail.',
        'explanationAr':
            'تشريع السعي بين الصفا والمروة واعتبارهما من شعائر الله الدالة على طاعته والإخلاص له.',
      },
      'hadith': {
        'textAr':
            'عَنْ عَائِشَةَ رَضِيَ اللَّهُ عَنْهَا قَالَتْ: «أَفَاضَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ مِنْ آخِرِ يَوْمِهِ حِينَ صَلَّى الظُّهْرَ، ثُمَّ رَجَعَ إِلَى مِنًى»',
        'referenceAr': 'صحيح البخاري (١٧٣٣) وصحيح مسلم (١٢١٨)',
        'textEn':
            'Aisha reported: "The Messenger of Allah (ﷺ) performed Tawaf al-Ifadah on the latter part of the day (10th) after praying Dhuhr, then he returned to Mina."',
        'referenceEn': 'Sahih al-Bukhari 1733, Sahih Muslim 1218',
        'explanationEn':
            'Confirms that Tawaf al-Ifadah is performed on the 10th of Dhul Hijjah before returning to Mina for Tashreeq nights.',
        'explanationAr':
            'بيان وقت طواف الإفاضة للنبي صلى الله عليه وسلم يوم النحر ورجوعه للمبيت بمنى.',
      },
      'dua': {
        'title': 'Dua at Mount Safa (دعاء الصفا والمروة)',
        'arabic':
            'أَبْدَأُ بِمَا بَدَأَ اللَّهُ بِهِ، إِنَّ الصَّفَا وَالْمَرْوَةَ مِن شَعَائِرِ اللَّهِ... لا إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ أَنْجَزَ وَعْدَهُ، وَنَصَرَ عَبْدَهُ، وَهَزَمَ الأَحْزَابَ وَحْدَهُ',
        'translit':
            'Abda’u bima bada’allahu bihi. La ilaha illallahu wahdahu anjaza wa’dahu, wa nasara \'abdahu, wa hazamal-ahzaba wahdah.',
        'meaningEn':
            'I begin with that which Allah began with. There is no deity except Allah alone, He fulfilled His promise, granted victory to His servant, and defeated the confederates alone.',
        'meaningAr':
            'التكبير والتهليل والثناء على الله عند صعود جبل الصفا والمروة والاستقبال للقبلة.',
      },
    },

    'rami_days': {
      'titleEn': 'Rami al-Jamarat (Days of Tashreeq - 11th, 12th, 13th)',
      'titleAr': 'رمي الجمار في أيام التشريق (١١، ١٢، ١٣ ذو الحجة)',
      'day': '11th, 12th, and optional 13th Dhul Hijjah',
      'dayAr': '١١ و١٢ و١٣ ذو الحجة - أيام التشريق',
      'overviewEn':
          'Pilgrims remain in Mina during the Days of Tashreeq (11th, 12th, and optionally 13th Dhul Hijjah). Each afternoon AFTER Zawal (midday sun turn), pilgrims pelt all three Jamarat in order: Small (Al-Sugra), Medium (Al-Wusta), and Large (Al-Aqabah) with 7 pebbles each (21 total per day). Long supplications are made after the 1st and 2nd Jamarat.',
      'overviewAr':
          'يقيم الحجاج بمنى أيام التشريق (١١، ١٢، و١٣ لمن تأخر). ويكون رمي الجمار الثلاث بعد زوال الشمس (بعد صلاة الظهر) كل يوم بترتيب: الجمرة الصغرى (٧ حصيات)، ثم الوسطى (٧ حصيات)، ثم العقبة الكبرى (٧ حصيات) بمجموع ٢١ حصاة يومياً. ويُسن الوقوف والدعاء الطويل بعد الصغرى والوسطى.',
      'keyActionsEn': [
        'Stay overnight in Mina during Tashreeq nights (Wajib).',
        'Wait for Zawal (Dhuhr time) each day before starting Rami.',
        'Pelt 1st: Small Jamrah (7 pebbles) -> Step aside & make long Dua facing Qiblah.',
        'Pelt 2nd: Medium Jamrah (7 pebbles) -> Step aside & make long Dua facing Qiblah.',
        'Pelt 3rd: Large Jamrah al-Aqabah (7 pebbles) -> Depart without stopping for Dua.',
        'Pilgrims can depart Mina on 12th before Maghrib (Ta\'ajjul) or stay for 13th (Takhar).',
      ],
      'keyActionsAr': [
        'المبيت بمنى ليالي أيام التشريق (واجب).',
        'بداية الرمي يومياً بعد زوال الشمس (أذان الظهر).',
        'رمي الجمرة الأولى الصغرى بـ ٧ حصيات ثم التنحي والقيام للدعاء الطويل مستقبل القبلة.',
        'رمي الجمرة الثانية الوسطى بـ ٧ حصيات ثم التنحي والقيام للدعاء الطويل.',
        'رمي الجمرة الثالثة الكبرى (العقبة) بـ ٧ حصيات والانصراف دون دعاء.',
        'جواز التعجل والخروج من منى في اليوم الثاني عشر قبل الغروب، أو التأخر لليوم الثالث عشر وهو الأفضل.',
      ],
      'quran': {
        'textAr':
            'فَمَن تَعَجَّلَ فِي يَوْمَيْنِ فَلَا إِثْمَ عَلَيْهِ وَمَن تَأَخَّرَ فَلَا إِثْمَ عَلَيْهِ ۚ لِمَنِ اتَّقَىٰ ۗ وَاتَّقُوا اللَّهَ وَاعْلَمُوا أَنَّكُمْ إِلَيْهِ تُحْشَرُونَ',
        'referenceAr': 'سورة البقرة - الآية ٢٠٣',
        'textEn':
            'Whoever hastens [his departure] in two days, there is no sin upon him; and whoever delays, there is no sin upon him - for him who fears Allah. And fear Allah and know that unto Him you will be gathered.',
        'referenceEn': 'Surah Al-Baqarah (2:203)',
        'explanationEn':
            'Divine permission for pilgrims to either complete Tashreeq on the 12th (Ta\'ajjul) or complete the 13th day (Takhar), provided it is done with Taqwa.',
        'explanationAr':
            'تبيح الآية التعجل في اليوم الثاني عشر أو التأخر لليوم الثالث عشر لمن اتقى الله.',
      },
      'hadith': {
        'textAr':
            'عَنْ عَبْدِ اللَّهِ بْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّهُ كَانَ يَرْمِي الْجَمْرَةَ الدُّنْيَا بِسَبْعِ حَصَيَاتٍ، ثُمَّ يُكَبِّرُ عَلَى إِثْرِ كُلِّ حَصَاةٍ، ثُمَّ يَتَقَدَّمُ فَيُسْهِلُ فَيَقُومُ مُسْتَقْبِلَ الْقِبْلَةِ، فَيَقُومُ طَوِيلاً وَيَدْعُو وَيَرْفَعُ يَدَيْهِ... وَيَقُولُ: هَكَذَا رَأَيْتُ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ يَفْعَلُهُ',
        'referenceAr': 'صحيح البخاري (١٧٥١)',
        'textEn':
            'Narrated Ibn Umar: He used to stone the nearest Jamrah with 7 pebbles, saying Takbeer with each pebble. Then he would move forward, stand facing the Qiblah for a long time making Dua with raised hands... and say: "This is how I saw the Prophet (ﷺ) doing it."',
        'referenceEn': 'Sahih al-Bukhari 1751',
        'explanationEn':
            'Details the Sunnah method of standing for prolonged Dua after the Small and Medium Jamarat during Tashreeq days.',
        'explanationAr':
            'شرح وتطبييق سنة النبي صلى الله عليه وسلم في الوقوف للدعاء الطويل بين الجمار.',
      },
      'dua': {
        'title': 'Dua Between Jamarat (الدعاء الطويل بين الجمرتين)',
        'arabic':
            'اللَّهُمَّ اغْفِرْ وَارْحَمْ، وَاعْفُ عَمَّا تَعْلَمُ، وَأَنْتَ الأَعَزُّ الأَكْرَمُ، اللَّهُمَّ آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
        'translit':
            'Allahummaghfir warham, wa’fu \'amma ta’lam, wa antal-a’azzul-akram. Allahumma atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina \'adhaban-nar.',
        'meaningEn':
            'O Allah forgive and have mercy, and pardon what You know, for You are the Most Mighty, Most Generous. O Allah grant us good in this world and the next and save us from the Fire.',
        'meaningAr':
            'الدعاء والمناجاة الطويلة مستقبل القبلة بعد رمي الجمرة الصغرى والوسطى.',
      },
    },

    'tawaf_wida': {
      'titleEn': 'Tawaf al-Wida (Farewell Tawaf)',
      'titleAr': 'طواف الوداع',
      'day': 'Final action before leaving Makkah',
      'dayAr': 'آخر أعمال الحاج قبل مغادرة مكة',
      'overviewEn':
          'Tawaf al-Wida (Farewell Tawaf) is the final compulsory obligation (Wajib) for every pilgrim before leaving the holy city of Makkah. It consists of 7 circuits around the Kaaba without Sa\'i. After completing Tawaf al-Wida, pilgrims pray 2 Rakat, drink Zamzam, and depart Makkah directly without lingering.',
      'overviewAr':
          'طواف الوداع هو آخر واجبات الحج على كل آفاقي (من خارج مكة) قبل مغادرتها. يطوف الحاج ٧ أشواط حول البيت الحرام تحيةً ووداعاً للكعبة، ثم يصلي ركعتين، ويشرب من زمزم، وينطلق مسافراً إلى أهله دون إقامة أو مكوث بعده.',
      'keyActionsEn': [
        'Perform 7 circuits around the Kaaba as the absolute last activity in Makkah.',
        'No Raml (brisk walking) or Idtiba (shoulder uncovering) required.',
        'Pray 2 Rakat behind Maqam Ibrahim.',
        'Drink Zamzam water and supplicate for accepted Hajj and safe journey home.',
        'Depart Makkah immediately after completing Tawaf al-Wida.',
      ],
      'keyActionsAr': [
        'الطواف حول الكعبة المشرفة ٧ أشواط كآخر عهد بالحرم.',
        'لا يُشرع فيه رَمَل ولا اضطباع.',
        'صلاة ركعتين خلف المقام والشرب من ماء زمزم.',
        'الدعاء بالقبول والعودة إلى الديار سالماً.',
        'المغادرة الفورية لمكة المكرمة بعد الطواف مباشرة.',
      ],
      'quran': {
        'textAr':
            'ثُمَّ لْيَقْضُوا تَفَثَهُمْ وَلْيُوفُوا نُذُورَهُمْ وَلْيَطَّوَّفُوا بِالْبَيْتِ الْعَتِيقِ',
        'referenceAr': 'سورة الحج - الآية ٢٩',
        'textEn':
            'Then let them end their untidiness and fulfill their vows and perform Tawaf around the Ancient House.',
        'referenceEn': 'Surah Al-Hajj (22:29)',
        'explanationEn':
            'General divine directive commanding believers to wrap up their pilgrimage rites with Tawaf around the sacred Kaaba.',
        'explanationAr':
            'الأمر الرباني بختام المناسك بالطواف بالبيت العتيق تعظيماً له.',
      },
      'hadith': {
        'textAr':
            'عَنِ ابْنِ عَبَّاسٍ رَضِيَ اللَّهُ عَنْهُمَا قَالَ: «أُمِرَ النَّاسُ أَنْ يَكُونَ آخِرُ عَهْدِهِمْ بِالْبَيْتِ، إِلاَّ أَنَّهُ خُفِّفَ عَنِ الْمَرْأَةِ الْحَائِضِ»',
        'referenceAr': 'صحيح البخاري (١٧٥٥) وصحيح مسلم (١٣٢٧)',
        'textEn':
            'Ibn Abbas reported: "The people were ordered that their last action should be at the House (Kaaba), except that an exemption was granted for menstruating women."',
        'referenceEn': 'Sahih al-Bukhari 1755, Sahih Muslim 1327',
        'explanationEn':
            'Establishes Tawaf al-Wida as a binding obligation for all departing pilgrims.',
        'explanationAr':
            'وجوب كون طواف الوداع آخر أعمال الحاج بمكة والتخفيف عن الحائض.',
      },
      'dua': {
        'title': 'Dua of Departure & Farewell',
        'arabic':
            'اللَّهُمَّ لا تَجْعَلْ هَذَا آخِرَ الْعَهْدِ بِبَيْتِكَ الْحَرَامِ، وَإِنْ جَعَلْتَهُ آخِرَ الْعَهْدِ فَاعْوَضْنِي عَنْهُ الْجَنَّةَ بِرَحْمَتِكَ يَا أَرْحَمَ الرَّاحِمِينَ',
        'translit':
            'Allahumma la taj’al hadha akhiral-\'ahdi bibaytikal-haram, wa in ja’altahu akhiral-\'ahdi fa’awwidni \'anhul-jannata birahmatika ya arhamar-rahimin.',
        'meaningEn':
            'O Allah, do not make this the last visit to Your Sacred House, and if You decree it to be the last, grant me Paradise in exchange by Your Mercy, O Most Merciful!',
        'meaningAr':
            'التوسل إلى الله ألا يكون هذا آخر العهد بالبيت الحرام والتضرع بالعودة والقبول.',
      },
    },

    // ===== UMRAH STEPS DETAILS =====
    'ihram_u': {
      'titleEn': 'Enter Ihram for Umrah',
      'titleAr': 'الإحرام للعمرة',
      'day': 'At Miqat',
      'dayAr': 'عند الميقات',
      'overviewEn':
          'The first pillar of Umrah is entering Ihram at the designated Miqat with ritual purification, wearing Ihram garments, stating the Niyyah for Umrah ("Labbayk Allahumma Umrah"), and continuously reciting Talbiyah until seeing the Kaaba.',
      'overviewAr':
          'أول أركان العمرة وهو الإحرام من الميقات بالطهارة والغسل ولبس ثياب الإحرام والتلفظ بالنية ("لَبَّيْكَ اللَّهُمَّ عُمْرَةً") ورفع الصوت بالتلبية حتى رؤية الكعبة.',
      'keyActionsEn': [
        'Ghusl & perfumes on body before Ihram.',
        'Wear Ihram cloths (men) / modest dress (women).',
        'Intention: "Labbayk Allahumma Umrah".',
        'Recite Talbiyah continuously.',
      ],
      'keyActionsAr': [
        'الاغتسال والتطيب قبل الإحرام.',
        'ارتداء ملابس الإحرام.',
        'النية: "لَبَّيْكَ اللَّهُمَّ عُمْرَةً".',
        'رفع الصوت بالتلبية.',
      ],
      'quran': {
        'textAr': 'وَأَتِمُّوا الْحَجَّ وَالْعُمْرَةَ لِلَّهِ',
        'referenceAr': 'سورة البقرة - الآية ١٩٦',
        'textEn': 'And complete the Hajj and Umrah for Allah.',
        'referenceEn': 'Surah Al-Baqarah (2:196)',
        'explanationEn':
            'Divine mandate commanding the sincere completion of Umrah rituals exclusively for Allah.',
        'explanationAr': 'وجوب إتمام العمرة وإخلاصها لله تعالى.',
      },
      'hadith': {
        'textAr':
            'عَنْ أَبِي هُرَيْرَةَ رَضِيَ اللَّهُ عَنْهُ أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ قَالَ: «الْعُمْرَةُ إِلَى الْعُمْرَةِ كَفَّارَةٌ لِمَا بَيْنَهُمَا، وَالْحَجُّ الْمَبْرُورُ لَيْسَ لَهُ جَزَاءٌ إِلاَّ الْجَنَّةُ»',
        'referenceAr': 'صحيح البخاري (١٧٧٣) وصحيح مسلم (١٣٤٩)',
        'textEn':
            'Abu Hurairah reported: The Messenger of Allah (ﷺ) said: "An Umrah to another Umrah is an expiation for whatever sins occur between them, and an accepted Hajj receives no reward less than Paradise."',
        'referenceEn': 'Sahih al-Bukhari 1773, Sahih Muslim 1349',
        'explanationEn':
            'Highlights the immense spiritual purification and expiation of sins obtained through Umrah.',
        'explanationAr': 'فضل العمرة ومحوها للذنوب والخطايا.',
      },
      'dua': {
        'title': 'Intention for Umrah',
        'arabic': 'لَبَّيْكَ اللَّهُمَّ عُمْرَةً، لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ...',
        'translit': 'Labbayk Allahumma \'Umrah, Labbayk Allahumma Labbayk...',
        'meaningEn': 'Here I am O Allah, performing Umrah at Your service.',
        'meaningAr': 'التلبية والنية لأداء مناسك العمرة.',
      },
    },

    'tawaf_u': {
      'titleEn': 'Tawaf of Umrah',
      'titleAr': 'طواف العمرة',
      'day': 'Around the Kaaba',
      'dayAr': 'حول الكعبة المشرفة',
      'overviewEn':
          'Circumambulate the Holy Kaaba 7 times counter-clockwise, starting from the Black Stone. Men perform Idtiba and Raml in the first 3 rounds. Conclude with 2 Rakat behind Maqam Ibrahim and drinking Zamzam.',
      'overviewAr':
          'الطواف حول الكعبة المشرفة ٧ أشواط يبدأ من الحجر الأسود وينتهي عنده، مع الاضطباع والرمل للرجال في الأشواط الثلاثة الأولى، يعقبه صلاة ركعتين خلف المقام والشرب من زمزم.',
      'keyActionsEn': [
        '7 rounds around Kaaba.',
        'Idtiba & Raml (men in 3 rounds).',
        '2 Rakat at Maqam Ibrahim.',
        'Drink Zamzam water.',
      ],
      'keyActionsAr': [
        'الطواف ٧ أشواط حول الكعبة.',
        'الاضطباع والرمل للرجال في الثلاث الأولى.',
        'صلاة ركعتين خلف المقام.',
        'الشرب من ماء زمزم.',
      ],
      'quran': {
        'textAr': 'وَلْيَطَّوَّفُوا بِالْبَيْتِ الْعَتِيقِ',
        'referenceAr': 'سورة الحج - الآية ٢٩',
        'textEn': 'And perform Tawaf around the Ancient House.',
        'referenceEn': 'Surah Al-Hajj (22:29)',
        'explanationEn': 'Divine order to perform Tawaf around the sacred Kaaba.',
        'explanationAr': 'الأمر بالطواف بالبيت الحرام.',
      },
      'hadith': {
        'textAr':
            'عَنْ عَبْدِ اللَّهِ بْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا قَالَ: «مَنْ طَافَ بِهَذَا الْبَيْتِ أُسْبُوعًا فَأَحْصَاهُ كَانَ كَعِتْقِ رَقَبَةٍ»',
        'referenceAr': 'سنن الترمذي (٩٥٩)',
        'textEn':
            'Ibn Umar reported: "Whoever performs Tawaf around this House seven times properly, it is equal to freeing a slave."',
        'referenceEn': 'Jami\' at-Tirmidhi 959',
        'explanationEn': 'Virtue and great reward of performing 7 rounds of Tawaf.',
        'explanationAr': 'عظيم ثواب الطواف بالبيت الحرام.',
      },
      'dua': {
        'title': 'Dua Between Corners',
        'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
        'translit': 'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina \'adhaban-nar.',
        'meaningEn': 'Our Lord, grant us good in this world and the next and save us from Hellfire.',
        'meaningAr': 'الدعاء بين الركن اليماني والحجر الأسود.',
      },
    },

    'sai_u': {
      'titleEn': 'Sa’i of Umrah (Safa & Marwah)',
      'titleAr': 'سعي العمرة (الصفا والمروة)',
      'day': 'Between Safa and Marwah',
      'dayAr': 'بين الصفا والمروة',
      'overviewEn':
          'Walk 7 times between the hills of Safa and Marwah, commencing at Safa and ending at Marwah. Men jog lightly between the green lights. Recite Dhikr and make personal supplications at both hills.',
      'overviewAr':
          'السعي بين الصفا والمروة ٧ أشواط يبدأ بالصفا وينتهي بالمروة، يهرول الرجال بين العلمين الأخضرين، مع الإكثار من الذكر والدعاء عند كل جبل.',
      'keyActionsEn': [
        'Begin at Safa facing Kaaba.',
        '7 laps (Safa to Marwah = 1, Marwah to Safa = 2).',
        'Light jog for men between green marker lights.',
        'Conclude at Marwah on 7th lap.',
      ],
      'keyActionsAr': [
        'البداية من جبل الصفا واستقبال القبلة.',
        '٧ أشواط (من الصفا للمروة شوط، والعكس شوط).',
        'الهرولة للرجال بين الميلين الأخضرين.',
        'الختام في الشوط السابع عند المروة.',
      ],
      'quran': {
        'textAr': 'إِنَّ الصَّفَا وَالْمَرْوَةَ مِن شَعَائِرِ اللَّهِ',
        'referenceAr': 'سورة البقرة - الآية ١٥٨',
        'textEn': 'Indeed, Safa and Marwah are among the symbols of Allah.',
        'referenceEn': 'Surah Al-Baqarah (2:158)',
        'explanationEn': 'Safa and Marwah are established as sacred symbols for pilgrimage.',
        'explanationAr': 'اعتبار الصفا والمروة من شعائر الله.',
      },
      'hadith': {
        'textAr':
            'عَنْ جَابِرٍ رَضِيَ اللَّهُ عَنْهُ قَالَ: فَبَدَأَ بِالصَّفَا فَرَقِيَ عَلَيْهِ حَتَّى رَأَى الْبَيْتَ فَاسْتَقْبَلَ الْقِبْلَةَ، فَوَحَّدَ اللَّهَ وَكَبَّرَهُ وَقَالَ: «أَبْدَأُ بِمَا بَدَأَ اللَّهُ بِهِ»',
        'referenceAr': 'صحيح مسلم (١٢١٨)',
        'textEn':
            'Jabir reported: Prophet (ﷺ) started at Safa, mounted it until he saw the Kaaba, faced Qiblah, praised Allah, and said: "I begin with that which Allah began with."',
        'referenceEn': 'Sahih Muslim 1218',
        'explanationEn': 'The exact Sunnah guidance for initiating Sa\'i at Safa.',
        'explanationAr': 'سنة النبي صلى الله عليه وسلم في أداء السعي.',
      },
      'dua': {
        'title': 'Dua on Safa & Marwah',
        'arabic': 'لا إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ...',
        'translit': 'La ilaha illallahu wahdahu la sharika lahu...',
        'meaningEn': 'There is no deity except Allah alone without partner...',
        'meaningAr': 'التوحيد والثناء عند الجبلين.',
      },
    },

    'halq_u': {
      'titleEn': 'Halq / Taqsir (Completion of Umrah)',
      'titleAr': 'الحلق أو التقصير (إتمام العمرة)',
      'day': 'Final step of Umrah',
      'dayAr': 'آخر أعمال العمرة',
      'overviewEn':
          'Complete Umrah by shaving the head (men - preferred) or trimming hair all around. Women trim a fingertip length. All Ihram prohibitions are lifted, and Umrah is completed!',
      'overviewAr':
          'ختام مناسك العمرة بحلق رأس الرجل (وهو الأفضل) أو تقصيره، وتقصير المرأة قدر أنملة، وبذلك تحل العمرة بالكامل وتكتمل المناسك.',
      'keyActionsEn': [
        'Men shave (Halq) or trim (Taqsir).',
        'Women trim fingertip length.',
        'Ihram restrictions completely lifted.',
        'Umrah is officially complete!',
      ],
      'keyActionsAr': [
        'حلق الرجل أو تقصيره.',
        'تقصير المرأة من أطراف شعرها.',
        'خلع ملابس الإحرام والتحلل التام.',
        'اكتمال العمرة بفضل الله.',
      ],
      'quran': {
        'textAr': 'مُحَلِّقِينَ رُءُوسَكُمْ وَمُقَصِّرِينَ لَا تَخَافُونَ',
        'referenceAr': 'سورة الفتح - الآية ٢٧',
        'textEn': 'With your heads shaved and hair shortened, not fearing.',
        'referenceEn': 'Surah Al-Fath (48:27)',
        'explanationEn': 'Divine sanction of shaving and trimming to complete Umrah.',
        'explanationAr': 'مشروعية الحلق والتقصير لإتمام النسك.',
      },
      'hadith': {
        'textAr':
            'عَنْ عَبْدِ اللَّهِ بْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا أَنَّ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ قَالَ: «رَحِمَ اللَّهُ الْمُحَلِّقِينَ»، قَالُوا: وَالْمُقَصِّرِينَ يَا رَسُولَ اللَّهِ؟ قَالَ: «رَحِمَ اللَّهُ الْمُحَلِّقِينَ»، قَالُوا: وَالْمُقَصِّرِينَ؟ قَالَ: «وَالْمُقَصِّرِينَ»',
        'referenceAr': 'صحيح البخاري (١٧٢٧)',
        'textEn':
            'The Prophet (ﷺ) invoked mercy thrice for those who shave their heads and then for those who shorten.',
        'referenceEn': 'Sahih al-Bukhari 1727',
        'explanationEn': 'Prophetic mercy for pilgrims upon shaving or trimming.',
        'explanationAr': 'الدعاء بالرحمة للمحلقين والمقصرين.',
      },
      'dua': {
        'title': 'Dua of Gratitude upon Completion',
        'arabic': 'الْحَمْدُ لِلَّهِ الَّذِي بِنِعْمَتِهِ تَتِمُّ الصَّالِحَاتُ',
        'translit': 'Alhamdu lillahil-ladhi bi-ni\'matihi tatimmus-salihat.',
        'meaningEn': 'Praise be to Allah by Whose grace good deeds are completed.',
        'meaningAr': 'شكر الله تعالى على التوفيق لإتمام العمرة.',
      },
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
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      _hajjType = prefs.getString('hajj_type') ?? 'Tamattu';

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
        _packingDone[item] = prefs.getBool('pack_${item.hashCode}') ?? false;
      }
      for (final item in _documentItems) {
        _documentsDone[item] = prefs.getBool('doc_${item.hashCode}') ?? false;
      }

      _initSegmentControllersForCurrentMode();
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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

    const double rowHeight = 225;
    const double nodeSize = 64;
    const double sidePad = 16;
    const double topOffset = 36;

    return ListView(
      key: ValueKey('rituals_${_mode}_$_hajjType'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildProgressCard(completedCount, steps.length, '$_mode Progress'),
        if (_mode == 'Hajj') ...[
          const SizedBox(height: 16),
          _buildHajjTypeSelector(),
        ],
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final totalHeight = rowHeight * steps.length + nodeSize + topOffset;

            final centers = List.generate(steps.length, (i) {
              final isLeft = i.isEven;
              final cx = isLeft ? sidePad + nodeSize / 2 : width - sidePad - nodeSize / 2;
              final cy = topOffset + nodeSize / 2 + rowHeight * i;
              return Offset(cx, cy);
            });

            final segmentAnimations = List.generate(
              steps.length - 1,
              (i) => _segmentAnimations['${segKeyPrefix}_$i']!,
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
                        final id = steps[i]['id']!;
                        final alreadyDone = doneMap[id] ?? false;

                        if (!alreadyDone) {
                          if (i > 0) {
                            final prevDone = doneMap[steps[i - 1]['id']!] ?? false;
                            if (!prevDone) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Complete "${steps[i - 1]['title']}" first'),
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
                            final nextDone = doneMap[steps[i + 1]['id']!] ?? false;
                            if (nextDone) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Uncheck "${steps[i + 1]['title']}" first'),
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
                      stepId: steps[i]['id']!,
                      title: steps[i]['title']!,
                      guideline: steps[i]['desc']!,
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
                _saveBool('pack_${item.hashCode}', newVal);
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
                _saveBool('doc_${item.hashCode}', newVal);
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
