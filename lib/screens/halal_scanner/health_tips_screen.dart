import 'package:flutter/material.dart';
import 'halal_drawer.dart';

class HealthTipArticle {
  final String title;
  final String description;
  final String date;
  final IconData icon;
  final List<Color> gradient;
  final String content;

  HealthTipArticle({
    required this.title,
    required this.description,
    required this.date,
    required this.icon,
    required this.gradient,
    required this.content,
  });
}

class HealthTipsScreen extends StatefulWidget {
  const HealthTipsScreen({super.key});

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
      gradient: [Color(0xFF8E9EAB), Color(0xFFEEF2F3)],
      content: 'Eating Halal is an essential part of Islamic faith. Good, wholesome (Tayyib) nutrition purifies the mind, enables focused worship, and ensures that prayers are accepted. Conversely, consuming prohibited items has a direct negative spiritual consequence on one\'s heart and spiritual connection with the Almighty.',
    ),
    HealthTipArticle(
      title: 'Are Vinegars Halal? Discover the Truth...',
      description: 'Specialty vinegars such as balsamic, wine, or apple cider vinegar generate many doubts in...',
      date: '20 Jul',
      icon: Icons.liquor_outlined,
      gradient: [Color(0xFFE1533B), Color(0xFFE9967A)],
      content: 'Vinegar produced by natural fermentation of alcohol is halal, as the chemical structure changes entirely from an intoxicant to an acid. However, wine vinegar requires scrutiny to ensure no residual wine remains. Balsamic and cider vinegars are generally halal unless synthetic alcohol is artificially introduced.',
    ),
    HealthTipArticle(
      title: '🧀 Not All Cheese Is Halal! The Truth A...',
      description: 'Cheese is one of the most deceptive foods for Muslims because its key ingredient, rennet, ...',
      date: '17 Jul',
      icon: Icons.breakfast_dining_outlined,
      gradient: [Color(0xFFFFB347), Color(0xFFFFCC33)],
      content: 'The primary concern in cheese production is the source of "rennet"—the enzyme used to coagulate milk. If the rennet is extracted from an animal slaughtered according to Islamic law, or is of microbial/vegetable origin, the cheese is Halal. Otherwise, if sourced from non-halal animal sources, it is Haram.',
    ),
    HealthTipArticle(
      title: 'Healthy alternatives to ultra-processed ...',
      description: 'You don\'t need to give up taste to avoid ultra-processed foods. There are many healthy and...',
      date: '14 Jul',
      icon: Icons.local_dining_outlined,
      gradient: [Color(0xFF83a4d4), Color(0xFFb6fbff)],
      content: 'Replace processed snacks with wholesome alternatives like dates, figs, almonds, or honey. These are traditional foods recommended in the Sunnah that support gut health, lower blood pressure, and supply clean energy without toxic preservatives or synthetic additives.',
    ),
    HealthTipArticle(
      title: 'Seasonal Vegetables in the Month of Ju...',
      description: 'With the summer just beginning, the vegetables that thrive in the heat are now in full swi...',
      date: '08 Jul',
      icon: Icons.eco_outlined,
      gradient: [Color(0xFF56AB2F), Color(0xFFA8E063)],
      content: 'Summertime brings nutrient-rich vegetables like zucchini, peppers, and cucumbers. Consuming seasonal produce ensures high vitamin intake, boosts hydration levels naturally, and aligns our diet with local natural cycles.',
    ),
    HealthTipArticle(
      title: '🧬 Live Longer and Better: How Fasting...',
      description: 'Modern science has discovered something revolutionary: fasting not only helps you live mor...',
      date: '02 Jul',
      icon: Icons.insights_outlined,
      gradient: [Color(0xFF30CFD0), Color(0xFF330867)],
      content: 'Intermittent fasting triggers autophagy—a cellular cleaning process where the body breaks down and recycles damaged cells. Following the Sunnah by fasting on Mondays and Thursdays delivers immense biological benefits, helping to regulate sugar levels, reduce inflammation, and prolong healthy lifespan.',
    ),
    HealthTipArticle(
      title: '⚠️ WARNING! This red insect is in your ...',
      description: 'What is E120? E120 or Carmine is a RED dye made by crushing live insects called cochineal....',
      date: '29 Jun',
      icon: Icons.bug_report_outlined,
      gradient: [Color(0xFFED213A), Color(0xFF93291E)],
      content: 'E120, also known as Carmine, is a popular red coloring extracted from cochineal insects. In Islamic jurisprudence, many scholars consider insect consumption forbidden (Haram) because they are not permissible land animals, except under very specific medical necessity. Check labels on candies, yogurts, and juices!',
    ),
    HealthTipArticle(
      title: '❤️ Your Invisible Shield: How Fasting Pr...',
      description: 'Prophet Muhammad ﷺ described fasting as a shield (junnah) against the fire of hell and the...',
      date: '26 Jun',
      icon: Icons.favorite_border_rounded,
      gradient: [Color(0xFFEF32D9), Color(0xFF89FFFD)],
      content: 'Fasting provides a spiritual and psychological defense system. It shields the mind from evil inclinations, reduces anger, increases empathy for the poor, and acts as a barrier protecting the believer from physical illnesses and spiritual negligence.',
    ),
    HealthTipArticle(
      title: '🍷 Hidden alcohol in common products 🍷 ...',
      description: 'Alcohol doesn\'t always appear under its direct name on...',
      date: '23 Jun',
      icon: Icons.warning_amber_rounded,
      gradient: [Color(0xFF232526), Color(0xFF414345)],
      content: 'Alcohol can hide behind terms like "flavor carriers," "vanilla extract," "soy sauce fermenters," or chemical names like ethanol, ethyl alcohol, and propylene glycol. Always review the extraction carrier used in liquid supplements, desserts, and bakery products.',
    ),
  ];

  void _showArticleDetail(HealthTipArticle article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image Box
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: article.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Icon(article.icon, color: Colors.white, size: 54),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        article.date,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const Icon(Icons.share_outlined, size: 18, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    article.content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF55A498),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9F9FA),
      drawer: const HalalDrawer(activeRoute: 'Health tips'),
      appBar: AppBar(
        backgroundColor: tealColor,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
        padding: const EdgeInsets.all(16.0),
        itemCount: _articles.length,
        itemBuilder: (context, index) {
          final article = _articles[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: InkWell(
              onTap: () => _showArticleDetail(article),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Left image container with beautiful gradient & icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: article.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(article.icon, color: Colors.white, size: 32),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                article.date,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            article.description,
                            style: TextStyle(
                              color: Colors.grey[600],
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
    );
  }
}