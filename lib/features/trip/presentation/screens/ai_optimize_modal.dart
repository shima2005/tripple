import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/shared/widgets/tripple_empty_state.dart';
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';

class AIOptimizeModal extends StatefulWidget {
  final Trip trip;

  const AIOptimizeModal({super.key, required this.trip});

  @override
  State<AIOptimizeModal> createState() => _AIOptimizeModalState();
}

class _AIOptimizeModalState extends State<AIOptimizeModal> {
  int _selectedDayIndex = 0;
  bool _isLoading = false;
  final Set<String> _lockedItemIds = {};
  List<ScheduledItem>? _previewItems;

  List<ScheduledItem> get _originalItems => context.read<TripCubit>().state.scheduleItems
      .whereType<ScheduledItem>()
      .where((i) => i.dayIndex == _selectedDayIndex)
      .toList();

  @override
  void initState() {
    super.initState();
    _updateLockedItemsForDay(0);
  }

  void _updateLockedItemsForDay(int dayIndex) {
    _lockedItemIds.clear();
    final items = context.read<TripCubit>().state.scheduleItems
        .whereType<ScheduledItem>()
        .where((i) => i.dayIndex == dayIndex)
        .toList();
    for (var item in items) {
      if (item.isTimeFixed) _lockedItemIds.add(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPreview = _previewItems != null;

    // 👇 TrippleModalScaffoldへ移行
    return TrippleModalScaffold(
      // タイトル切り替え
      title: isPreview ? 'Preview Changes' : 'AI Optimizer',
      icon: isPreview ? Icons.check_circle_outline_rounded : Icons.auto_awesome,
      // ローディング中はこのアイコンを使う
      extraHeaderActions: _isLoading ? [const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))] : null,
      
      heightRatio: TrippleModalSize.highRatio,
      isScrollable: false, // リストメインなのでfalse

      // プレビュー時のみ保存ボタンを表示
      onSave: isPreview ? _applyChanges : null,
      saveLabel: 'Apply Changes',
      isLoading: _isLoading,

      child: _isLoading 
        // ローディング表示
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'AI is calculating the best route...\nSolving the puzzle 🧩', 
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        : (isPreview ? _buildPreviewScreen() : _buildInputScreen()),
    );
  }

  // 1. 入力画面
  Widget _buildInputScreen() {
    final daysCount = widget.trip.endDate.difference(widget.trip.startDate).inDays + 1;
    final currentDayItems = context.watch<TripCubit>().state.scheduleItems
        .whereType<ScheduledItem>()
        .where((i) => i.dayIndex == _selectedDayIndex)
        .toList()..sort((a, b) => a.time.compareTo(b.time));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 日付選択
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
                onTap: () {
                  setState(() {
                    _selectedDayIndex = index;
                    _updateLockedItemsForDay(index);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: isSelected ? AppColors.accent : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300)),
                  alignment: Alignment.center,
                  child: Text('Day ${index + 1}', style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // 2. ロック設定
        Row(
          children: [
            Text('Lock Schedule', style: AppTextStyles.label),
            const SizedBox(width: 8),
            const Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text('Tap to lock time', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: currentDayItems.isEmpty
              ? Center(
                  child: TrippleEmptyState(
                    title: 'No Plans Yet',
                    message: 'This day is empty. Use "Suggest & Fill" to ask AI for spots!',
                    icon: Icons.calendar_today_rounded,
                    accentColor: Colors.grey,
                  ),
                )
              : Container(
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: currentDayItems.length,
                    separatorBuilder: (c, i) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final item = currentDayItems[index];
                      final isLocked = _lockedItemIds.contains(item.id);
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: isLocked ? AppColors.primary.withValues(alpha: 0.1) : Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: isLocked ? AppColors.primary : Colors.grey.shade300)),
                          child: Text(DateFormat('HH:mm').format(item.time), style: TextStyle(fontWeight: FontWeight.bold, color: isLocked ? AppColors.primary : Colors.grey, fontSize: 12)),
                        ),
                        title: Text(item.name, style: AppTextStyles.bodyMedium),
                        trailing: IconButton(
                          icon: Icon(isLocked ? Icons.lock_rounded : Icons.lock_open_rounded, color: isLocked ? AppColors.primary : Colors.grey, size: 20),
                          onPressed: () => setState(() => isLocked ? _lockedItemIds.remove(item.id) : _lockedItemIds.add(item.id)),
                        ),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 24),

        // 3. アクション
        Text('Optimize Action', style: AppTextStyles.label),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ActionCard(icon: Icons.sort_rounded, title: 'Reorder Only', subtitle: 'Efficient Route', color: AppColors.primary, onTap: () => _executeSimulation(allowSuggestions: false))),
            const SizedBox(width: 12),
            Expanded(child: _ActionCard(icon: Icons.add_location_alt_rounded, title: 'Suggest & Fill', subtitle: 'Fill empty gaps', color: AppColors.accent, onTap: () => _executeSimulation(allowSuggestions: true))),
          ],
        ),
      ],
    );
  }

  // 2. プレビュー画面
  Widget _buildPreviewScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review the changes before applying.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        
        Expanded(
          child: ListView.separated(
            itemCount: _previewItems!.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final newItem = _previewItems![index];
              ScheduledItem? oldItem;
              if (newItem.id.isNotEmpty) {
                try { oldItem = _originalItems.firstWhere((o) => o.id == newItem.id); } catch (_) {}
              }
              final isNew = oldItem == null;
              final isTimeChanged = oldItem != null && (oldItem.time.hour != newItem.time.hour || oldItem.time.minute != newItem.time.minute);

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(color: isNew ? AppColors.accent.withValues(alpha: 0.05) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (isTimeChanged) ...[Text(DateFormat('HH:mm').format(oldItem.time), style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.lineThrough)), const Icon(Icons.arrow_downward_rounded, size: 12, color: AppColors.primary)],
                        Text(DateFormat('HH:mm').format(newItem.time), style: TextStyle(fontWeight: FontWeight.bold, color: isTimeChanged ? AppColors.primary : AppColors.textPrimary, fontSize: 14)),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text(newItem.name, style: const TextStyle(fontWeight: FontWeight.bold))), if (isNew) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)), child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))]),
                      if (newItem.notes != null && newItem.notes!.isNotEmpty) Text(newItem.notes!, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // キャンセルボタンだけここに。保存ボタンはScaffoldのフッターへ
        SizedBox(width: double.infinity, child: TextButton(onPressed: () => setState(() => _previewItems = null), child: const Text('Edit / Cancel', style: TextStyle(color: Colors.grey)))),
      ],
    );
  }

  // ----------------------------------------------------------------
  // ロジック
  // ----------------------------------------------------------------

  // 1. シミュレーション実行
  void _executeSimulation({required bool allowSuggestions}) async {
    setState(() => _isLoading = true);
    try {
      final date = widget.trip.startDate.add(Duration(days: _selectedDayIndex));
      
      // Cubitのシミュレーションメソッドを呼ぶ
      final result = await context.read<TripCubit>().simulateAutoSchedule(
        dayIndex: _selectedDayIndex,
        date: date,
        allowSuggestions: allowSuggestions,
        lockedItemIds: _lockedItemIds,
      );

      if (mounted) {
        setState(() {
          _previewItems = result; // 結果をセットしてプレビュー画面へ
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

  // 2. 保存実行
  void _applyChanges() async {
    if (_previewItems == null) return;
    setState(() => _isLoading = true);

    try {
      await context.read<TripCubit>().saveOptimizedSchedule(
        tripId: widget.trip.id,
        dayIndex: _selectedDayIndex,
        optimizedItems: _previewItems!,
      );
      
      if (mounted) {
        Navigator.pop(context); // モーダル閉じる
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule updated! ✨')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }
}

// ----------------------------------------------------------------
// ヘルパーウィジェット
// ----------------------------------------------------------------
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}