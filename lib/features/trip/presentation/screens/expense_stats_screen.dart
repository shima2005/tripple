import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart'; 
import 'package:new_tripple/features/trip/domain/trip_state.dart'; 
import 'package:new_tripple/core/utils/debt_calculator.dart'; 
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/models/expense_item.dart';
import 'package:new_tripple/shared/widgets/tripple_empty_state.dart'; // 👈 追加
import 'expense_edit_modal.dart';
// 👇 統一ScaffoldとConstants
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';

class ExpenseStatsModal extends StatefulWidget { // Screen -> Modal に変更
  final Trip trip;
  const ExpenseStatsModal({super.key, required this.trip});

  @override
  State<ExpenseStatsModal> createState() => _ExpenseStatsModalState();
}

class _ExpenseStatsModalState extends State<ExpenseStatsModal> {
  // TabControllerは不要 (DefaultTabControllerを使うため)

  @override
  Widget build(BuildContext context) {
    // 👇 TrippleModalScaffoldへ移行
    return TrippleModalScaffold(
      title: 'Expenses',
      icon: Icons.attach_money_rounded,
      heightRatio: TrippleModalSize.highRatio, // コンテンツが多いのでHigh
      
      // TabBarを使うので、Scaffold自体のスクロールはOFF
      isScrollable: false,

      // ヘッダー右側に「追加ボタン」を配置 (FABの代わり)
      extraHeaderActions: [
        IconButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => ExpenseEditModal(trip: widget.trip),
            );
          },
          icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
          iconSize: 32, // 少し大きく
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
          ),
        ),
      ],

      // DefaultTabControllerでラップしてタブ管理
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            // 1. タブバー (Containerで囲ってデザイン調整)
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'List'),
                  Tab(text: 'Chart'),
                  Tab(text: 'Settle'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. タブの中身 (Expandedで埋める)
            Expanded(
              child: BlocBuilder<TripCubit, TripState>(
                builder: (context, state) {
                  // データ取得中かつデータなし
                  if (state.status == TripStatus.loading && state.expenses.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final expenses = state.expenses;

                  return TabBarView(
                    children: [
                      _buildListTab(expenses),
                      _buildChartTab(expenses),
                      _buildSettlementTab(expenses),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- List Tab ---
  Widget _buildListTab(List<ExpenseItem> expenses) {
    if (expenses.isEmpty) {
      // 統一したEmptyStateを使用
      return const Center(
        child: TrippleEmptyState(
          title: 'No Expenses Yet',
          message: 'Track your spending here.\nTap "+" to add a cost.',
          icon: Icons.receipt_long_rounded,
          accentColor: AppColors.primary,
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24), // 下部余白
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final e = expenses[index];
        return Card(
          elevation: 0,
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell( // タップエフェクト追加
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ExpenseEditModal(trip: widget.trip, expense: e),
              );
            },
            onLongPress: () => _showDeleteConfirmDialog(e),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(_getCategoryIcon(e.category), color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Paid by ${_getName(e.payerId)}', style: AppTextStyles.label.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text(
                    '${e.amount.toStringAsFixed(0)} ${e.currency}',
                    style: AppTextStyles.h3.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmDialog(ExpenseItem e) {
    // 統一したデザインのアラートなどは別途共通化しても良いですが、一旦既存のアラートを使用
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense?'),
        content: Text('Delete "${e.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<TripCubit>().deleteExpense(widget.trip.id, e.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'food': return Icons.restaurant;
      case 'transport': return Icons.directions_bus;
      case 'hotel': return Icons.hotel;
      case 'ticket': return Icons.confirmation_number;
      case 'shopping': return Icons.shopping_bag;
      default: return Icons.attach_money;
    }
  }

  // --- Chart Tab ---
  Widget _buildChartTab(List<ExpenseItem> expenses) {
    final dataMap = <String, double>{};
    for (var e in expenses) {
      dataMap[e.category] = (dataMap[e.category] ?? 0) + e.amount;
    }

    if (dataMap.isEmpty) {
      return const Center(
        child: TrippleEmptyState(
          title: 'No Data',
          message: 'Add expenses to see the breakdown.',
          icon: Icons.pie_chart_outline_rounded,
          accentColor: Colors.grey,
        ),
      );
    }

    final sections = dataMap.entries.map((e) {
      final color = Colors.primaries[e.key.hashCode % Colors.primaries.length];
      return PieChartSectionData(
        value: e.value,
        title: '${e.key}\n${e.value.toStringAsFixed(0)}',
        color: color,
        radius: 100,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Center(
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  // --- Settlement Tab ---
  Widget _buildSettlementTab(List<ExpenseItem> expenses) {
    final List<String> allMemberIds = <String>[
      ...(widget.trip.memberIds ?? []),
      ...widget.trip.guests.map((g) => g.id),
    ];

    final debtsMap = ExpenseCalculator.calculateDebts(expenses, allMemberIds);

    if (debtsMap.isEmpty) {
      return const Center(
        child: TrippleEmptyState(
          title: 'All Settled',
          message: 'No debts to settle. Perfect balance!',
          icon: Icons.check_circle_outline_rounded,
          accentColor: Colors.green,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Text('Who pays whom?', style: AppTextStyles.h3), // ModalHeaderがあるので不要かも
        // const SizedBox(height: 16),
        
        ...debtsMap.entries.map((entry) {
          final currency = entry.key;
          final instructions = entry.value;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(currency, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold, color: AppColors.accent)),
                ),
              ),
              if (instructions.isEmpty)
                 const Padding(padding: EdgeInsets.all(8), child: Text('All settled!')),
                 
              ...instructions.map((ins) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_getName(ins.fromUserId), style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                            const Text('pays', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_getName(ins.toUserId), style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                            const Text('receives', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        ins.amount.toStringAsFixed(0),
                        style: AppTextStyles.h3.copyWith(color: AppColors.primary, fontSize: 18),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          );
        }),
      ],
    );
  }

  String _getName(String id) {
    try {
      final guest = widget.trip.guests.firstWhere((g) => g.id == id);
      return guest.name;
    } catch (_) {
      if (id == widget.trip.ownerId) return 'Owner';
      // 実際にはUserProfileをキャッシュから引くか、IDを表示する
      // ここは既存ロジック通り
      return 'Member'; 
    }
  }
}