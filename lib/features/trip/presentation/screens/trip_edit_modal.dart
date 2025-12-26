import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/features/trip/presentation/screens/checklist_modal.dart';
import 'package:new_tripple/features/trip/presentation/screens/share_trip_modal.dart';
import 'package:new_tripple/models/enums.dart';
import 'package:new_tripple/models/trip.dart'; // TripDestinationもここにある前提
import 'package:new_tripple/shared/widgets/common_inputs.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/features/trip/presentation/screens/place_search_modeal.dart';
import 'package:new_tripple/services/geocoding_service.dart';
import 'package:new_tripple/services/storage_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:new_tripple/shared/widgets/modal_header.dart';

class TripEditModal extends StatefulWidget {
  final Trip? trip;

  const TripEditModal({super.key, this.trip});

  @override
  State<TripEditModal> createState() => _TripEditModalState();
}

class _TripEditModalState extends State<TripEditModal> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _imageController;
  late TextEditingController _tagInputController;
  late TransportType _mainTransportType;
  List<String> _tags = [];

  bool get _isEditing => widget.trip != null;
  
  List<TripDestination> _destinations = [];

  final _storageService = StorageService(); 
  bool _isUploading = false;
  
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.trip?.title ?? '');
    _imageController = TextEditingController(text: widget.trip?.coverImageUrl ?? '');
    _tags = List.from(widget.trip?.tags ?? []);
    _mainTransportType = (widget.trip != null) ? widget.trip!.mainTransport : TransportType.transit;
    
    // 既存の行き先があれば読み込む
    _destinations = List.from(widget.trip?.destinations ?? []);
    
    _tagInputController = TextEditingController();
    
    if (widget.trip != null) {
      _dateRange = DateTimeRange(start: widget.trip!.startDate, end: widget.trip!.endDate);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _imageController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
            // --- ヘッダー ---
            TrippleModalHeader(
              icon:widget.trip == null ? Icons.luggage_rounded : Icons.edit_location_alt_rounded,
              title: (_isEditing) ? 'Edit Trip' : 'New Trip',
            ),

            const SizedBox(height: 32),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. タイトル
                    TrippleTextField(
                      controller: _titleController,
                      label: 'Trip Title',
                      hintText: 'Ex: Eurotrip 2025',
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 24),

                    // Main Transport Method
                    Text('Main Transport', style: AppTextStyles.label),
                    const SizedBox(height: 12),
                    ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: TransportType.values.where((t) => t != TransportType.other).map((type) {
                            return TrippleSelectionChip(
                              label: type.displayName,
                              icon: type.icon,
                              isSelected: _mainTransportType == type,
                              onTap: () => setState(() => _mainTransportType = type),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24,),

                    // 👇 2. 行き先 (Destinations) - 日数選択付きにアップグレード！
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Destinations 📍', style: AppTextStyles.label),
                        TextButton.icon(
                          onPressed: _addDestination, 
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Place'),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    if (_destinations.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          'No destinations added yet.\nTap "Add Place" to search!',
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _destinations.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          // 👇 新しいUIビルダーを使用
                          return _buildDestinationItem(index, _destinations[index]);
                        },
                      ),
                    const SizedBox(height: 24),

                    // 3. 日程選択
                    Text('Date Range', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Text(
                              _dateRange == null
                                  ? 'Select dates'
                                  : '${DateFormat('yyyy/MM/dd').format(_dateRange!.start)} - ${DateFormat('MM/dd').format(_dateRange!.end)}',
                              style: _dateRange == null
                                  ? AppTextStyles.bodyMedium.copyWith(color: Colors.grey)
                                  : AppTextStyles.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4. 画像URL
                    Text('Cover Image', style: AppTextStyles.label),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                            image: _imageController.text.isNotEmpty
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(_imageController.text),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _isUploading
                              ? const Center(child: CircularProgressIndicator())
                              : _imageController.text.isEmpty
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_rounded, size: 48, color: Colors.grey[400]),
                                        const SizedBox(height: 8),
                                        Text('Tap to upload photo', style: TextStyle(color: Colors.grey[600])),
                                      ],
                                    )
                                  : Align(
                                      alignment: Alignment.topRight,
                                      child: IconButton(
                                        icon: const Icon(Icons.edit_rounded, color: Colors.white),
                                        style: IconButton.styleFrom(backgroundColor: Colors.black38),
                                        onPressed: _pickImage,
                                      ),
                                    ),
                        ),
                      ),
                    ),

                    // 5. Tags
                    Text('Tags', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    if (_tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags.map((tag) => Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TrippleTextField(
                      controller: _tagInputController,
                      hintText: 'Add a tag...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
                        onPressed: _addTag,
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                    
                    if (_isEditing) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.orange[100], shape: BoxShape.circle),
                          child: const Icon(Icons.backpack_rounded, color: Colors.orange),
                        ),
                        title: const Text('Packing List', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${widget.trip!.checklist.where((i) => i.isChecked).length} / ${widget.trip!.checklist.length} checked'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const ChecklistModal(),
                          );
                        },
                      ),
                      const Divider(),
                    ],
                  ],
                ),
              ),
            ),

            if (_isEditing) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ShareTripModal(trip: widget.trip!),
                    );
                  },
                  icon: const Icon(Icons.qr_code_rounded, color: AppColors.primary),
                  label: const Text('Invite Friends'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],

            if (_isEditing) ...[
              Center(
                child: TextButton.icon(
                  onPressed: _onDeletePressed,
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  label: Text(
                    'Delete Trip',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            TripplePrimaryButton(
              text: 'Save Trip',
              onPressed: _saveTrip,
            ),
          ],
        ),
      ),
    );
  }

  // 👇 行き先アイテム (日数調整ボタン付き)
  Widget _buildDestinationItem(int index, TripDestination dest) {
    final days = dest.stayDays ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.place_rounded, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          
          // 場所名 & 国名
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dest.name, style: AppTextStyles.bodyLarge.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
                if (dest.country != null)
                  Text(dest.country!, style: AppTextStyles.label.copyWith(color: Colors.grey)),
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
                         // Immutableモデルのため再生成
                         _destinations[index] = TripDestination(
                            name: dest.name, country: dest.country, countryCode: dest.countryCode,
                            state: dest.state, latitude: dest.latitude, longitude: dest.longitude,
                            stayDays: days - 1, // 👈 減らす
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
                       _destinations[index] = TripDestination(
                          name: dest.name, country: dest.country, countryCode: dest.countryCode,
                          state: dest.state, latitude: dest.latitude, longitude: dest.longitude,
                          stayDays: days + 1, // 👈 増やす
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
            onPressed: () => setState(() => _destinations.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Future<void> _addDestination() async {
    final PlaceSearchResult? result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlaceSearchModal(hintText: "e.g. Kyoto, France",),
    );

    if (result != null) {
      setState(() {
        _destinations.add(TripDestination(
          name: result.name,
          country: result.country,
          countryCode: result.countryCode,
          state: result.state,
          latitude: result.location.latitude,
          longitude: result.location.longitude,
          stayDays: 1, // 👈 追加時、デフォルト1日を設定
        ));
        
        // タイトルが空なら、場所名を入れてあげる親切設計
        if (_titleController.text.isEmpty) {
          _titleController.text = "${result.name} Trip";
        }
      });
    }
  }

  // ... ( _addTag, _pickDateRange, _onDeletePressed, _executeDelete, _saveTrip, _pickImage は変更なし )
  void _addTag() {
    final text = _tagInputController.text.trim();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text);
        _tagInputController.clear();
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDateRange: _dateRange,
      builder: (context, child) {
         return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white, onSurface: AppColors.textPrimary),
            ),
            child: child!,
         );
      },
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  void _onDeletePressed() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.pop(context); _executeDelete(); }, child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }

  void _executeDelete() {
    if (widget.trip != null) {
      context.read<TripCubit>().deleteTrip(widget.trip!.id);
      Navigator.pop(context, true);
    }
  }

  void _saveTrip() {
    if (!_formKey.currentState!.validate() || _dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please check inputs')));
      return;
    }

    if (_isEditing) {
      context.read<TripCubit>().updateTripBasicInfo(
        tripId: widget.trip!.id,
        title: _titleController.text,
        dateRange: _dateRange,
        coverImageUrl: _imageController.text.isNotEmpty ? _imageController.text : null,
        tags: _tags,
        destinations: _destinations,
        mainTransport: _mainTransportType,        
      );
    } else {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      context.read<TripCubit>().createTrip(
        userId: userId,
        title: _titleController.text,
        dateRange: _dateRange!,
        coverImageUrl: _imageController.text.isNotEmpty ? _imageController.text : null,
        tags: _tags,
        destinations: _destinations,
        mainTransport: _mainTransportType,
      );
    }
    
    Navigator.pop(context);
  }

  Future<void> _pickImage() async {
    setState(() => _isUploading = true);
    final url = await _storageService.pickAndUploadImage(folder: 'trip_covers');
    if (url != null) {
      setState(() {
        _imageController.text = url;
        _isUploading = false;
      });
    } else {
      setState(() => _isUploading = false);
    }
  }
}