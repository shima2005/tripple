import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/features/trip/domain/trip_state.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';

class ChecklistModal extends StatefulWidget {
  const ChecklistModal({super.key});

  @override
  State<ChecklistModal> createState() => _ChecklistModalState();
}

class _ChecklistModalState extends State<ChecklistModal> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripCubit, TripState>(
      builder: (context, state) {
        final trip = state.selectedTrip;
        if (trip == null) return const SizedBox.shrink();

        final items = trip.checklist;
        final checkedCount = items.where((i) => i.isChecked).length;
        final progress = items.isEmpty ? 0.0 : checkedCount / items.length;

        return TrippleModalScaffold(
          title: 'Packing List',
          icon: Icons.checklist_rounded,
          heightRatio: TrippleModalSize.mediumRatio,
          
          // リスト自体をスクロールさせたいので、Scaffoldの親スクロールはOFF
          isScrollable: false,

          // ヘッダー右側に進捗を表示
          extraHeaderActions: [
             Center(
               child: Text(
                 '${(progress * 100).toInt()}%',
                 style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
               ),
             ),
             const SizedBox(width: 8),
             SizedBox(
               width: 20, height: 20,
               child: CircularProgressIndicator(
                 value: progress,
                 strokeWidth: 3,
                 backgroundColor: Colors.grey[200],
                 valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
               ),
             ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👇 修正: プリセットボタン (リストが空の時だけ表示)
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.read<TripCubit>().loadChecklistPreset(isInternational: false),
                          icon: const Icon(Icons.train_rounded, color: AppColors.primary),
                          label: const Text('Domestic'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.read<TripCubit>().loadChecklistPreset(isInternational: true),
                          icon: const Icon(Icons.flight_takeoff_rounded, color: AppColors.accent),
                          label: const Text('Overseas'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // List
              Expanded(
                child: items.isEmpty 
                  ? const Center(child: Text('No items yet.\nAdd manually or ask AI!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Dismissible(
                          key: Key(item.name),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red[100],
                            child: const Icon(Icons.delete, color: Colors.red),
                          ),
                          onDismissed: (_) {
                            context.read<TripCubit>().deleteCheckItem(item.name);
                          },
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                            title: Text(
                              item.name,
                              style: TextStyle(
                                decoration: item.isChecked ? TextDecoration.lineThrough : null,
                                color: item.isChecked ? Colors.grey : AppColors.textPrimary,
                              ),
                            ),
                            value: item.isChecked,
                            onChanged: (_) {
                              context.read<TripCubit>().toggleCheckItem(item.name);
                            },
                          ),
                        );
                      },
                    ),
              ),

              const SizedBox(height: 16),

              // Add Input
              Row(
                children: [
                  Expanded(
                    child: TrippleTextField(
                      controller: _controller,
                      hintText: 'Add new item...',
                      onSubmitted: (val) => _addItem(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 40),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _addItem() {
    if (_controller.text.isNotEmpty) {
      context.read<TripCubit>().addCheckItem(_controller.text);
      _controller.clear();
    }
  }
}