import 'package:flutter/material.dart';
import 'halal_drawer.dart';
import 'guides_and_walkthrough.dart' hide MobileFrame;
import 'additives_list_screen.dart';

class HealthTipArticle {
  final String title;
  final String description;
  final String date;
  final IconData icon;
  final List<Color> gradient;
  final String content;
  // Path to the article's image, e.g. 'assets/images/health_tips/xxx.jpg'.
  // Drop your downloaded image at this path (and register the folder in
  // pubspec.yaml under flutter/assets) — if the file isn't there yet, a
  // gradient + icon placeholder is shown instead so nothing crashes.
  final String imagePath;

  HealthTipArticle({
    required this.title,
    required this.description,
    required this.date,
    required this.icon,
    required this.gradient,
    required this.content,
    required this.imagePath,
  });
}

class HealthTipsScreen extends StatefulWidget {
  final bool isDarkMode;
  const HealthTipsScreen({super.key, this.isDarkMode = false});

  @override
  State<HealthTipsScreen> createState() => _HealthTipsScreenState();
}

class _HealthTipsScreenState extends State<HealthTipsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<HealthTipArticle> _articles = [
    HealthTipArticle(
      title: 'The impact of what we eat on our spirit...',
      description: 'In Islam, food is not only a physical necessity, it also influences the heart and faith. E...',
      date: 'Yesterday',
      icon: Icons.spa_outlined,
      gradient: const [Color(0xFF8E9EAB), Color(0xFFEEF2F3)],
      imagePath: 'assets/images/health_tips/impact_of_food.jpg',
      content: 'In Islam, food is not only a physical necessity, it also influences the heart and faith. Eating Halal and tayyib (pure and wholesome) strengthens the connection with Allah and brings spiritual peace.\n\nKey aspects:\n\n\ud83d\udd45 Obedience to Allah: choosing Halal is fulfilling a divine command.\n\n\u2764\ufe0f Inner purity: what we consume directly affects our spiritual state.\n\n\ud83c\udf3f Balance of the soul: healthy and natural foods promote calmness and gratitude.\n\n\ud83d\udc6a Example for the family: teaching Halal eating transmits faith and values.\n\nEvery bite can bring us closer or farther from spirituality. That\u2019s why consciously choosing what we eat is part of living Islam every day.\n\ud83d\udc49 With Tag Halal you can ensure what you consume is truly Halal and beneficial for both body and soul.',
    ),
    HealthTipArticle(
      title: 'Are Vinegars Halal? Discover the Truth...',
      description: 'Specialty vinegars such as balsamic, wine, or apple cider vinegar generate many doubts in...',
      date: '20 Jul',
      icon: Icons.liquor_outlined,
      gradient: const [Color(0xFFE1533B), Color(0xFFE9967A)],
      imagePath: 'assets/images/health_tips/vinegars_halal.jpg',
      content: 'Vinegar produced by natural fermentation of alcohol is halal, as the chemical structure changes entirely from an intoxicant to an acid. However, wine vinegar requires scrutiny to ensure no residual wine remains. Balsamic and cider vinegars are generally halal unless synthetic alcohol is artificially introduced.',
    ),
    HealthTipArticle(
      title: '\ud83e\uddc0 Not All Cheese Is Halal! The Truth A...',
      description: 'Cheese is one of the most deceptive foods for Muslims because its key ingredient, rennet, ...',
      date: '17 Jul',
      icon: Icons.breakfast_dining_outlined,
      gradient: const [Color(0xFFFFB347), Color(0xFFFFCC33)],
      imagePath: 'assets/images/health_tips/cheese_halal.jpg',
      content: 'The primary concern in cheese production is the source of "rennet"\u2014the enzyme used to coagulate milk. If the rennet is extracted from an animal slaughtered according to Islamic law, or is of microbial/vegetable origin, the cheese is Halal. Otherwise, if sourced from non-halal animal sources, it is Haram.',
    ),
    HealthTipArticle(
      title: 'Healthy alternatives to ultra-processed ...',
      description: 'You don\'t need to give up taste to avoid ultra-processed foods. There are many healthy and...',
      date: '14 Jul',
      icon: Icons.local_dining_outlined,
      gradient: const [Color(0xFF83a4d4), Color(0xFFb6fbff)],
      imagePath: 'assets/images/health_tips/ultra_processed_alternatives.jpg',
      content: 'Replace processed snacks with wholesome alternatives like dates, figs, almonds, or honey. These are traditional foods recommended in the Sunnah that support gut health, lower blood pressure, and supply clean energy without toxic preservatives or synthetic additives.',
    ),
    HealthTipArticle(
      title: 'Seasonal Vegetables in the Month of Ju...',
      description: 'With the summer just beginning, the vegetables that thrive in the heat are now in full swi...',
      date: '08 Jul',
      icon: Icons.eco_outlined,
      gradient: const [Color(0xFF56AB2F), Color(0xFFA8E063)],
      imagePath: 'assets/images/health_tips/seasonal_vegetables.jpg',
      content: 'Summertime brings nutrient-rich vegetables like zucchini, peppers, and cucumbers. Consuming seasonal produce ensures high vitamin intake, boosts hydration levels naturally, and aligns our diet with local natural cycles.',
    ),
    HealthTipArticle(
      title: '\ud83e\uddec Live Longer and Better: How Fasting...',
      description: 'Modern science has discovered something revolutionary: fasting not only helps you live mor...',
      date: '02 Jul',
      icon: Icons.insights_outlined,
      gradient: const [Color(0xFF30CFD0), Color(0xFF330867)],
      imagePath: 'assets/images/health_tips/fasting_live_longer.jpg',
      content: 'Intermittent fasting triggers autophagy\u2014a cellular cleaning process where the body breaks down and recycles damaged cells. Following the Sunnah by fasting on Mondays and Thursdays delivers immense biological benefits, helping to regulate sugar levels, reduce inflammation, and prolong healthy lifespan.',
    ),
    HealthTipArticle(
      title: '\u26a0\ufe0f WARNING! This red insect is in your ...',
      description: 'What is E120? E120 or Carmine is a RED dye made by crushing live insects called cochineal....',
      date: '29 Jun',
      icon: Icons.bug_report_outlined,
      gradient: const [Color(0xFFED213A), Color(0xFF93291E)],
      imagePath: 'assets/images/health_tips/red_insect_e120.jpg',
      content: 'E120, also known as Carmine, is a popular red coloring extracted from cochineal insects. In Islamic jurisprudence, many scholars consider insect consumption forbidden (Haram) because they are not permissible land animals, except under very specific medical necessity. Check labels on candies, yogurts, and juices!',
    ),
    HealthTipArticle(
      title: '\u2764\ufe0f Your Invisible Shield: How Fasting Pr...',
      description: 'Prophet Muhammad \ufdfa described fasting as a shield (junnah) against the fire of hell and the...',
      date: '26 Jun',
      icon: Icons.favorite_border_rounded,
      gradient: const [Color(0xFFEF32D9), Color(0xFF89FFFD)],
      imagePath: 'assets/images/health_tips/fasting_shield.jpg',
      content: 'Fasting provides a spiritual and psychological defense system. It shields the mind from evil inclinations, reduces anger, increases empathy for the poor, and acts as a barrier protecting the believer from physical illnesses and spiritual negligence.',
    ),
    HealthTipArticle(
      title: '\ud83c\udf77 Hidden alcohol in common products \ud83c\udf77 ...',
      description: 'Alcohol doesn\'t always appear under its direct name on...',
      date: '23 Jun',
      icon: Icons.warning_amber_rounded,
      gradient: const [Color(0xFF232526), Color(0xFF414345)],
      imagePath: 'assets/images/health_tips/hidden_alcohol.jpg',
      content: 'Alcohol can hide behind terms like "flavor carriers," "vanilla extract," "soy sauce fermenters," or chemical names like ethanol, ethyl alcohol, and propylene glycol. Always review the extraction carrier used in liquid supplements, desserts, and bakery products.',
    ),
  ];

  void _openArticle(HealthTipArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HealthTipDetailScreen(article: article, isDarkMode: widget.isDarkMode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);

    return MobileFrame(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF9F9FA),
        drawer: HalalDrawer(
          activeRoute: 'Health tips',
          isDarkMode: widget.isDarkMode,
        ),
        appBar: AppBar(
          backgroundColor: tealColor,
          elevation: 0,
         
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
     ),
          title: const Text(
            'Health tips',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: ListView.builder(
          padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, MediaQuery.of(context).padding.bottom + 16.0),
          itemCount: _articles.length,
          itemBuilder: (context, index) {
            final article = _articles[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
              ),
              child: InkWell(
                onTap: () => _openArticle(article),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // Left thumbnail — shows the real image once you drop
                      // it at article.imagePath; falls back to the gradient
                      // + icon placeholder until then.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: Image.asset(
                            article.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: article.gradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(article.icon, color: Colors.white, size: 32),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Right text column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    article.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  article.date,
                                  style: TextStyle(
                                    color: widget.isDarkMode ? Colors.white70 : Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              article.description,
                              style: TextStyle(
                                color: widget.isDarkMode ? Colors.white70 : Colors.grey[600],
                                fontSize: 12,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Full-page article detail — matches the "Tag Halal Food" reference design:
// back + share app bar, a boxed image, a boxed title, and a boxed content
// paragraph, all on a light mint background.
class HealthTipDetailScreen extends StatelessWidget {
  final HealthTipArticle article;
  final bool isDarkMode;

  const HealthTipDetailScreen({super.key, required this.article, this.isDarkMode = false});

  static const Color tealColor = Color(0xFF55A498);
  static const Color pageBg = Color(0xFFE3F2EC);

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : pageBg,
        appBar: AppBar(
          backgroundColor: tealColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Tag Halal Food',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sharing "${article.title}"...')),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Boxed hero image — drop your image at article.imagePath.
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tealColor, width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        article.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: article.gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(article.icon, color: Colors.white, size: 64),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tealColor, width: 1.2),
                  ),
                  child: Text(
                    article.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Content box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tealColor, width: 1.2),
                  ),
                  child: Text(
                    article.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDarkMode ? Colors.white : Colors.black87,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}