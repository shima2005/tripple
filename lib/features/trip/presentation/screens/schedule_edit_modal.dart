import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui'; // ScrollBehavior用
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/models/enums.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';
import 'package:new_tripple/features/trip/presentation/screens/place_search_modeal.dart';
import 'package:new_tripple/services/geocoding_service.dart';
import 'package:new_tripple/services/gemini_service.dart';
import 'package:new_tripple/shared/widgets/modal_header.dart';
import 'package:new_tripple/shared/widgets/scan_button.dart';
import 'package:image_picker/image_picker.dart';

class ScheduleEditModal extends StatefulWidget {
  final Trip trip;
  final ScheduledItem? item;
  final DateTime? initialDateTime;

  const ScheduleEditModal({super.key, required this.trip, this.item, this.initialDateTime});

  @override
  State<ScheduleEditModal> createState() => _ScheduleEditModalState();
}

class _ScheduleEditModalState extends State<ScheduleEditModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _costController;
  late TextEditingController _notesController;
  late TextEditingController _durationController;
  late TextEditingController _imageController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  ItemCategory _selectedCategory = ItemCategory.sightseeing;

  double? _latitude;
  double? _longitude;

  final _geminiService = GeminiService(); // インスタンス
  bool _isScanning = false; // ローディング用

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _costController = TextEditingController(text: widget.item?.cost?.toInt().toString() ?? '');
    _notesController = TextEditingController(text: widget.item?.notes ?? '');
    _durationController = TextEditingController(text: widget.item?.durationMinutes?.toString() ?? '60');
    _imageController = TextEditingController(text: widget.item?.imageUrl ?? '');

    _latitude = widget.item?.latitude;
    _longitude = widget.item?.longitude;

    if (widget.item != null) {
      // 編集モード: 既存のデータを使う
      _selectedDate = widget.item!.time;
      _selectedTime = TimeOfDay.fromDateTime(widget.item!.time);
      _selectedCategory = widget.item!.category;
    } else {
      // 新規作成モード: 
      // 👇 渡された initialDateTime があればそれを使う、なければ旅行開始日
      if (widget.initialDateTime != null) {
        _selectedDate = widget.initialDateTime!;
        _selectedTime = TimeOfDay.fromDateTime(widget.initialDateTime!);
      } else {
        // フォールバック (念のため)
        final now = DateTime.now();
        if (now.isAfter(widget.trip.startDate) && now.isBefore(widget.trip.endDate)) {
          _selectedDate = now;
        } else {
          _selectedDate = widget.trip.startDate;
        }
        _selectedTime = const TimeOfDay(hour: 10, minute: 0);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👇 修正: ヘッダー (スッキリ & オーバーフロー対策)
            TrippleModalHeader(
              title: widget.item == null ? 'Add Schedule' : 'Edit Schedule',
              actions: [
                if (_isScanning)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Transform.scale(
                    scale: 0.9,
                    child: ScanButton(
                      onImagePicked: (img) => _handleScan(image: img),
                      onTextPasted: (txt) => _handleScan(text: txt),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. カテゴリ選択 (共通チップ使用)
                    Text('Category', style: AppTextStyles.label),
                    const SizedBox(height: 12),
                    ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: ItemCategory.values.map((category) { 
                            return TrippleSelectionChip(
                              label: category.displayName,
                              icon: category.icon,
                              isSelected: _selectedCategory == category,
                              onTap: () => setState(() => _selectedCategory = category),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. 名前入力 & 場所検索
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end, // 下揃えにして、入力欄とボタンの底を合わせる
                      children: [
                        Expanded(
                          child: TrippleTextField(
                            controller: _nameController,
                            label: 'Spot Name',
                            hintText: 'Ex: 清水寺, ランチ',
                            // 👇 エンターキーで検索へ！
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                _openPlaceSearch(query: value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // 👇 ボタンの高さを合わせるハック
                        Column(
                          children: [
                            // 左のTextFieldのラベルと同じ高さの透明なテキストを置いて、高さを稼ぐ
                            Text(' ', style: AppTextStyles.label), 
                            const SizedBox(height: 8),
                            
                            // 検索ボタン
                            Container(
                              height: 56, // TextFieldの高さ(デフォルト)に合わせる
                              width: 56,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.map_rounded, color: AppColors.accent),
                                onPressed: () => _openPlaceSearch(query: _nameController.text),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),

                    // 3. 日時と滞在時間 (モダン一体型UI)
                    Row(
                      children: [
                        // 日時選択 (一体型コンテナ)
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date & Time', style: AppTextStyles.label),
                              const SizedBox(height: 8),
                              Container(
                                height: 56, // テキストフィールドと同じ高さに合わせる
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    // 日付エリア
                                    Expanded(
                                      flex: 3,
                                      child: GestureDetector(
                                        onTap: _pickDate,
                                        behavior: HitTestBehavior.opaque,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                DateFormat('MM/dd (E)').format(_selectedDate),
                                                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    // 区切り線
                                    Container(
                                      width: 1,
                                      height: 32,
                                      color: Colors.grey.shade300,
                                    ),

                                    // 時間エリア
                                    Expanded(
                                      flex: 2,
                                      child: GestureDetector(
                                        onTap: _pickTimeCupertino,
                                        behavior: HitTestBehavior.opaque,
                                        child: Center(
                                          child: Text(
                                            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // 滞在時間 (共通部品使用)
                        Expanded(
                          flex: 2,
                          child: TrippleTextField(
                            controller: _durationController,
                            label: 'Min',
                            hintText: '60',
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) => setState((){}),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        'Ends at: ${_calculateEndTime()}',
                        style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4. 費用 (共通部品使用)
                    TrippleTextField(
                      controller: _costController,
                      label: 'Cost (¥)',
                      hintText: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 24),

                    // 5. 画像URL (共通部品使用)
                    TrippleTextField(
                      controller: _imageController,
                      label: 'Image URL (Optional)',
                      hintText: 'https://...',
                    ),
                    const SizedBox(height: 24),

                    // 6. メモ (共通部品使用)
                    TrippleTextField(
                      controller: _notesController,
                      label: 'Notes',
                      hintText: 'Reservation details, memo...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            if (widget.item != null) ...[
              Center(
                child: TextButton.icon(
                  onPressed: _onDeletePressed,
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  label: Text(
                    'Delete Schedule',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 保存ボタン (共通部品使用)
            TripplePrimaryButton(
              text: widget.item == null ? 'Add to Itinerary' : 'Save the Schedule',
              onPressed: _saveItem,
            ),
          ],
        ),
      ),
    );
  }

  // 👇 スキャン処理
  Future<void> _handleScan({XFile? image, String? text}) async {
    setState(() => _isScanning = true);
    try {
      final data = await _geminiService.extractFromImageOrText(image: image, text: text);
      
      // データ反映
      setState(() {
        _nameController.text = data['title'] ?? '';
        _notesController.text = data['memo'] ?? '';
        
        // 日時
        if (data['start_time'] != null) {
          final start = DateTime.parse(data['start_time']);
          _selectedDate = start; // 内部のDateTime変数
          // TimeOfDayなどの更新も必要ならここで
        }
        
        
        // 場所 (Geocodingが必要ならここで検索かけるか、とりあえず名前にいれる)
        // 今回はとりあえずログ出し
        print("Location: ${data['location']}"); 
        
        // タイプ判定してカテゴリ切り替え
        if (data['type'] == 'transport') {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seems like a transport ticket. Consider using Route Edit!')));
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanned! Verify details.')));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    } finally {
      setState(() => _isScanning = false);
    }
  }

  // ... (メソッド群 _calculateEndTime, _pickDateTime, _pickDateCupertino, _pickTimeCupertino, _saveItem, _onDeletePressed, _executeDelete は変更なし)
  String _calculateEndTime() {
    final duration = int.tryParse(_durationController.text) ?? 0;
    final startDateTime = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );
    final endDateTime = startDateTime.add(Duration(minutes: duration));
    return DateFormat('HH:mm').format(endDateTime);
  }

  Future<void> _pickDate() async {
    final firstDate = widget.trip.startDate;
    final lastDate = widget.trip.endDate;
    
    // 現在の選択日が範囲外なら、範囲内に補正する
    final initialDate = _selectedDate.isBefore(firstDate) 
        ? firstDate 
        : (_selectedDate.isAfter(lastDate) ? lastDate : _selectedDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        // 全画面にならず、ポップアップのように表示する設定
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400.0,
              maxHeight: 500.0,
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary, // アプリのテーマカラーを適用
                  onPrimary: Colors.white,
                  onSurface: AppColors.textPrimary,
                ),
                dialogTheme: DialogThemeData(backgroundColor: Colors.white),
              ),
              child: child!,
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _pickTimeCupertino() {
    final initialDateTime = DateTime(2020, 1, 1, _selectedTime.hour, _selectedTime.minute);
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(
              height: 190,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: initialDateTime,
                onDateTimeChanged: (val) => setState(() => _selectedTime = TimeOfDay.fromDateTime(val)),
              ),
            ),
            CupertinoButton(child: const Text('Done'), onPressed: () => Navigator.pop(context))
          ],
        ),
      ),
    );
  }

  void _saveItem() {
    if (_formKey.currentState!.validate()) {
      final startDateTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );
      final tripStartDate = DateTime(widget.trip.startDate.year, widget.trip.startDate.month, widget.trip.startDate.day);
      final itemDate = DateTime(startDateTime.year, startDateTime.month, startDateTime.day);
      final dayIndex = itemDate.difference(tripStartDate).inDays;

      final newItem = ScheduledItem(
        id: widget.item?.id ?? '', 
        dayIndex: dayIndex, 
        time: startDateTime,
        name: _nameController.text,
        category: _selectedCategory,
        durationMinutes: int.tryParse(_durationController.text),
        cost: double.tryParse(_costController.text),
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        imageUrl: _imageController.text.isNotEmpty ? _imageController.text : null,
        latitude: _latitude,
        longitude: _longitude
      );
      context.read<TripCubit>().addOrUpdateScheduledItem(widget.trip.id, newItem);
      Navigator.pop(context);
    }
  }

  void _onDeletePressed() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule?'),
        content: const Text('This action will also recalculate travel routes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.pop(context); _executeDelete(); }, child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }

  void _executeDelete() {
    if (widget.item != null) {
      context.read<TripCubit>().deleteScheduledItem(widget.trip.id, widget.item!.id);
      Navigator.pop(context);
    }
  }

  //TODO: 検索モーダルを開く処理（一時的）
  Future<void> _openPlaceSearch({String? query}) async {
    final PlaceSearchResult? result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaceSearchModal(initialQuery: query), // クエリを渡す
    );

    if (result != null) {
      setState(() {
        // 名前が空なら、検索結果の名前で埋める
        if (_nameController.text.isEmpty) {
          _nameController.text = result.name;
        }
        _latitude = result.location.latitude;
        _longitude = result.location.longitude;
      });
    }
  }
}