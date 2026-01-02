import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/features/trip/domain/trip_state.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';
import 'package:new_tripple/features/trip/presentation/screens/place_search_modeal.dart';
import 'package:new_tripple/services/geocoding_service.dart';
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';
import 'package:new_tripple/shared/widgets/tripple_toast.dart';

class PastTripLogModal extends StatefulWidget {
  const PastTripLogModal({super.key});

  @override
  State<PastTripLogModal> createState() => _PastTripLogModalState();
}

class _PastTripLogModalState extends State<PastTripLogModal> {
  bool _isAdding = false;

  // 👇 初期値を "Past Trip" に設定！
  final TextEditingController _titleController = TextEditingController(text: 'Past Trip');
  List<TripDestination> _tempDestinations = [];

  @override
  Widget build(BuildContext context) {
    return TrippleModalScaffold(
      // 👇 1. タイトルを動的に切り替え！
      title: _isAdding ? "New Entry" : "Past Travel Log",
      // アイコンも切り替えるとオシャレ
      icon: _isAdding ? Icons.edit_location_alt_rounded : Icons.history_edu_rounded,
      
      heightRatio: TrippleModalSize.highRatio,

      // 👇 2. 「追加モード」のときだけ、ヘッダー右側に「戻るボタン」を表示！
      extraHeaderActions: _isAdding 
        ? [
            TextButton.icon(
              onPressed: () => setState(() => _isAdding = false),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            )
          ] 
        : null,

      onSave: _isAdding ? _saveTrip : null,
      saveLabel: 'Save to History',

      isScrollable: _isAdding,

      child: _isAdding 
        ? _buildAddForm() 
        : _buildHistoryList(),
    );
  }

  // 1. 履歴一覧モード (変更なし)
  Widget _buildHistoryList() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _isAdding = true;
                _titleController.text = 'Past Trip';
                _tempDestinations = [];
              });
            },
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text('Log New Past Trip'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Your History', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 12),
        
        Expanded(
          child: BlocBuilder<TripCubit, TripState>(
            builder: (context, state) {
              final pastTrips = state.allTrips.where((t) => 
                t.tags != null && t.tags!.contains('past_trip')
              ).toList();
              pastTrips.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              if (pastTrips.isEmpty) {
                return Center(child: Text('No history yet.', style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey)));
              }

              return ListView.separated(
                itemCount: pastTrips.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildHistoryItem(pastTrips[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  // 2. 新規作成フォームモード (手動ヘッダーを削除！)
  Widget _buildAddForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 👇 3. ここにあった Row(戻るボタン + タイトル) は削除！
        // Scaffoldのヘッダーが代わりになるので不要です。

        TrippleTextField(
          controller: _titleController,
          hintText: 'Trip Title (e.g. Eurotrip 2010)',
          label: 'Title',
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Destinations', style: AppTextStyles.label),
            TextButton.icon(
              onPressed: _addNewDestination,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Place'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_tempDestinations.isEmpty)
          Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.map_outlined, color: Colors.grey, size: 40),
                const SizedBox(height: 8),
                Text('Add places you visited!', style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey)),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tempDestinations.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final dest = _tempDestinations[index];
              return _buildEditDestinationItem(index, dest);
            },
          ),
      ],
    );
  }


  // 履歴アイテム (前回と同じ)
  Widget _buildHistoryItem(Trip trip) {
    if (trip.destinations.isEmpty) return const SizedBox.shrink();
    final names = trip.destinations.map((d) => d.name).join(', ');
    final totalDays = trip.endDate.difference(trip.startDate).inDays + 1;
    final countryCode = trip.destinations.first.countryCode?.toUpperCase() ?? '🌍';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Text(countryCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(names, style: AppTextStyles.label.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Text('$totalDays Days', style: AppTextStyles.label.copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
            onPressed: () => _confirmDelete(trip),
          ),
        ],
      ),
    );
  }

  // 👇 リストアイテム (日数調整ボタン付き！)
  Widget _buildEditDestinationItem(int index, TripDestination dest) {
    final days = dest.stayDays ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.place, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          
          // 場所名 & 国名
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dest.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (dest.country != null)
                  Text(dest.country!, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),

          // 日数調整エリア
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // マイナスボタン
                GestureDetector(
                  onTap: () {
                    if (days > 1) {
                      setState(() {
                        // コピーして更新 (モデルがimmutableなので)
                        _tempDestinations[index] = TripDestination(
                          name: dest.name, country: dest.country, countryCode: dest.countryCode,
                          state: dest.state, latitude: dest.latitude, longitude: dest.longitude,
                          stayDays: days - 1,
                        );
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(Icons.remove_rounded, size: 16, color: days > 1 ? AppColors.textPrimary : Colors.grey),
                  ),
                ),
                
                // 日数表示
                Text('$days d', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                
                // プラスボタン
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _tempDestinations[index] = TripDestination(
                        name: dest.name, country: dest.country, countryCode: dest.countryCode,
                        state: dest.state, latitude: dest.latitude, longitude: dest.longitude,
                        stayDays: days + 1,
                      );
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          
          // 削除ボタン
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
            onPressed: () => setState(() => _tempDestinations.removeAt(index)),
          ),
        ],
      ),
    );
  }

  // --- ロジック ---

  Future<void> _addNewDestination() async {
    final result = await showModalBottomSheet<PlaceSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // 👇 ヒントテキストを渡す！
      builder: (context) => const PlaceSearchModal(hintText: 'e.g. Paris, Tokyo, Italy'),
    );

    if (result == null) return;

    setState(() {
      // ダイアログなしで、デフォルト1日で即追加！
      _tempDestinations.add(TripDestination(
        name: result.name,
        country: result.country,
        countryCode: result.countryCode,
        state: result.state,
        latitude: result.location.latitude,
        longitude: result.location.longitude,
        stayDays: 1, // デフォルト1日
      ));
    });
  }

  void _saveTrip() {
    if (_tempDestinations.isEmpty) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    int totalDays = 0;
    for (var d in _tempDestinations) {
      totalDays += (d.stayDays ?? 1);
    }

    final startDate = DateTime(2000, 1, 1);
    final endDate = startDate.add(Duration(days: totalDays - 1));

    final newTrip = Trip(
      id: '',
      // タイトル未入力なら、先頭の場所名を使う
      title: _titleController.text.isNotEmpty 
          ? _titleController.text 
          : "Past: ${_tempDestinations.first.name}",
      startDate: startDate,
      endDate: endDate,
      ownerId: userId,
      memberIds: [userId],
      createdAt: DateTime.now(),
      destinations: _tempDestinations,
      tags: ['past_trip'],
    );

    context.read<TripCubit>().addTrip(newTrip);
    
    setState(() {
      _isAdding = false;
      _tempDestinations = [];
      _titleController.text = 'Past Trip';
    });

    TrippleToast.show(context, "Trip logged successfully!");
  }

  void _confirmDelete(Trip trip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Log?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<TripCubit>().deleteTrip(trip.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}