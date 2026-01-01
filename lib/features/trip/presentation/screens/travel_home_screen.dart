import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/features/trip/domain/trip_state.dart';
import 'package:new_tripple/features/trip/presentation/widgets/trip_card.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/shared/widgets/custom_header.dart';
import 'package:new_tripple/shared/widgets/tripple_empty_state.dart';

class TravelHomeScreen extends StatefulWidget {
  final Function(Trip) onTripSelected;

  const TravelHomeScreen({super.key, required this.onTripSelected});
  
  @override
  State<TravelHomeScreen> createState() => _TravelHomeScreenState();
}

class _TravelHomeScreenState extends State<TravelHomeScreen> {
  bool _showPastTrips = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // 背景色を指定しておくと安心
      body: SafeArea(
        bottom: false, 
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              
              // 1. My Trips ヘッダー
              CustomHeader(title: "My Trips"),

              // 2. リスト部分 (画面いっぱい使う)
              Expanded(
                child: BlocBuilder<TripCubit, TripState>(
                  builder: (context, state) {
                    if (state.status == TripStatus.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final now = DateTime.now();
                    final visibleTrips = state.allTrips.where((t) => 
                        t.tags == null || !t.tags!.contains('past_trip')
                    ).toList();

                    final futureTrips = visibleTrips.where((t) => t.endDate.isAfter(now)).toList();
                    final pastTrips = visibleTrips.where((t) => t.endDate.isBefore(now)).toList();

                    futureTrips.sort((a, b) => a.startDate.compareTo(b.startDate));
                    pastTrips.sort((a, b) => b.startDate.compareTo(a.startDate));

                    return ListView(
                      // ボトムナビゲーションバー(約80px) + FABのスペースを確保
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        // Future Trips
                        if (futureTrips.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40), // 少し上を開けるとバランス良し
                            child: TrippleEmptyState(
                              title: 'No trips planned yet',
                              message: 'Tap the "+" button below to start planning your next adventure!',
                              icon: Icons.flight_takeoff_rounded,
                              accentColor: AppColors.accent,
                            ),
                          )
                        else
                          ...futureTrips.map((trip) => TripCard(
                            trip: trip,
                            onTap: () {
                              widget.onTripSelected(trip);
                            },
                          )),

                        const SizedBox(height: 24),

                        // Past Trips
                        if (pastTrips.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => setState(() => _showPastTrips = !_showPastTrips),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Text('Past Trips 🕘', style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
                                  const Spacer(),
                                  Icon(_showPastTrips ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          AnimatedCrossFade(
                            firstChild: const SizedBox(width: double.infinity),
                            secondChild: Column(
                              children: pastTrips.map((trip) => TripCard(
                                trip: trip,
                                onTap: () => widget.onTripSelected(trip),
                              )).toList(),
                            ),
                            crossFadeState: _showPastTrips ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 300),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}