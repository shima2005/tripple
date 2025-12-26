import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';

class AIOptimizeModal extends StatefulWidget {
  final Trip trip;

  const AIOptimizeModal({super.key, required this.trip});

  @override
  State<AIOptimizeModal> createState() => _AIOptimizeModalState();
}

class _AIOptimizeModalState extends State<AIOptimizeModal> {
  int _selectedDayIndex = 0;
  bool _isLoading = false;
  
  // ロックされたアイテムIDのセット
  final Set<String> _lockedItemIds = {};

  // プレビュー用のデータ (nullなら入力画面、入っていればプレビュー画面)
  List<ScheduledItem>? _previewItems;

  // 比較用：現在の選択中の日のアイテムリスト（変更前）
  List<ScheduledItem> get _originalItems => context.read<TripCubit>().state.scheduleItems
      .whereType<ScheduledItem>()
      .where((i) => i.dayIndex == _selectedDayIndex)
      .toList();

  @override
  void initState() {
    super.initState();
    // 初期化時に、元々固定されているアイテムをロックリストに入れておく
    _updateLockedItemsForDay(0);
  }

  void _updateLockedItemsForDay(int dayIndex) {
    _lockedItemIds.clear();
    final items = context.read<TripCubit>().state.scheduleItems
        .whereType<ScheduledItem>()
        .where((i) => i.dayIndex == dayIndex)
        .toList();
    
    for (var item in items) {
      if (item.isTimeFixed) {
        _lockedItemIds.add(item.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ローディング画面
    if (_isLoading) {
      return Container(
        height: 400,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'AI is calculating the best route...\nSolving the puzzle 🧩', 
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // プレビュー画面
    if (_previewItems != null) {
      return _buildPreviewScreen();
    }

    // 入力画面
    return _buildInputScreen();
  }

  // ----------------------------------------------------------------
  // 1. 入力画面 (設定・ロック選択)
  // ----------------------------------------------------------------
  Widget _buildInputScreen() {
    final daysCount = widget.trip.endDate.difference(widget.trip.startDate).inDays + 1;
    
    // 現在選択中の日のアイテムリストを取得
    final currentDayItems = context.watch<TripCubit>().state.scheduleItems
        .whereType<ScheduledItem>()
        .where((i) => i.dayIndex == _selectedDayIndex)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome, color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Text('AI Optimizer', style: AppTextStyles.h2),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 24),

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
                      _updateLockedItemsForDay(index); // ロック状態をリセット・更新
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.grey.shade300,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Day ${index + 1}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                    child: Text(
                      'No plans for this day yet.\nAI can suggest spots!',
                      style: TextStyle(color: Colors.grey[400]),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
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
                            decoration: BoxDecoration(
                              color: isLocked ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isLocked ? AppColors.primary : Colors.grey.shade300),
                            ),
                            child: Text(
                              DateFormat('HH:mm').format(item.time),
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: isLocked ? AppColors.primary : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(item.name, style: AppTextStyles.bodyMedium),
                          trailing: IconButton(
                            icon: Icon(
                              isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                              color: isLocked ? AppColors.primary : Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                if (isLocked) {
                                  _lockedItemIds.remove(item.id);
                                } else {
                                  _lockedItemIds.add(item.id);
                                }
                              });
                            },
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
              Expanded(
                child: _ActionCard(
                  icon: Icons.sort_rounded,
                  title: 'Reorder Only',
                  subtitle: 'Efficient Route',
                  color: AppColors.primary,
                  onTap: () => _executeSimulation(allowSuggestions: false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.add_location_alt_rounded,
                  title: 'Suggest & Fill',
                  subtitle: 'Fill empty gaps',
                  color: AppColors.accent,
                  onTap: () => _executeSimulation(allowSuggestions: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // 2. プレビュー画面 (変更確認)
  // ----------------------------------------------------------------
  Widget _buildPreviewScreen() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text('Preview Changes', style: AppTextStyles.h2),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Review the changes before applying.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView.separated(
              itemCount: _previewItems!.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final newItem = _previewItems![index];
                
                // 変更点の検出 (IDで旧アイテムを探す)
                ScheduledItem? oldItem;
                if (newItem.id.isNotEmpty) {
                  try {
                    oldItem = _originalItems.firstWhere((o) => o.id == newItem.id);
                  } catch (_) {}
                }

                final isNew = oldItem == null;
                // 時間が変わったか (分単位で比較)
                final isTimeChanged = oldItem != null && 
                    (oldItem.time.hour != newItem.time.hour || oldItem.time.minute != newItem.time.minute);

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isNew ? AppColors.accent.withValues(alpha: 0.05) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // 時間表示
                      SizedBox(
                        width: 60,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isTimeChanged) ...[
                              Text(
                                DateFormat('HH:mm').format(oldItem.time),
                                style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.lineThrough),
                              ),
                              const Icon(Icons.arrow_downward_rounded, size: 12, color: AppColors.primary),
                            ],
                            Text(
                              DateFormat('HH:mm').format(newItem.time),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isTimeChanged ? AppColors.primary : AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // 内容
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(newItem.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                if (isNew)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            if (newItem.notes != null && newItem.notes!.isNotEmpty)
                              Text(newItem.notes!, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // アクションボタン
          Row(
            children: [
              TextButton(
                onPressed: () {
                  // キャンセル -> 入力画面に戻る
                  setState(() => _previewItems = null);
                },
                child: const Text('Edit / Cancel', style: TextStyle(color: Colors.grey)),
              ),
              const Spacer(),
              Expanded(
                child: TripplePrimaryButton(
                  text: 'Apply Changes',
                  onPressed: _applyChanges, // 保存実行！
                ),
              ),
            ],
          ),
        ],
      ),
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