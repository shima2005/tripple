// lib/features/trip/presentation/screens/expense_edit_modal.dart

import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/models/enums.dart';
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';
import 'package:new_tripple/shared/widgets/tripple_toast.dart';
import 'package:uuid/uuid.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/data/trip_repository.dart'; // SplitModeのために必要
import 'package:new_tripple/models/expense_item.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';
import 'package:new_tripple/shared/widgets/modal_header.dart';

class ExpenseEditModal extends StatefulWidget {
  final Trip trip;
  final ExpenseItem? expense;
  final String? linkedScheduleId;
  final double? initialAmount;
  final String? initialTitle;

  const ExpenseEditModal({
    super.key,
    required this.trip,
    this.expense,
    this.linkedScheduleId,
    this.initialAmount,
    this.initialTitle,
  });

  @override
  State<ExpenseEditModal> createState() => _ExpenseEditModalState();
}

class _ExpenseEditModalState extends State<ExpenseEditModal> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _amountController; 
  late TextEditingController _perPersonAmountController; 

  String _currency = 'JPY';
  String _payerId = '';
  List<String> _payeeIds = [];
  SplitMode _splitMode = SplitMode.equal;
  
  Map<String, double> _customAmounts = {};
  DateTime _date = DateTime.now();
  String _category = 'food';
  
  String? _linkedScheduleId;
  String? _linkedScheduleName;

  List<Map<String, String>> _allMembers = [];
  final _categories = ['food', 'transport', 'hotel', 'ticket', 'shopping', 'other'];

  @override
  void initState() {
    super.initState();
    _refreshMembersList();

    final e = widget.expense;
    
    _linkedScheduleId = e?.linkedScheduleId ?? widget.linkedScheduleId;
    _titleController = TextEditingController(text: e?.title ?? widget.initialTitle ?? '');
    
    double initialTotal = e?.amount ?? widget.initialAmount ?? 0;
    _amountController = TextEditingController(text: initialTotal == 0 ? '' : initialTotal.toStringAsFixed(0));
    
    double perPersonVal = 0;
    if (e?.splitMode == SplitMode.share && e!.payeeIds.isNotEmpty) {
      perPersonVal = e.amount / e.payeeIds.length;
    }
    _perPersonAmountController = TextEditingController(
      text: perPersonVal > 0 ? perPersonVal.toStringAsFixed(0) : ''
    );

    _currency = e?.currency ?? 'JPY';
    _payerId = e?.payerId ?? (widget.trip.ownerId);
    _payeeIds = e != null ? List.from(e.payeeIds) : _allMembers.map((m) => m['id']!).toList();
    _splitMode = e?.splitMode ?? SplitMode.equal;
    _customAmounts = e?.customAmounts ?? {};
    _date = e?.date ?? DateTime.now();
    _category = e?.category ?? 'food';

    if (_linkedScheduleId != null) {
      _fetchLinkedScheduleName();
    }
  }

  void _refreshMembersList() {
    setState(() {
      _allMembers = [
        ...widget.trip.memberIds?.map((id) => {'id': id, 'name': 'Member'}) ?? [], 
        ...widget.trip.guests.map((g) => {'id': g.id, 'name': g.name}),
      ];
    });
  }

  Future<void> _fetchLinkedScheduleName() async {
    // Repositoryメソッドはインスタンス化が必要な場合があります。必要に応じて修正してください。
    // ここでは簡易的に直呼び出しの想定です。
    final items = await TripRepository().fetchFullSchedule(widget.trip.id);
    final match = items.whereType<ScheduledItem>().firstWhere((i) => i.id == _linkedScheduleId, orElse: () => ScheduledItem(id: '', dayIndex: 0, time: DateTime.now(), name: 'Unknown', category: ItemCategory.other));
    if (match.id.isNotEmpty) {
      setState(() {
        _linkedScheduleName = match.name;
      });
    }
  }

  void _onSplitModeChanged(SplitMode? newMode) {
    if (newMode == null) return;
    
    setState(() {
      final oldMode = _splitMode;
      _splitMode = newMode;

      if (oldMode == SplitMode.equal && newMode == SplitMode.share) {
        if (_amountController.text.isNotEmpty) {
          _perPersonAmountController.text = _amountController.text;
          _updateTotalFromPerPerson();
        }
      }
      else if (newMode == SplitMode.custom) {
        _updateTotalFromCustomAmounts(); 
      }
    });
  }

  void _updateTotalFromPerPerson() {
    double perPerson = double.tryParse(_perPersonAmountController.text) ?? 0;
    int count = _payeeIds.isEmpty ? 1 : _payeeIds.length;
    double total = perPerson * count;
    _amountController.text = total == 0 ? '' : total.toStringAsFixed(0);
  }

  void _updateTotalFromCustomAmounts() {
    double total = 0;
    for (var id in _payeeIds) {
      total += _customAmounts[id] ?? 0;
    }
    _amountController.text = total == 0 ? '' : total.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    // 👇 TrippleModalScaffoldへ移行
    return TrippleModalScaffold(
      title: widget.expense == null ? 'New Expense' : 'Edit Expense',
      heightRatio: TrippleModalSize.highRatio,
      
      onSave: _save,
      saveLabel: 'Save Expense',

      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPlanLinkButton(),
            const SizedBox(height: 16),

            TrippleTextField(
              controller: _titleController,
              label: 'Title',
              hintText: 'Dinner, Taxi, etc.',
              validator: (v) => v!.isEmpty ? 'Please enter title' : null,
            ),
            const SizedBox(height: 24),

            _buildAmountSection(),
            const SizedBox(height: 24),

            Text('Category', style: AppTextStyles.label),
            const SizedBox(height: 12),
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _categories.map((cat) {
                    return TrippleSelectionChip(
                      label: cat[0].toUpperCase() + cat.substring(1),
                      icon: _getCategoryIcon(cat),
                      isSelected: _category == cat,
                      onTap: () => setState(() => _category = cat),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payer', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _allMembers.any((m) => m['id'] == _payerId) ? _payerId : null,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            items: _allMembers.map((m) {
                              return DropdownMenuItem(
                                value: m['id'],
                                child: Text(m['name'] ?? 'Unknown', style: AppTextStyles.bodyLarge),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _payerId = v!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context, 
                        initialDate: _date, 
                        firstDate: DateTime(2000), 
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.primary, 
                                onPrimary: Colors.white, 
                                onSurface: AppColors.textPrimary, 
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary, 
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if(d != null) setState(() => _date = d);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date', style: AppTextStyles.label),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(DateFormat('MM/dd').format(_date), style: AppTextStyles.bodyLarge),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 48),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Split With', style: AppTextStyles.h3),
                DropdownButton<SplitMode>(
                  value: _splitMode,
                  underline: Container(),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primary),
                  icon: const Icon(Icons.tune, color: AppColors.primary, size: 20),
                  onChanged: _onSplitModeChanged, 
                  items: const [
                    DropdownMenuItem(value: SplitMode.equal, child: Text('Equal Split')),
                    DropdownMenuItem(value: SplitMode.share, child: Text('Per Person (Fixed)')),
                    DropdownMenuItem(value: SplitMode.custom, child: Text('Custom Amount')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            ..._allMembers.map((member) {
              final id = member['id']!;
              final isSelected = _payeeIds.contains(id);
              
              String amountStr = '';
              
              if (isSelected) {
                if (_splitMode == SplitMode.equal) {
                  double currentTotal = double.tryParse(_amountController.text) ?? 0;
                  amountStr = (currentTotal / (_payeeIds.isEmpty ? 1 : _payeeIds.length)).toStringAsFixed(0);
                } else if (_splitMode == SplitMode.share) {
                   amountStr = _perPersonAmountController.text;
                } else {
                  amountStr = (_customAmounts[id] ?? 0).toStringAsFixed(0);
                }
              }

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _payeeIds.remove(id);
                    } else {
                      _payeeIds.add(id);
                    }
                    if (_splitMode == SplitMode.share) {
                      _updateTotalFromPerPerson();
                    } else if (_splitMode == SplitMode.custom) {
                      _updateTotalFromCustomAmounts();
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(member['name']!, style: AppTextStyles.bodyLarge)),
                      
                      if (isSelected && (_splitMode == SplitMode.equal || _splitMode == SplitMode.share))
                        Text('$amountStr $_currency', style: AppTextStyles.bodyMedium),
                      
                      if (isSelected && _splitMode == SplitMode.custom)
                        SizedBox(
                          width: 100,
                          height: 48,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.end,
                            decoration: InputDecoration(
                              hintText: '0',
                              filled: true,
                              fillColor: AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            controller: TextEditingController(text: (_customAmounts[id] ?? 0) == 0 ? '' : (_customAmounts[id] ?? 0).toStringAsFixed(0))
                              ..selection = TextSelection.fromPosition(TextPosition(offset: ((_customAmounts[id] ?? 0) == 0 ? '' : (_customAmounts[id] ?? 0).toStringAsFixed(0)).length)),
                            onChanged: (val) {
                               setState(() {
                                 _customAmounts[id] = double.tryParse(val) ?? 0;
                                 _updateTotalFromCustomAmounts();
                               });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: TextButton.icon(
                onPressed: _showAddGuestDialog,
                icon: const Icon(Icons.person_add, color: AppColors.primary),
                label: Text('Add Guest', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primary)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanLinkButton() {
    return GestureDetector(
      onTap: _showSelectPlanModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _linkedScheduleId != null ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _linkedScheduleId != null ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month,
              color: _linkedScheduleId != null ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _linkedScheduleId != null ? 'Linked to Plan' : 'Link to Plan (Optional)',
                    style: AppTextStyles.label.copyWith(
                      color: _linkedScheduleId != null ? AppColors.primary : Colors.grey,
                    ),
                  ),
                  if (_linkedScheduleName != null)
                    Text(
                      _linkedScheduleName!,
                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (_linkedScheduleId != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _linkedScheduleId = null;
                    _linkedScheduleName = null;
                  });
                },
              )
            else
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSection() {
    if (_splitMode == SplitMode.share) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TrippleTextField(
              controller: _perPersonAmountController, 
              label: 'Amount (Per Person)',
              hintText: '1000',
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onChanged: (_) => setState(() {
                _updateTotalFromPerPerson();
              }),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _buildCurrencyDropdown(),
          ),
        ],
      );
    } 
    else if (_splitMode == SplitMode.custom) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: AbsorbPointer( 
              child: TrippleTextField(
                controller: _amountController, 
                label: 'Total Amount (Auto)', 
                hintText: '0',
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _buildCurrencyDropdown(),
          ),
        ],
      );
    }
    else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TrippleTextField(
              controller: _amountController, 
              label: 'Total Amount',
              hintText: '0',
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _buildCurrencyDropdown(),
          ),
        ],
      );
    }
  }

  Widget _buildCurrencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Currency', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currency,
              isExpanded: true,
              // 🎨 Dropdown背景色統一
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              items: ['JPY', 'USD', 'EUR', 'KRW'].map((c) {
                return DropdownMenuItem(value: c, child: Text(c, style: AppTextStyles.bodyLarge));
              }).toList(),
              onChanged: (v) => setState(() => _currency = v!),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showSelectPlanModal() async {
    final allItems = await TripRepository().fetchFullSchedule(widget.trip.id);
    final plans = allItems.whereType<ScheduledItem>().toList();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: TrippleModalHeader(title: 'Select Plan'),
            ),
            Expanded(
              child: plans.isEmpty
                ? Center(child: Text('No plans found.', style: AppTextStyles.bodyMedium))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: plans.length,
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      final costStr = plan.cost != null ? ' (Planned: ${plan.cost})' : '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Icon(Icons.event, color: AppColors.primary, size: 20),
                        ),
                        title: Text(plan.name, style: AppTextStyles.bodyLarge),
                        subtitle: Text(
                          'Day ${plan.dayIndex + 1} - ${DateFormat('HH:mm').format(plan.time)}$costStr',
                          style: AppTextStyles.bodyMedium,
                        ),
                        onTap: () {
                          setState(() {
                            _linkedScheduleId = plan.id;
                            _linkedScheduleName = plan.name;
                            
                            if (_titleController.text.isEmpty) {
                              _titleController.text = plan.name;
                            }
                            
                            if (_amountController.text.isEmpty && plan.cost != null) {
                              _amountController.text = plan.cost!.toStringAsFixed(0);
                              
                              if (_splitMode == SplitMode.share) {
                                _perPersonAmountController.text = plan.cost!.toStringAsFixed(0);
                                _updateTotalFromPerPerson();
                              }
                            }
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddGuestDialog() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // 🎨 Dialog背景色・形統一
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Guest', style: AppTextStyles.h3),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: 'Guest Name',
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel', style: TextStyle(color: Colors.grey))
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final newGuest = TripGuest(id: const Uuid().v4(), name: name);
                await TripRepository().addGuestToTrip(widget.trip.id, newGuest);
                widget.trip.guests.add(newGuest); 
                _refreshMembersList();
                setState(() {
                  _payeeIds.add(newGuest.id);
                  if (_splitMode == SplitMode.share) {
                    _updateTotalFromPerPerson();
                  } else if (_splitMode == SplitMode.custom) {
                    _updateTotalFromCustomAmounts();
                  }
                });
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_payeeIds.isEmpty) {
      TrippleToast.show(context, 'Please select at least one person.', isError: true);
      return;
    }

    final newExpense = ExpenseItem(
      id: widget.expense?.id ?? '', 
      title: _titleController.text,
      amount: double.parse(_amountController.text),
      currency: _currency,
      payerId: _payerId,
      payeeIds: _payeeIds,
      splitMode: _splitMode,
      customAmounts: _splitMode == SplitMode.custom ? _customAmounts : null,
      date: _date,
      category: _category,
      linkedScheduleId: _linkedScheduleId,
    );

    // Cubit経由で保存 (リスト即時更新のため)
    context.read<TripCubit>().addOrUpdateExpense(widget.trip.id, newExpense);

    if (mounted) Navigator.pop(context);
  }
}