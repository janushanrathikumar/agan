// lib/startup_page/start_page.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:restorant/startup page/signin_page.dart';
import 'package:restorant/startup page/signup_page.dart';
import '../language.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF112A18);
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

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
          // ── Premium Background Gradient ──────────────────────────────────────
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF194D25), Color(0xFF0C1E11)],
              ),
            ),
          ),

          // ── Ambient Background Glows ─────────────────────────────────────────
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
                // ── Top Bar (Language Toggle & Skip) ───────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Language Toggle Pill
                      Container(
                        decoration: BoxDecoration(
                          color: kWhite.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kWhite.withOpacity(0.2)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _toggleLanguage,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.language,
                                  color: kWhite,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppLanguage.getText('lang_toggle'),
                                  style: const TextStyle(
                                    color: kWhite,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Skip Button
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
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Slides Carousel (Glassmorphism Cards) ──────────────────────
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isWide ? 720 : 520),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 32,
                                  ),
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
                                      const SizedBox(height: 32),
                                      Text(
                                        slide['title']!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: kWhite,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        slide['text']!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: kMuted.withOpacity(0.9),
                                          fontSize: 16,
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
                  ),
                ),

                // ── Animated Dots Indicator ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        height: 10,
                        width: _currentIndex == i ? 30 : 10,
                        decoration: BoxDecoration(
                          color: _currentIndex == i
                              ? kPrimary
                              : kWhite.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _currentIndex == i
                              ? [
                                  BoxShadow(
                                    color: kPrimary.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Bottom Action Buttons ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Row(
                    children: [
                      // Sign Up (Outline Button)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: kPrimary.withOpacity(0.8),
                              width: 2,
                            ),
                            foregroundColor: kWhite,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            SignUpPage.route,
                          ),
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

                      // Next / Log In (Filled Button)
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: kPrimary.withOpacity(0.5),
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
        ],
      ),
    );
  }
}
