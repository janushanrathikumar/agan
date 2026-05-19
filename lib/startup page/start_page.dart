// lib/startup_page/start_page.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:restorant/startup page/signin_page.dart';

// Palette
const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class StartPage extends StatefulWidget {
  const StartPage({super.key});
  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final _slides = const [
    {
      'image': 'assets/slide1.png',
      'title': 'Order like a King',
      'text': 'Skip the line. Order your favourite coffee in a few taps.',
    },
    {
      'image': 'assets/slide2.png',
      'title': 'Fast Delivery',
      'text': 'Get it to your table or door quickly.',
    },
    {
      'image': 'assets/slide3.png',
      'title': 'Earn Rewards',
      'text': 'Collect points. Unlock exclusive offers.',
    },
    {
      'image': 'assets/slide4.png',
      'title': 'Stay Connected',
      'text': 'Track orders and get updates.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

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
                colors: [Color(0xFF2A2928), Color(0xFF221F1E)],
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
                color: kMuted.withOpacity(0.12),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Skip button (top-right)
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      SignInPage.route,
                    ),
                    child: const Text('Skip', style: TextStyle(color: kMuted)),
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
                                    color: kWhite.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: kWhite.withOpacity(0.10),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.35),
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
                              color: kWhite.withOpacity(0.22),
                              width: 1,
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
                          child: const Text('Sign Up'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: kWhite,
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
                                ? 'Log In'
                                : 'Next',
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
