// lib/startup_page/start_page.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:restorant/startup page/signin_page.dart';
import '../language.dart'; // Language file இணைக்கப்பட்டுள்ளது


const kPrimary = Color(0xFFE49024); // ஆரஞ்சு நிறம் (Mountains/Banner)
const kBg = Color(0xFF112A18); // அடர் பச்சை நிறம் (Dark Green - Background)
const kDarkGreen = Color(0xFF194D25); // லோகோ பச்சை நிறம் (Logo Forest Green)
const kMuted = Color(0xFFA1B3A1); // சற்று மங்கலான பச்சை/சாம்பல்
const kWhite = Color(0xFFF7F7F2); // கிரீம் வெள்ளை (Cream/Off-white)

class StartPage extends StatefulWidget {
  const StartPage({super.key});
  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  // மொழியை மாற்றும் Function
  void _toggleLanguage() {
    setState(() {
      if (AppLanguage.currentLanguage == 'de') {
        AppLanguage.currentLanguage = 'en';
      } else {
        AppLanguage.currentLanguage = 'de';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    // ஸ்லைடு டேட்டா (Language file-ல் இருந்து Text எடுக்கப்படுகிறது)
    final _slides = [
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
          // Background gradient
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF194D25),
                  Color(0xFF0C1E11),
                ], // லோகோ பச்சை Gradient
              ),
            ),
          ),
          // Accent blobs
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimary.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimary.withOpacity(0.12),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Top Bar (Language Toggle & Skip button)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Language Toggle Button
                      TextButton.icon(
                        onPressed: _toggleLanguage,
                        icon: const Icon(
                          Icons.language,
                          color: kWhite,
                          size: 20,
                        ),
                        label: Text(
                          AppLanguage.getText('lang_toggle'),
                          style: const TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Skip button
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          SignInPage.route,
                        ),
                        child: Text(
                          AppLanguage.getText('skip'),
                          style: const TextStyle(color: kMuted),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Slides
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isWide ? 720 : 520),
                      child: PageView.builder(
                        controller: _controller,
                        onPageChanged: (i) => setState(() => _currentIndex = i),
                        itemCount: _slides.length,
                        itemBuilder: (_, i) {
                          final slide = _slides[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isWide ? 36 : 24,
                                    vertical: isWide ? 28 : 22,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kWhite.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: kWhite.withOpacity(0.15),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 24,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Image.asset(
                                          slide['image']!,
                                          height: isWide ? 260 : 200,
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
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        slide['text']!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: kMuted,
                                          fontSize: 15,
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

                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      height: 10,
                      width: _currentIndex == i ? 22 : 10,
                      decoration: BoxDecoration(
                        color: _currentIndex == i
                            ? kPrimary
                            : kWhite.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // CTA buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: kPrimary.withOpacity(0.8),
                              width: 1.5,
                            ),
                            foregroundColor: kWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            SignInPage.route,
                          ),
                          child: Text(AppLanguage.getText('sign_up')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor:
                                Colors.white, // Text color on Orange button
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          onPressed: () {
                            if (_currentIndex < _slides.length - 1) {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 260),
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
                            _currentIndex == _slides.length - 1
                                ? AppLanguage.getText('log_in')
                                : AppLanguage.getText('next'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
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
