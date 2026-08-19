// lib/startup_page/start_page.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this import for the privacy link
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
      AppLanguage.currentLanguage = (AppLanguage.currentLanguage == 'de')
          ? 'en'
          : 'de';
    });
  }

  String _aboutLabel() {
    return AppLanguage.currentLanguage == 'de' ? 'Über uns' : 'About';
  }

  // Helper method to open the privacy policy link
  Future<void> _launchPrivacyPolicy() async {
    // 🔴 REPLACE THIS LINK WITH YOUR ACTUAL PRIVACY POLICY LINK 🔴
    final Uri url = Uri.parse('https://restaurantkleefeld.ch/privacy');
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Privacy Policy')),
        );
      }
    }
  }

  void _showAboutUsSheet(BuildContext context) {
    final isDe = AppLanguage.currentLanguage == 'de';
    final sheetWidth = MediaQuery.of(context).size.width;
    final contentMaxWidth = sheetWidth >= 720 ? 640.0 : double.infinity;

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
                        Text(
                          isDe
                              ? 'Restaurant Kleefeld App' // 🟢 Inga maathirukken
                              : 'Restaurant Kleefeld App', // 🟢 Inga maathirukken
                          style: const TextStyle(
                            color: kWhite,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isDe
                              ? 'Informationen, Angebot & Datenschutz'
                              : 'Information, Cuisine & Privacy',
                          style: const TextStyle(
                            color: kPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- REQUIRED BY GOOGLE: APP PURPOSE ---
                        _buildInfoCard(
                          icon: Icons.app_shortcut_rounded,
                          title: isDe
                              ? 'Zweck dieser App'
                              : 'Purpose of this App',
                          description: isDe
                              ? 'Willkommen bei Restorant. Mit dieser App können Sie ganz einfach unsere Speisekarte durchsuchen, Essen online bestellen und Ihr Benutzerkonto verwalten.'
                              : 'Welcome to Restorant. This application allows users to easily browse our menu, order food online, and manage their personal accounts.',
                        ),
                        const SizedBox(height: 12),

                        // --- REQUIRED BY GOOGLE: DATA USAGE TRANSPARENCY ---
                        _buildInfoCard(
                          icon: Icons.security_rounded,
                          title: isDe
                              ? 'Wie wir Ihre Daten nutzen'
                              : 'How we use your data',
                          description: isDe
                              ? 'Wir fordern Ihre E-Mail-Adresse und Telefonnummer an, um Ihr Konto sicher zu authentifizieren, Ihre Essensbestellungen abzuwickeln und Sie über wichtige Updates zu Ihrer Lieferung zu informieren. Wir geben Ihre Daten nicht an Dritte weiter.'
                              : 'We request your email address and phone number to securely authenticate your account, process your food orders, and contact you regarding important delivery updates. We do not share your data with third parties.',
                        ),
                        const SizedBox(height: 12),

                        // --- REQUIRED BY GOOGLE: PRIVACY POLICY LINK ---
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
                        const SizedBox(height: 24),

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
                              isDe ? 'Restaurant' : 'Restaurant',
                              '80 Plätze',
                            ),
                            _buildCapacityBadge(
                              Icons.meeting_room,
                              isDe ? 'Saal' : 'Event Hall',
                              '70 Plätze',
                            ),
                            _buildCapacityBadge(
                              Icons.yard,
                              isDe ? 'Garten' : 'Garden',
                              '60 Plätze',
                            ),
                            _buildCapacityBadge(
                              Icons.local_bar,
                              isDe ? 'Bar / Fumoir' : 'Bar / Lounge',
                              '20 Plätze',
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        _buildInfoCard(
                          icon: Icons.outdoor_grill,
                          title: isDe
                              ? 'Kulinarisches Angebot'
                              : 'Culinary Delights',
                          description: isDe
                              ? 'Schweizer Spezialitäten und hausgemachte Gerichte wie unsere beliebte Pfannen-Rösti sowie feine sri-lankische Spezialitäten mit authentischen Aromen.'
                              : 'Authentic Swiss specialties such as homemade pan-served Rösti, paired with flavorful Sri Lankan traditional dishes.',
                        ),

                        const SizedBox(height: 12),

                        _buildInfoCard(
                          icon: Icons.local_pizza,
                          title: isDe
                              ? 'Knusprige Pizza & Hausgemachter Eistee'
                              : 'Crispy Pizza & Fresh Iced Tea',
                          description: isDe
                              ? 'Knuspriger Boden und herzhafter Geschmack frisch aus dem Ofen. Dazu perfekt: Unser hausgemachter, frischer Eistee.'
                              : 'Oven-baked pizzas with crispy crusts alongside our freshly prepared homemade iced tea.',
                        ),

                        const SizedBox(height: 12),

                        _buildInfoCard(
                          icon: Icons.celebration,
                          title: isDe
                              ? 'Anlässe, Partyservice & Saal'
                              : 'Events & Catering Service',
                          description: isDe
                              ? 'Unser Saal (70 Plätze) eignet sich perfekt für Familienfeiern, Geburtstage und Firmenanlässe. Saalvermietung & Apéros auf Anfrage.'
                              : 'Our 70-seat hall is ideal for family events, birthdays, and corporate celebrations. Catering and hall rentals available.',
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    final contentMaxWidth = isWide ? 720.0 : 520.0;

    final slides = [
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

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF194D25), Color(0xFF0C1E11)],
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimary.withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox(),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        children: [
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
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: PageView.builder(
                        controller: _controller,
                        onPageChanged: (i) => setState(() => _currentIndex = i),
                        itemCount: slides.length,
                        itemBuilder: (_, i) {
                          final slide = slides[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: kWhite.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: kWhite.withOpacity(0.15),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 30,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Image.asset(
                                          slide['image']!,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        slide['title']!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: kWhite,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        slide['text']!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: kMuted.withOpacity(0.9),
                                          fontSize: 15,
                                          height: 1.45,
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
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        height: 7,
                        width: _currentIndex == i ? 28 : 7,
                        decoration: BoxDecoration(
                          color: _currentIndex == i
                              ? kPrimary
                              : kWhite.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                      child: Row(
                        children: [
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
