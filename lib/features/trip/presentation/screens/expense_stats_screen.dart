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
import 'expense_edit_modal.dart';
import 'dart:math';

class ExpenseStatsScreen extends StatefulWidget {
  final Trip trip;
  const ExpenseStatsScreen({super.key, required this.trip});

  @override
  State<ExpenseStatsScreen> createState() => _ExpenseStatsScreenState();
}

class _ExpenseStatsScreenState extends State<ExpenseStatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Expenses', style: AppTextStyles.h3),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'List'),
            Tab(text: 'Chart'),
            Tab(text: 'Settle'),
          ],
        ),
      ),
      // FutureBuilder ではなく BlocBuilder を使用
      body: BlocBuilder<TripCubit, TripState>(
        builder: (context, state) {
          // データ取得中、かつまだデータがない場合
          if (state.status == TripStatus.loading && state.expenses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = state.expenses;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildListTab(expenses),
              _buildChartTab(expenses),
              _buildSettlementTab(expenses),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          // await と setState が不要になる
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => ExpenseEditModal(trip: widget.trip),
          );
        },
      ),
    );
  }

  Widget _buildListTab(List<ExpenseItem> expenses) {
    if (expenses.isEmpty) {
      return Center(child: Text('No expenses yet.', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final e = expenses[index];
        return Card(
          elevation: 0,
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Icon(_getCategoryIcon(e.category), color: AppColors.primary),
            ),
            title: Text(e.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text('Paid by ${_getName(e.payerId)}', style: AppTextStyles.bodyMedium),
            trailing: Text(
              '${e.amount.toStringAsFixed(0)} ${e.currency}',
              style: AppTextStyles.h3.copyWith(fontSize: 16),
            ),
            onTap: () {
              // 編集モーダルを開く
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ExpenseEditModal(trip: widget.trip, expense: e),
              );
            },
            // スワイプ削除機能を追加するならここ
            onLongPress: () {
              _showDeleteConfirmDialog(e);
            },
          ),
        );
      },
    );
  }

  void _showDeleteConfirmDialog(ExpenseItem e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Delete "${e.title}"?'),
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

  Widget _buildChartTab(List<ExpenseItem> expenses) {
    // カテゴリごとの集計
    final dataMap = <String, double>{};
    for (var e in expenses) {
      dataMap[e.category] = (dataMap[e.category] ?? 0) + e.amount;
    }

    if (dataMap.isEmpty) {
      return Center(child: Text('No data available', style: AppTextStyles.bodyLarge));
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

  Widget _buildSettlementTab(List<ExpenseItem> expenses) {
    // 参加者IDリスト (メンバー + ゲスト)
    final List<String> allMemberIds = <String>[
      ...(widget.trip.memberIds ?? []),
      ...widget.trip.guests.map((g) => g.id),
    ];

    // ロジッククラスを使って計算
    final debtsMap = ExpenseCalculator.calculateDebts(expenses, allMemberIds);

    if (debtsMap.isEmpty) {
      return Center(child: Text('No settlements needed.', style: AppTextStyles.bodyLarge));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Who pays whom?', style: AppTextStyles.h3),
        const SizedBox(height: 16),
        ...debtsMap.entries.map((entry) {
          final currency = entry.key;
          final instructions = entry.value;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(currency, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
              ),
              if (instructions.isEmpty)
                 Padding(padding: const EdgeInsets.all(8), child: Text('All settled!', style: AppTextStyles.bodyMedium)),
              ...instructions.map((ins) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_getName(ins.fromUserId), style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                            Text('pays', style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: AppColors.textSecondary),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_getName(ins.toUserId), style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                            Text('receives', style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${ins.amount.toStringAsFixed(0)}',
                        style: AppTextStyles.h3.copyWith(color: AppColors.primary, fontSize: 18),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],
          );
        }),
      ],
    );
  }

  String _getName(String id) {
    // メンバーIDなら 'Member' (本来はUser Profile取得)、ゲストなら名前を表示
    // 簡易的にTrip内のゲストリストから検索
    try {
      final guest = widget.trip.guests.firstWhere((g) => g.id == id);
      return guest.name;
    } catch (_) {
      // ゲストにいなければメンバーIDとみなす
      // 本当はここで UserRepo から名前を引きたいが、同期的に返したいので簡易表示
      if (id == widget.trip.ownerId) return 'Owner';
      return 'Member'; // IDの先頭を表示などしてもよい
    }
  }
}