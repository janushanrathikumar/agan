// lib/startup_page/start_page.dart

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:restorant/startup page/signin_page.dart';
import 'package:restorant/startup page/signup_page.dart';
import '../language.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF112A18);
const kCardBg = Color(0xFF163820);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  final PageController _controller = PageController();

  int _currentIndex = 0;

  void _toggleLanguage() {
    setState(() {
      AppLanguage.currentLanguage = AppLanguage.currentLanguage == 'de'
          ? 'en'
          : 'de';
    });
  }

  String _aboutLabel() {
    return AppLanguage.currentLanguage == 'de' ? 'Über uns' : 'About';
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse('https://restaurantkleefeld.ch/privacy');

    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Privacy Policy')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Privacy Policy')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ABOUT US
  // ---------------------------------------------------------------------------

  void _showAboutUsSheet(BuildContext context) {
    final bool isDe = AppLanguage.currentLanguage == 'de';

    final double sheetWidth = MediaQuery.of(context).size.width;

    final double contentMaxWidth = sheetWidth >= 720 ? 640.0 : double.infinity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: const Color(0xFF0F2615),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: kWhite.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: kMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      children: [
                        // -----------------------------------------------------
                        // APP NAME
                        // -----------------------------------------------------
                        const Text(
                          'Restaurant Kleefeld',
                          style: TextStyle(
                            color: kWhite,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          isDe
                              ? 'Online bestellen, Kundenkonto & Restaurantinformationen'
                              : 'Online food ordering, customer account & restaurant information',
                          style: const TextStyle(
                            color: kPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // -----------------------------------------------------
                        // PURPOSE
                        // -----------------------------------------------------
                        _buildInfoCard(
                          icon: Icons.restaurant_menu,
                          title: isDe
                              ? 'Was ist Restaurant Kleefeld?'
                              : 'What is Restaurant Kleefeld?',
                          description: isDe
                              ? 'Restaurant Kleefeld ist unsere Online-Plattform für Gäste. Sie können unsere Speisekarte entdecken, Essen online bestellen, Ihre Bestellungen verwalten und Ihr persönliches Kundenkonto nutzen.'
                              : 'Restaurant Kleefeld is our online platform for guests. Discover our menu, order food online, manage your orders, and use your personal customer account.',
                        ),

                        const SizedBox(height: 12),

                        // -----------------------------------------------------
                        // SPACES
                        // -----------------------------------------------------
                        Text(
                          isDe
                              ? 'Unsere Räumlichkeiten'
                              : 'Our Spaces & Capacity',
                          style: const TextStyle(
                            color: kWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildCapacityBadge(
                              Icons.restaurant,
                              'Restaurant',
                              isDe ? '80 Plätze' : '80 seats',
                            ),
                            _buildCapacityBadge(
                              Icons.meeting_room,
                              isDe ? 'Saal' : 'Event Hall',
                              isDe ? '70 Plätze' : '70 seats',
                            ),
                            _buildCapacityBadge(
                              Icons.yard,
                              isDe ? 'Garten' : 'Garden',
                              isDe ? '60 Plätze' : '60 seats',
                            ),
                            _buildCapacityBadge(
                              Icons.local_bar,
                              isDe ? 'Bar / Fumoir' : 'Bar / Lounge',
                              isDe ? '20 Plätze' : '20 seats',
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // -----------------------------------------------------
                        // SWISS FOOD
                        // -----------------------------------------------------
                        _buildInfoCard(
                          icon: Icons.outdoor_grill,
                          title: isDe
                              ? 'Kulinarisches Angebot'
                              : 'Culinary Delights',
                          description: isDe
                              ? 'Schweizer Spezialitäten und hausgemachte Gerichte wie unsere beliebte Pfannen-Rösti sowie feine sri-lankische Spezialitäten mit authentischen Aromen.'
                              : 'Enjoy Swiss specialties and homemade dishes such as our popular pan-served Rösti together with flavorful Sri Lankan specialties.',
                        ),

                        const SizedBox(height: 12),

                        // -----------------------------------------------------
                        // PIZZA
                        // -----------------------------------------------------
                        _buildInfoCard(
                          icon: Icons.local_pizza,
                          title: isDe
                              ? 'Knusprige Pizza & hausgemachter Eistee'
                              : 'Crispy Pizza & Homemade Iced Tea',
                          description: isDe
                              ? 'Knuspriger Boden und herzhafter Geschmack frisch aus dem Ofen. Dazu unser hausgemachter, frischer Eistee.'
                              : 'Fresh oven-baked pizzas with a crispy crust, served alongside our homemade iced tea.',
                        ),

                        const SizedBox(height: 12),

                        // -----------------------------------------------------
                        // EVENTS
                        // -----------------------------------------------------
                        _buildInfoCard(
                          icon: Icons.celebration,
                          title: isDe
                              ? 'Anlässe, Partyservice & Saal'
                              : 'Events & Catering Service',
                          description: isDe
                              ? 'Unser Saal mit 70 Plätzen eignet sich für Familienfeiern, Geburtstage und Firmenanlässe. Saalvermietung und Apéros auf Anfrage.'
                              : 'Our 70-seat event hall is suitable for family celebrations, birthdays and corporate events. Hall rental and catering are available on request.',
                        ),

                        const SizedBox(height: 24),

                        // -----------------------------------------------------
                        // PRIVACY POLICY
                        // -----------------------------------------------------
                        InkWell(
                          onTap: _launchPrivacyPolicy,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kPrimary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: kPrimary.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.privacy_tip_outlined,
                                  color: kPrimary,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    isDe
                                        ? 'Unsere Datenschutzerklärung lesen'
                                        : 'Read our Privacy Policy',
                                    style: const TextStyle(
                                      color: kWhite,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: kPrimary,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CAPACITY BADGE
  // ---------------------------------------------------------------------------

  Widget _buildCapacityBadge(IconData icon, String title, String capacity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrimary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kPrimary, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                capacity,
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INFORMATION CARD
  // ---------------------------------------------------------------------------

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kWhite.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kPrimary, size: 22),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  description,
                  style: TextStyle(
                    color: kMuted.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isDe = AppLanguage.currentLanguage == 'de';

    final bool isWide = MediaQuery.of(context).size.width >= 720;

    final double contentMaxWidth = isWide ? 720.0 : 520.0;

    // -------------------------------------------------------------------------
    // SLIDES
    // -------------------------------------------------------------------------

    final List<Map<String, String>> slides = [
      {
        'image': 'assets/slide1.png',
        'title': AppLanguage.getText('title_1'),
        'text': AppLanguage.getText('text_1'),
      },
      {
        'image': 'assets/slide2.png',
        'title': AppLanguage.getText('title_2'),
        'text': AppLanguage.getText('text_2'),
      },
      {
        'image': 'assets/slide3.png',
        'title': AppLanguage.getText('title_3'),
        'text': AppLanguage.getText('text_3'),
      },
      {
        'image': 'assets/slide4.png',
        'title': AppLanguage.getText('title_4'),
        'text': AppLanguage.getText('text_4'),
      },
    ];

    // -------------------------------------------------------------------------
    // PAGE
    // -------------------------------------------------------------------------

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // -------------------------------------------------------------------
          // BACKGROUND
          // -------------------------------------------------------------------
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF194D25), Color(0xFF0C1E11)],
              ),
            ),
          ),

          // -------------------------------------------------------------------
          // SAFE AREA
          // -------------------------------------------------------------------
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  children: [
                    // =========================================================
                    // TOP BAR
                    // =========================================================
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          // ---------------------------------------------------
                          // LANGUAGE
                          // ---------------------------------------------------
                          Container(
                            decoration: BoxDecoration(
                              color: kWhite.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: kWhite.withOpacity(0.2),
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _toggleLanguage,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.language,
                                      color: kWhite,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppLanguage.getText('lang_toggle'),
                                      style: const TextStyle(
                                        color: kWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const Spacer(),

                          // ---------------------------------------------------
                          // ABOUT
                          // ---------------------------------------------------
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _showAboutUsSheet(context),
                              splashColor: kPrimary.withOpacity(0.3),
                              highlightColor: kPrimary.withOpacity(0.15),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: kPrimary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: kPrimary.withOpacity(0.6),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      color: kPrimary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _aboutLabel(),
                                      style: const TextStyle(
                                        color: kWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 6),

                          // ---------------------------------------------------
                          // SKIP
                          // ---------------------------------------------------
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              SignInPage.route,
                            ),
                            child: Text(
                              AppLanguage.getText('skip'),
                              style: const TextStyle(
                                color: kMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // =========================================================
                    // APP NAME
                    // =========================================================
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Restaurant Kleefeld',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kWhite,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // =========================================================
                    // APP PURPOSE
                    // =========================================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        isDe
                            ? 'Ihre Online-Plattform für Restaurant Kleefeld: Speisekarte entdecken, Essen online bestellen und Kundenkonto verwalten.'
                            : 'Your online platform for Restaurant Kleefeld: discover our menu, order food online, and manage your customer account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kMuted.withOpacity(0.95),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // =========================================================
                    // SLIDESHOW
                    // =========================================================
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        itemCount: slides.length,
                        itemBuilder: (_, index) {
                          final Map<String, String> slide = slides[index];

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: kWhite.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: kWhite.withOpacity(0.15),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // IMAGE
                                      Expanded(
                                        child: Image.asset(
                                          slide['image']!,
                                          fit: BoxFit.contain,
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // TITLE
                                      Text(
                                        slide['title']!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: kWhite,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      // DESCRIPTION
                                      Text(
                                        slide['text']!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: kMuted.withOpacity(0.9),
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // =========================================================
                    // DOT INDICATORS
                    // =========================================================
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(slides.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            height: 7,
                            width: _currentIndex == index ? 28 : 7,
                            decoration: BoxDecoration(
                              color: _currentIndex == index
                                  ? kPrimary
                                  : kWhite.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }),
                      ),
                    ),

                    // =========================================================
                    // PRIVACY POLICY
                    // =========================================================
                    InkWell(
                      onTap: _launchPrivacyPolicy,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.privacy_tip_outlined,
                              color: kPrimary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isDe
                                  ? 'Datenschutzerklärung lesen'
                                  : 'Read our Privacy Policy',
                              style: const TextStyle(
                                color: kPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                                decorationColor: kPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // =========================================================
                    // BUTTONS
                    // =========================================================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                      child: Row(
                        children: [
                          // ---------------------------------------------------
                          // SIGN UP
                          // ---------------------------------------------------
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: kPrimary.withOpacity(0.8),
                                  width: 2,
                                ),
                                foregroundColor: kWhite,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                if (_currentIndex < slides.length - 1) {
                                  _controller.animateToPage(
                                    slides.length - 1,
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOutCubic,
                                  );
                                } else {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    SignUpPage.route,
                                  );
                                }
                              },
                              child: Text(
                                AppLanguage.getText('sign_up'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // ---------------------------------------------------
                          // NEXT / LOGIN
                          // ---------------------------------------------------
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              onPressed: () {
                                if (_currentIndex < slides.length - 1) {
                                  _controller.nextPage(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                  );
                                } else {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    SignInPage.route,
                                  );
                                }
                              },
                              child: Text(
                                _currentIndex == slides.length - 1
                                    ? AppLanguage.getText('log_in')
                                    : AppLanguage.getText('next'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
        ],
      ),
    );
  }
}
