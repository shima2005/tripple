import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import 'dart:ui'; 
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/models/enums.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/services/gemini_service.dart';
import 'package:new_tripple/services/geocoding_service.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';
import 'package:new_tripple/features/trip/presentation/screens/place_search_modeal.dart';
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';

class AITripPlanModal extends StatefulWidget {
  final Function(Trip) onTripCreated;

  const AITripPlanModal({super.key, required this.onTripCreated});

  @override
  State<AITripPlanModal> createState() => _AITripPlanModalState();
}

class _AITripPlanModalState extends State<AITripPlanModal> {
  // ... (変数はそのまま)
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _startLocController = TextEditingController();
  final TextEditingController _endLocController = TextEditingController();
  final TextEditingController _excludeController = TextEditingController();
  PlaceSearchResult? _destination;
  DateTimeRange? _dateRange;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 0);
  TransportType _transportType = TransportType.transit;
  String _tripStyle = 'Balanced'; 
  final List<String> _excludedPlaces = [];
  final List<DateTime> _freeDates = [];
  final List<AccommodationRequest> _accommodations = []; 
  bool _autoSuggest = true;
  final List<ScheduledItem> _mustVisitItems = [];
  final List<String> _styles = ['Balanced', 'Relaxed', 'Packed', 'History', 'Foodie', 'Nature', 'Maniac', 'Luxury', 'Local'];

  @override
  void dispose() {
    _titleController.dispose();
    _startLocController.dispose();
    _endLocController.dispose();
    _excludeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return TrippleModalScaffold(
        title: 'Generating...',
        icon: Icons.auto_awesome,
        heightRatio: TrippleModalSize.highRatio,
        isScrollable: false, 
        child: _AILoadingView(destination: _destination?.name ?? 'Destination'),
      );
    }

    return TrippleModalScaffold(
      title: 'AI Trip Planner',
      icon: Icons.auto_awesome,
      heightRatio: TrippleModalSize.highRatio,
      isScrollable: false, // PageViewを使うのでfalse

      child: Column(
        children: [
          _buildProgressIndicator(),
          const SizedBox(height: 24),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1Basic(),
                _buildStepLogistics(),
                _buildStep2Preferences(),
                _buildStepHotels(),
                _buildStep3MustVisit(),
                _buildStep4Confirm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 👇 修正: Scrollableなレイアウトに変更 (Step 1) ---
  Widget _buildStep1Basic() {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false, // 中身がスクロール不要ならフィット、必要ならスクロール
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step 1: Basics', style: AppTextStyles.label),
              const SizedBox(height: 16),
              
              GestureDetector(
                onTap: () async {
                  final result = await showModalBottomSheet<PlaceSearchResult>(
                    context: context,
                    isScrollControlled: true, // フルスクリーン検索用
                    backgroundColor: Colors.transparent,
                    builder: (context) => const PlaceSearchModal(hintText: 'Destination (e.g. Kyoto, France)'),
                  );
                  if (result != null) {
                    setState(() {
                      _destination = result;
                      if (_titleController.text.isEmpty) _titleController.text = "Trip to ${result.name}";
                    });
                  }
                },
                child: _buildSelectBox(icon: Icons.map_rounded, text: _destination?.name ?? 'Where are you going?', isActive: _destination != null),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: _dateRange,
                    builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
                  );
                  if (picked != null) setState(() => _dateRange = picked);
                },
                child: _buildSelectBox(icon: Icons.calendar_today_rounded, text: _dateRange == null ? 'When?' : '${DateFormat('yyyy/MM/dd').format(_dateRange!.start)} - ${DateFormat('MM/dd').format(_dateRange!.end)}', isActive: _dateRange != null),
              ),
              const SizedBox(height: 16),

              TrippleTextField(controller: _titleController, label: 'Trip Title', hintText: 'e.g. Summer Vacation'),
              
              const Spacer(), // 下部に余白を埋める
              const SizedBox(height: 24), // Spacerが0になった時の最低余白
              
              TripplePrimaryButton(
                text: 'Next', 
                onPressed: () {
                  if (_destination != null && _dateRange != null && _titleController.text.isNotEmpty) {
                    _nextStep();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                  }
                }
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 👇 修正: Scrollableなレイアウトに変更 (Step 2) ---
  Widget _buildStepLogistics() {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step 2: Start & End', style: AppTextStyles.label),
              const SizedBox(height: 20),
              Row(children: [const Icon(Icons.flight_takeoff_rounded, color: AppColors.primary), const SizedBox(width: 8), Text('Day 1 Start', style: AppTextStyles.h3.copyWith(fontSize: 16))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(flex: 2, child: GestureDetector(onTap: () => _pickTimeCupertino(true), child: _buildSelectBox(icon: Icons.access_time, text: _formatTime(_startTime), isActive: true, isSmall: true))), const SizedBox(width: 8), Expanded(flex: 3, child: TrippleTextField(controller: _startLocController, hintText: 'e.g. Tokyo St.', label: null))]),
              const SizedBox(height: 32),
              Row(children: [const Icon(Icons.flight_land_rounded, color: AppColors.accent), const SizedBox(width: 8), Text('Last Day Goal', style: AppTextStyles.h3.copyWith(fontSize: 16))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(flex: 2, child: GestureDetector(onTap: () => _pickTimeCupertino(false), child: _buildSelectBox(icon: Icons.access_time, text: _formatTime(_endTime), isActive: true, isSmall: true))), const SizedBox(width: 8), Expanded(flex: 3, child: TrippleTextField(controller: _endLocController, hintText: 'e.g. Airport', label: null))]),
              
              const Spacer(),
              const SizedBox(height: 24),
              _buildNavButtons(),
            ],
          ),
        ),
      ],
    );
  }

  // --- 👇 修正: Scrollableなレイアウトに変更 (Step 3) ---
  Widget _buildStep2Preferences() {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step 3: Preferences', style: AppTextStyles.label),
              const SizedBox(height: 16),
              Text('Trip Style', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ScrollConfiguration(behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}), child: SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: Row(children: _styles.map((style) => TrippleSelectionChip(label: style, icon: Icons.style_rounded, isSelected: _tripStyle == style, onTap: () => setState(() => _tripStyle = style))).toList()))),
              const SizedBox(height: 24),
              Text('Transport Mode', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ScrollConfiguration(behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}), child: SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: Row(children: [TransportType.transit, TransportType.car, TransportType.walk].map((type) { return TrippleSelectionChip(label: type.displayName, icon: type.icon, isSelected: _transportType == type, onTap: () => setState(() => _transportType = type)); }).toList()))),
              const SizedBox(height: 24),
              Text('Exclude Places', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: TrippleTextField(controller: _excludeController, hintText: 'Add place to skip...', onSubmitted: (val) { if (val.isNotEmpty) { setState(() { _excludedPlaces.add(val); _excludeController.clear(); }); } })), const SizedBox(width: 8), IconButton(onPressed: () { if (_excludeController.text.isNotEmpty) { setState(() { _excludedPlaces.add(_excludeController.text); _excludeController.clear(); }); } }, icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 32))]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: _excludedPlaces.map((p) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(p, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)), const SizedBox(width: 8), GestureDetector(onTap: () => setState(() => _excludedPlaces.remove(p)), child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey))]))).toList()),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Free Days (No Plan)', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)), TextButton.icon(onPressed: _pickFreeDate, icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add Date'))]),
              Wrap(spacing: 8, children: _freeDates.map((d) => Chip(label: Text(DateFormat('MM/dd').format(d)), onDeleted: () => setState(() => _freeDates.remove(d)), backgroundColor: AppColors.accent.withValues(alpha: 0.1))).toList()),
              
              const Spacer(),
              const SizedBox(height: 24),
              _buildNavButtons(),
            ],
          ),
        ),
      ],
    );
  }

  // --- Step 4: Hotels ---
  Widget _buildStepHotels() {
    if (_dateRange == null) return const SizedBox.shrink();
    final totalDays = _dateRange!.end.difference(_dateRange!.start).inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 4: Accommodation', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Text('Leave blank for AI suggestion.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),

        Expanded(
          child: ListView.separated(
            itemCount: totalDays,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final existing = _accommodations.firstWhere(
                  (a) => a.dayIndex == index, 
                  orElse: () => AccommodationRequest(dayIndex: index, name: '')
              );
              
              return Row(
                children: [
                  Container(
                    width: 80,
                    alignment: Alignment.centerLeft,
                    child: Text('Night ${index + 1}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: TrippleTextField(
                      controller: TextEditingController(text: existing.name),
                      hintText: 'Hotel Name / Area',
                      onChanged: (val) {
                        _accommodations.removeWhere((a) => a.dayIndex == index);
                        if (val.isNotEmpty) {
                          _accommodations.add(AccommodationRequest(dayIndex: index, name: val));
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        _buildNavButtons(),
      ],
    );
  }

  // --- Step 5: Must Visit ---
  Widget _buildStep3MustVisit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 5: Must Visit', style: AppTextStyles.label),
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
          child: SwitchListTile(
            title: const Text('Auto Suggest Spots', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Fill empty slots with AI picks', style: TextStyle(fontSize: 12, color: Colors.grey)),
            value: _autoSuggest,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _autoSuggest = val),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addMustVisitPlace,
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text('Add Must-Visit Place'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: _mustVisitItems.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.auto_awesome_mosaic_rounded, size: 48, color: Colors.grey[300]), const SizedBox(height: 12), Text('AI will suggest everything!', style: TextStyle(color: Colors.grey[400]))]
                ))
              : ListView.separated(
                  itemCount: _mustVisitItems.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _mustVisitItems[index];
                    return Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: ListTile(
                        leading: const Icon(Icons.place, color: AppColors.primary),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${item.durationMinutes} min'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit_rounded, size: 20, color: Colors.grey), onPressed: () => _editMustVisitItem(index)),
                            IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey), onPressed: () => setState(() => _mustVisitItems.removeAt(index))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildNavButtons(),
      ],
    );
  }
  
  // --- Step 6: Confirm ---
  Widget _buildStep4Confirm() {
    if (_dateRange == null) return const SizedBox.shrink();
    return Column(
      children: [
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), shape: BoxShape.circle),
          child: const Icon(Icons.rocket_launch_rounded, size: 64, color: AppColors.primary),
        ),
        const SizedBox(height: 24),
        Text('Ready to Generate!', style: AppTextStyles.h1),
        const SizedBox(height: 8),
        Text('AI is ready to plan your trip to', style: TextStyle(color: Colors.grey[600])),
        Text(_destination?.name ?? '', style: AppTextStyles.h3),
        const SizedBox(height: 24),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: Column(
            children: [
              _buildSummaryRow(Icons.title, _titleController.text),
              const SizedBox(height: 8),
              _buildSummaryRow(Icons.calendar_today, '${DateFormat('MM/dd').format(_dateRange!.start)} - ${DateFormat('MM/dd').format(_dateRange!.end)}'),
              const SizedBox(height: 8),
              _buildSummaryRow(Icons.directions_bus, _transportType.displayName),
              const SizedBox(height: 8),
              _buildSummaryRow(Icons.flag, '${_mustVisitItems.length} places requested'),
            ],
          ),
        ),

        const Spacer(),
        Row(
          children: [
            Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)), child: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _prevStep)),
            const SizedBox(width: 12),
            Expanded(child: TripplePrimaryButton(text: 'Generate Plan! 🚀', onPressed: _generatePlan)),
          ],
        ),
      ],
    );
  }

  // --- Helpers ---
  Widget _buildSummaryRow(IconData icon, String text) {
    return Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis))]);
  }

  Widget _buildSelectBox({required IconData icon, required String text, required bool isActive, bool isSmall = false}) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(color: AppColors.background, border: Border.all(color: isActive ? AppColors.primary : Colors.transparent), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [Icon(icon, color: isActive ? AppColors.primary : Colors.grey, size: isSmall ? 20 : 24), const SizedBox(width: 12), Expanded(child: Text(text, style: isActive ? AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: isSmall ? 14 : 16) : AppTextStyles.bodyMedium.copyWith(color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis))]),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(6, (index) {
        final isActive = index <= _currentStep;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.grey[200],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNavButtons() {
    return Row(
      children: [
        Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)), child: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _prevStep)),
        const SizedBox(width: 12),
        Expanded(child: TripplePrimaryButton(text: 'Next', onPressed: _nextStep)),
      ],
    );
  }

  void _nextStep() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _currentStep++);
  }
  void _prevStep() {
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _currentStep--);
  }

  // 👇 修正: iOS風スクロールピッカー
  void _pickTimeCupertino(bool isStart) {
    final initialTime = isStart ? _startTime : _endTime;
    final initialDateTime = DateTime(2020, 1, 1, initialTime.hour, initialTime.minute);

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
                onDateTimeChanged: (val) {
                  setState(() {
                    if (isStart){
                      _startTime = TimeOfDay.fromDateTime(val);
                    }else{
                      _endTime = TimeOfDay.fromDateTime(val);
                    }
                  });
                },
              ),
            ),
            CupertinoButton(
              child: const Text('Done', style: TextStyle(color: AppColors.primary)),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
      ),
    );
  }
  String _formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  Future<void> _pickFreeDate() async {
    if (_dateRange == null) return;
    final picked = await showDatePicker(context: context, initialDate: _dateRange!.start, firstDate: _dateRange!.start, lastDate: _dateRange!.end, builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!));
    if (picked != null && !_freeDates.contains(picked)) setState(() => _freeDates.add(picked));
  }

  Future<void> _addMustVisitPlace() async {
    final result = await showModalBottomSheet<PlaceSearchResult>(context: context, backgroundColor: Colors.transparent, builder: (context) => const PlaceSearchModal());
    if (result == null) return;
    final duration = await _showDurationDialog();
    setState(() {
      _mustVisitItems.add(ScheduledItem(id: '', dayIndex: 0, time: DateTime(2000), name: result.name, latitude: result.location.latitude, longitude: result.location.longitude, category: ItemCategory.sightseeing, durationMinutes: duration ?? 90));
    });
  }

  Future<void> _editMustVisitItem(int index) async {
    final item = _mustVisitItems[index];
    final duration = await _showDurationDialog(initialValue: item.durationMinutes);
    if (duration != null) setState(() => _mustVisitItems[index] = item.copyWith(durationMinutes: duration));
  }

  // 👇 修正: クイックボタン付き時間入力ダイアログ
  Future<int?> _showDurationDialog({int? initialValue}) async {
    int currentMinutes = initialValue ?? 90;
    
    return await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // 中身に合わせて高さを変える
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 時間表示用のフォーマット
            final hours = currentMinutes ~/ 60;
            final mins = currentMinutes % 60;
            final timeText = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ヘッダー
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_rounded, color: AppColors.primary, size: 28),
                          const SizedBox(width: 12),
                          Text('Stay Duration', style: AppTextStyles.h2),
                        ],
                      ),
                      // 完了ボタン (右上)
                      TextButton(
                        onPressed: () => Navigator.pop(context, currentMinutes),
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 1. 大きな時間表示 (タップで手入力も可能にしてもいいが、今回は表示メイン)
                  Center(
                    child: Text(
                      timeText,
                      style: AppTextStyles.h1.copyWith(fontSize: 48, color: AppColors.primary),
                    ),
                  ),
                  Text('$currentMinutes min', style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey)),
                  
                  const SizedBox(height: 24),

                  // 2. クイックボタン (丸くてカワイイやつ)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _QuickActionButton(label: '-30', onTap: () => setState(() => currentMinutes = (currentMinutes - 30).clamp(10, 720))),
                      _QuickActionButton(label: '-10', onTap: () => setState(() => currentMinutes = (currentMinutes - 10).clamp(10, 720))),
                      _QuickActionButton(label: '+10', onTap: () => setState(() => currentMinutes = (currentMinutes + 10).clamp(10, 720))),
                      _QuickActionButton(label: '+30', onTap: () => setState(() => currentMinutes = (currentMinutes + 30).clamp(10, 720))),
                      _QuickActionButton(label: '+60', onTap: () => setState(() => currentMinutes = (currentMinutes + 60).clamp(10, 720))),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(),

                  // 3. スクロールピッカー (CupertinoTimerPicker)
                  SizedBox(
                    height: 150,
                    child: CupertinoTimerPicker(
                      mode: CupertinoTimerPickerMode.hm, // 時:分
                      initialTimerDuration: Duration(minutes: currentMinutes),
                      onTimerDurationChanged: (Duration newDuration) {
                        setState(() {
                          currentMinutes = newDuration.inMinutes;
                          if (currentMinutes < 10) currentMinutes = 10; // 最低10分
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 保存ボタン
                  TripplePrimaryButton(
                    text: 'Set Duration',
                    onPressed: () => Navigator.pop(context, currentMinutes),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  

  // ... (_generatePlan は変更なし)
  Future<void> _generatePlan() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    final createdTrip = await context.read<TripCubit>().createTripWithAI(
      userId: userId,
      title: _titleController.text,
      destination: _destination!.name,
      dateRange: _dateRange!,
      mustVisitItems: _mustVisitItems,
      excludedPlaces: _excludedPlaces,
      freeDates: _freeDates,
      tripStyle: _tripStyle,
      accommodations: _accommodations,
      startLocation: _startLocController.text.isEmpty ? null : _startLocController.text,
      startTime: _formatTime(_startTime),
      endLocation: _endLocController.text.isEmpty ? null : _endLocController.text,
      endTime: _formatTime(_endTime),
      transportType: _transportType,
      autoSuggest: _autoSuggest,
    );

    if (createdTrip != null) {
      if (mounted) {
        Navigator.pop(context); 
        widget.onTripCreated(createdTrip); 
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate plan.')));
      }
    }
  }
}


class _QuickActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPlus = label.startsWith('+');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isPlus ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPlus ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPlus ? AppColors.primary : AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _AILoadingView extends StatefulWidget {
  final String destination;
  const _AILoadingView({required this.destination});

  @override
  State<_AILoadingView> createState() => _AILoadingViewState();
}

class _AILoadingViewState extends State<_AILoadingView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  int _messageIndex = 0;
  late List<String> _messages;
  
  @override
  void initState() {
    super.initState();
    
    // 1. メッセージリスト (行き先を入れる！)
    _messages = [
      'Analyzing your travel style...',
      'Searching for hidden gems in ${widget.destination}...',
      'Checking opening hours & best times...',
      'Calculating optimal routes & transport...',
      'Finding the perfect hotels...',
      'Finalizing your dream itinerary...',
    ];

    // 2. ふわふわアニメーション
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true); // 膨らんだり縮んだり

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // 3. メッセージ切り替えタイマー
    _startMessageTimer();
  }

  void _startMessageTimer() async {
    for (int i = 0; i < _messages.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 2500)); // 2.5秒ごとに切り替え
      if (mounted) {
        setState(() {
          // 最後まで行ったら最後のメッセージで止める
          if (_messageIndex < _messages.length - 1) {
            _messageIndex++;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 背景装飾 (薄いグラデーション円)
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50, left: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.05),
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // メインアイコン (ふわふわアニメーション)
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, size: 64, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 48),

                // インジケーター
                const SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Color(0xFFF0F0F0),
                    color: AppColors.primary,
                    minHeight: 4,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),

                // 切り替わるメッセージ
                SizedBox(
                  height: 60, // 高さ固定でガタつき防止
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2), // 下から
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _messages[_messageIndex],
                      key: ValueKey<int>(_messageIndex), // Keyを変えるとアニメーションする
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}