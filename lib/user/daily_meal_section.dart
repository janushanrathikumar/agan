// lib/user/daily_meal_section.dart
//
// Active daily meals on the guest's home page.
//
// Active meals stay visible until their scheduled end. Ordering is available
// only inside each meal's window. Adding it uses the normal menu cart.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:restorant/language.dart';
import 'package:restorant/platform_image/platform_image.dart';
import 'package:restorant/shared/daily_meal.dart';
import 'package:restorant/startup%20page/auth_dialog.dart';

const _kPrimary = Color(0xFFB59410);
const _kCardBg = Color(0xFF163820);
const _kField = Color(0xFF1E3A24);
const _kMuted = Color(0xFFA1B3A1);
const _kWhite = Color(0xFFF7F7F2);

class DailyMealSection extends StatefulWidget {
  const DailyMealSection({super.key});

  @override
  State<DailyMealSection> createState() => _DailyMealSectionState();
}

class _DailyMealSectionState extends State<DailyMealSection> {
  late final Stream<List<DailyMeal>> _stream = DailyMealService.streamActive();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Firestore sends nothing when a meal's hours simply run out, so the
    // section re-checks the clock itself and lets it disappear on time.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _open(DailyMeal meal) async {
    if (!meal.isAvailableAt(DateTime.now())) return;
    if (!await requireLogin(
      context,
      reason: AppLanguage.getText('login_to_order'),
    )) {
      return;
    }
    if (!mounted) return;
    if (!meal.isAvailableAt(DateTime.now())) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DailyMealSheet(meal: meal),
    );
  }

  void _showImage(DailyMeal meal) {
    if (meal.imageUrl.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: _kCardBg,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SizedBox(
            height: MediaQuery.sizeOf(dialogContext).height * 0.78,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          meal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _kWhite,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          dialogContext,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded, color: _kWhite),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    child: ColoredBox(
                      color: _kField,
                      child: buildUniversalImage(
                        imageUrl: meal.imageUrl,
                        fit: BoxFit.contain,
                        fallback: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: _kMuted,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return StreamBuilder<List<DailyMeal>>(
      stream: _stream,
      builder: (context, snapshot) {
        final meals = (snapshot.data ?? const <DailyMeal>[])
            .where((meal) => now.isBefore(meal.availableUntil))
            .toList();
        if (meals.isEmpty) return const SizedBox.shrink();

        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final todayMeals = <DailyMeal>[];
        final tomorrowMeals = <DailyMeal>[];
        final laterMeals = <DailyMeal>[];
        for (final meal in meals) {
          final day = DateTime(
            meal.availableFrom.year,
            meal.availableFrom.month,
            meal.availableFrom.day,
          );
          if (day == today || meal.isAvailableAt(now)) {
            todayMeals.add(meal);
          } else if (day == tomorrow) {
            tomorrowMeals.add(meal);
          } else if (day.isAfter(tomorrow)) {
            laterMeals.add(meal);
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (todayMeals.isNotEmpty)
                _group('today_for_you', todayMeals, now),
              if (tomorrowMeals.isNotEmpty)
                _group('tomorrow_for_you', tomorrowMeals, now),
              if (laterMeals.isNotEmpty)
                _group('upcoming_for_you', laterMeals, now),
            ],
          ),
        );
      },
    );
  }

  Widget _group(String titleKey, List<DailyMeal> meals, DateTime now) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: _kPrimary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLanguage.getText(titleKey),
                      style: const TextStyle(
                        color: _kWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      AppLanguage.getText('daily_meal_subtitle'),
                      style: const TextStyle(color: _kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _kField,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${meals.length}',
                  style: const TextStyle(
                    color: _kPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final meal in meals) ...[
            _card(meal, now),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _card(DailyMeal meal, DateTime now) {
    final available = meal.isAvailableAt(now);
    final status = available
        ? AppLanguage.getText('daily_meal_available_now')
        : AppLanguage.getText('not_orderable_yet');
    final statusColor = available ? const Color(0xFF80D59A) : _kPrimary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = (constraints.maxWidth * 0.34).clamp(100.0, 220.0);
        final compact = constraints.maxWidth < 480;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kPrimary.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: imageWidth,
                height: compact ? 258 : 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    meal.imageUrl.isEmpty
                        ? const ColoredBox(
                            color: _kField,
                            child: Icon(
                              Icons.restaurant_menu_rounded,
                              color: _kPrimary,
                              size: 42,
                            ),
                          )
                        : Semantics(
                            button: true,
                            label:
                                '${AppLanguage.getText('view_meal_image')}: ${meal.name}',
                            child: InkWell(
                              onTap: () => _showImage(meal),
                              child: buildUniversalImage(
                                imageUrl: meal.imageUrl,
                                fallback: const ColoredBox(
                                  color: _kField,
                                  child: Icon(
                                    Icons.restaurant_menu_rounded,
                                    color: _kPrimary,
                                    size: 42,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    if (meal.imageUrl.isNotEmpty)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Tooltip(
                          message: AppLanguage.getText('view_meal_image'),
                          child: Material(
                            color: const Color(
                              0xFF102819,
                            ).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(9),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _showImage(meal),
                              icon: const Icon(
                                Icons.open_in_full_rounded,
                                color: _kWhite,
                                size: 17,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(compact ? 12 : 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            available ? Icons.circle : Icons.schedule_rounded,
                            color: statusColor,
                            size: available ? 8 : 13,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        meal.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _kWhite,
                          fontSize: compact ? 16 : 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (meal.description.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          meal.description,
                          maxLines: compact ? 3 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _kMuted,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        meal.windowLabel,
                        style: const TextStyle(color: _kMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'CHF ${meal.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: _kPrimary,
                          fontSize: compact ? 16 : 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (available) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _open(meal),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kPrimary,
                              foregroundColor: _kWhite,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              AppLanguage.getText('add_to_cart'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: compact ? 11 : 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Quantity and a note, then into the cart.
class _DailyMealSheet extends StatefulWidget {
  const _DailyMealSheet({required this.meal});

  final DailyMeal meal;

  @override
  State<_DailyMealSheet> createState() => _DailyMealSheetState();
}

class _DailyMealSheetState extends State<_DailyMealSheet> {
  final _note = TextEditingController();
  int _qty = 1;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _addToCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // The hours can run out while this sheet is open; a meal is orderable
    // only inside its own window.
    if (!widget.meal.isAvailableAt(DateTime.now())) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLanguage.getText('daily_meal_over')),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('chat')
          .doc(user.uid)
          .collection('items')
          .add(widget.meal.cartItem(qty: _qty, note: _note.text.trim()));

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLanguage.getText('added_to_cart')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLanguage.getText("Error:")} $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;

    return Container(
      decoration: const BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: _kMuted,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (meal.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: buildUniversalImage(
                  imageUrl: meal.imageUrl,
                  height: 160,
                  fallback: const ColoredBox(color: _kField),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            meal.name,
            style: const TextStyle(
              color: _kWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (meal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              meal.description,
              style: const TextStyle(color: _kMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            style: const TextStyle(color: _kWhite),
            decoration: InputDecoration(
              hintText: AppLanguage.getText('Note (optional)'),
              hintStyle: const TextStyle(color: _kMuted),
              filled: true,
              fillColor: _kField,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: _kPrimary),
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
              ),
              Text(
                '$_qty',
                style: const TextStyle(
                  color: _kWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: _kPrimary),
                onPressed: _qty < 20 ? () => setState(() => _qty++) : null,
              ),
              const Spacer(),
              Text(
                'CHF ${(meal.price * _qty).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: _kPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: _kWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _saving ? null : _addToCart,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _kWhite,
                      ),
                    )
                  : Text(
                      AppLanguage.getText('add_to_cart'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
