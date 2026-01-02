import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';
import 'package:new_tripple/models/enums.dart';
import 'package:url_launcher/url_launcher.dart';
// 👇 TrippleModalScaffold
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';

class AISuggestSpotModal extends StatefulWidget {
  final Trip trip;
  const AISuggestSpotModal({super.key, required this.trip});

  @override
  State<AISuggestSpotModal> createState() => _AISuggestSpotModalState();
}

class _AISuggestSpotModalState extends State<AISuggestSpotModal> {
  int _selectedDayIndex = 0;
  int _count = 3;
  final TextEditingController _requestController = TextEditingController();
  
  bool _isLoading = false;
  List<ScheduledItem>? _suggestions;

  @override
  Widget build(BuildContext context) {
    final isResult = _suggestions != null;

    // 👇 TrippleModalScaffoldへ移行
    return TrippleModalScaffold(
      // タイトル切り替え
      title: isResult ? 'AI Suggestions' : 'Suggest Next Spot',
      icon: isResult ? Icons.auto_awesome : Icons.lightbulb_outline_rounded,
      
      heightRatio: TrippleModalSize.mediumRatio, // ちょうどいいサイズ
      
      // 入力画面はフォームなのでスクロール可、結果画面はリストなのでスクロール不可(Expanded)
      isScrollable: !isResult,

      // アクションボタン (入力時のみAsk AIボタンを表示)
      onSave: !isResult ? _getSuggestions : null,
      saveLabel: 'Ask AI 🤖',
      isLoading: _isLoading,

      child: _isLoading 
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.accent),
                const SizedBox(height: 24),
                Text('Asking AI for recommendations... 🍜', style: AppTextStyles.bodyLarge),
              ],
            ),
          )
        : (isResult ? _buildResultScreen() : _buildInputScreen()),
    );
  }

  // 1. 入力画面
  Widget _buildInputScreen() {
    final daysCount = widget.trip.endDate.difference(widget.trip.startDate).inDays + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日付選択
        Text('Select Day', style: AppTextStyles.label),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: daysCount,
            separatorBuilder: (c, i) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = index == _selectedDayIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: isSelected ? AppColors.accent : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300)),
                  child: Text('Day ${index + 1}', style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // 個数選択
        Text('How many suggestions?', style: AppTextStyles.label),
        const SizedBox(height: 12),
        Row(
          children: [1, 3, 5].map((c) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text('$c spots'),
              selected: _count == c,
              onSelected: (val) => setState(() => _count = c),
              selectedColor: AppColors.accent.withValues(alpha: 0.2),
            ),
          )).toList(),
        ),
        const SizedBox(height: 24),

        // 要望入力
        Text('What are you looking for?', style: AppTextStyles.label),
        const SizedBox(height: 8),
        TrippleTextField(
          controller: _requestController,
          hintText: 'e.g. Quiet cafe with wifi, Spicy Ramen, Historical temple...',
          maxLines: 3,
        ),
        // ボタンはScaffoldへ移動
      ],
    );
  }

  // 2. 結果画面
  Widget _buildResultScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tap to add to your schedule.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        
        Expanded(
          child: ListView.separated(
            itemCount: _suggestions!.length,
            separatorBuilder: (c, i) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = _suggestions![index];
              return GestureDetector(
                onTap: () => _addSpot(item),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(item.category.icon, color: AppColors.accent, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Text('${item.durationMinutes} min', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(item.notes ?? '', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(onPressed: () => _openGoogleMaps(item.name), icon: const Icon(Icons.map_outlined, size: 18, color: Colors.grey), label: const Text('Check Map', style: TextStyle(color: Colors.grey))),
                          const SizedBox(width: 8),
                          TextButton.icon(onPressed: () => _addSpot(item), icon: const Icon(Icons.add_circle_outline_rounded, size: 18), label: const Text('Add to Schedule'), style: TextButton.styleFrom(foregroundColor: AppColors.accent)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => setState(() => _suggestions = null), 
            child: const Text('Ask Again / Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ),
      ],
    );
  }

  void _getSuggestions() async {
    if (_requestController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your request.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final results = await context.read<TripCubit>().fetchSpotSuggestions(
        dayIndex: _selectedDayIndex,
        userRequest: _requestController.text,
        count: _count,
      );
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _addSpot(ScheduledItem item) async {
    setState(() => _isLoading = true);
    try {
      await context.read<TripCubit>().addSuggestedSpot(
        tripId: widget.trip.id,
        dayIndex: _selectedDayIndex,
        suggestedItem: item,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} added!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
  Future<void> _openGoogleMaps(String query) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

}