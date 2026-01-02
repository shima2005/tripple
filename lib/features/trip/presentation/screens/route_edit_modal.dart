import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/models/enums.dart';
import 'package:new_tripple/models/route_item.dart';
import 'package:new_tripple/models/step_detail.dart';
import 'package:new_tripple/services/gemini_service.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';

class RouteEditModal extends StatefulWidget {
  final String tripId;
  final TransportType mainTransport;
  final RouteItem route;

  const RouteEditModal({super.key, required this.tripId, required this.route, required this.mainTransport});

  @override
  State<RouteEditModal> createState() => _RouteEditModalState();
}

class _RouteEditModalState extends State<RouteEditModal> {
  late TextEditingController _costController;
  late List<StepDetail> _steps;
  late TransportType _mainTransportType;

  final _geminiService = GeminiService(); 
  bool _isScanning = false; 

  @override
  void initState() {
    super.initState();
    _costController = TextEditingController(text: widget.route.cost?.toInt().toString() ?? '');
    _steps = List.from(widget.route.detailedSteps);
    _mainTransportType = (widget.route.transportType != widget.mainTransport) ? widget.route.transportType : widget.mainTransport;
  }

  @override
  void dispose() {
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = widget.route.time;
    final endTime = startTime.add(Duration(minutes: widget.route.durationMinutes));
    final timeStr = '${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)}';

    // 👇 TrippleModalScaffoldへ移行
    return TrippleModalScaffold(
      title: 'Edit Route',
      heightRatio: TrippleModalSize.highRatio, // 項目多いのでHigh
      
      // スキャン機能！
      isScanning: _isScanning,
      onScanImage: (img) => _handleScan(image: img),
      onScanText: (txt) => _handleScan(text: txt),

      // 保存
      onSave: _saveRoute,
      saveLabel: 'Save Route',

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2. Time Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(timeStr, style: AppTextStyles.h3.copyWith(fontSize: 18)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '${widget.route.durationMinutes} min',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Main Transport Method
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
          const SizedBox(height: 24),

          // 4. Cost
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TrippleTextField(
                  controller: _costController,
                  label: 'Total Cost (¥)',
                  hintText: '0',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Text('', style: AppTextStyles.label),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _calculateTotalCost,
                      icon: const Icon(Icons.calculate_outlined, size: 18),
                      label: const Text('Sum'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                        foregroundColor: AppColors.accent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 5. Steps Editor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Route Details (Steps)', style: AppTextStyles.label),
              TextButton.icon(
                onPressed: () => _openStepEditor(), 
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Step'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 4),
          
          if (_steps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(child: Text('No details added yet.', style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey))),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final item = _steps.removeAt(oldIndex);
                  _steps.insert(newIndex, item);
                });
              },
              children: [
                for (int i = 0; i < _steps.length; i++)
                  _buildStepItem(i, _steps[i]),
              ],
            ),
        ],
      ),
    );
  }

  // ... ( _handleScan, _buildStepItem などは変更なし) ...
  Future<void> _handleScan({XFile? image, String? text}) async {
    setState(() => _isScanning = true);
    
    try {
      final data = await _geminiService.extractFromImageOrText(image: image, text: text);
      if (data['type'] == 'stay') {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seems like a hotel booking. Use Spot Edit!')));
      }

      setState(() {
        final title = (data['title'] as String? ?? '').toLowerCase();
        final memo = (data['memo'] as String? ?? '').toLowerCase();
        final combined = '$title $memo';

        TransportType newType = _mainTransportType; 

        if (combined.contains('flight') || combined.contains('airline') || combined.contains('jal') || combined.contains('ana') || combined.contains('便')) {
          newType = TransportType.plane;
        } else if (combined.contains('train') || combined.contains('express') || combined.contains('shinkansen') || combined.contains('号')) {
          newType = TransportType.train;
        } else if (combined.contains('bus')) {
          newType = TransportType.bus;
        } else if (combined.contains('ferry') || combined.contains('ship') || combined.contains('boat')) {
          newType = TransportType.ferry;
        }
        
        _mainTransportType = newType;

        DateTime? depTime;
        DateTime? arrTime;
        if (data['start_time'] != null) depTime = DateTime.tryParse(data['start_time']);
        if (data['end_time'] != null) arrTime = DateTime.tryParse(data['end_time']);

        int duration = 0;
        if (depTime != null && arrTime != null) {
          duration = arrTime.difference(depTime).inMinutes;
        }

        final newStep = StepDetail(
          transportType: newType, 
          lineName: data['title'], 
          departureStation: data['origin'],
          arrivalStation: data['destination'],
          departureTime: depTime,
          arrivalTime: arrTime,
          durationMinutes: duration > 0 ? duration : 60,
          bookingDetails: data['memo'],
          cost: (data['cost'] as num?)?.toDouble(),
          customInstruction: 'Booked: ${data['title'] ?? "Transport"}',
        );

        _steps.add(newStep);
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${data['title']} to steps!')));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Widget _buildStepItem(int index, StepDetail step) {
    int minutesOffset = 0;
    for (int i = 0; i < index; i++) {
      minutesOffset += _steps[i].durationMinutes;
    }
    final stepStartTime = widget.route.time.add(Duration(minutes: minutesOffset));
    final stepStartTimeStr = DateFormat('HH:mm').format(stepStartTime);

    return Container(
      key: ValueKey(step),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Container(padding: const EdgeInsets.all(8), color: Colors.transparent, child: Icon(Icons.drag_indicator_rounded, color: Colors.grey[400])),
          ),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle), child: Icon(step.transportType.icon, color: AppColors.textPrimary, size: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _openStepEditor(step: step, index: index, startTime: stepStartTime),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('$stepStartTimeStr ', style: AppTextStyles.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          step.displayInstruction,
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (step.lineName != null || step.bookingDetails != null)
                    Text(
                      '${step.lineName ?? ""} ${step.bookingDetails ?? ""}'.trim(),
                      style: AppTextStyles.label.copyWith(fontSize: 10, color: AppColors.accent),
                    ),
                ],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.grey), onPressed: () => _openStepEditor(step: step, index: index, startTime: stepStartTime), constraints: const BoxConstraints(), padding: const EdgeInsets.all(8)),
          IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), onPressed: () => setState(() => _steps.removeAt(index)), constraints: const BoxConstraints(), padding: const EdgeInsets.all(8)),
        ],
      ),
    );
  }

  void _openStepEditor({StepDetail? step, int? index, DateTime? startTime}) {
    DateTime calculatedStartTime = startTime ?? widget.route.time;
    if (step == null) {
      int minutesOffset = 0;
      for (var s in _steps) { minutesOffset += s.durationMinutes; }
      calculatedStartTime = widget.route.time.add(Duration(minutes: minutesOffset));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StepEditorSheet(
        initialStep: step,
        initialTransportType: _mainTransportType,
        startTime: calculatedStartTime,
        onSave: (newStep) {
          setState(() {
            if (index != null) {
              _steps[index] = newStep;
            } else {
              _steps.add(newStep);
            }
          });
        },
      ),
    );
  }

  void _saveRoute() {
    final updatedRoute = widget.route.copyWith(
      cost: double.tryParse(_costController.text),
      detailedSteps: _steps,
      transportType: _mainTransportType,
    );
    context.read<TripCubit>().updateRouteItem(widget.tripId, updatedRoute);
    Navigator.pop(context);
  }

  void _calculateTotalCost() {
    double total = 0;
    for (var step in _steps) {
      total += step.cost ?? 0;
    }
    setState(() {
      _costController.text = total.toInt().toString();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Total cost updated')));
  }
}

// ----------------------------------------------------------------
// 内部クラス: ステップ編集シート
// ----------------------------------------------------------------
class _StepEditorSheet extends StatefulWidget {
  final StepDetail? initialStep;
  final TransportType initialTransportType; 
  final DateTime startTime; 
  final Function(StepDetail) onSave;

  const _StepEditorSheet({this.initialStep, required this.initialTransportType, required this.startTime, required this.onSave});

  @override
  State<_StepEditorSheet> createState() => _StepEditorSheetState();
}

class _StepEditorSheetState extends State<_StepEditorSheet> {
  late TransportType _selectedType;
  late TextEditingController _depController;
  late TextEditingController _arrController;
  late TextEditingController _lineController;
  late TextEditingController _detailController;
  late TextEditingController _durationController;
  late TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialStep?.transportType ?? widget.initialTransportType;
    _depController = TextEditingController(text: widget.initialStep?.departureStation ?? '');
    _arrController = TextEditingController(text: widget.initialStep?.arrivalStation ?? '');
    _lineController = TextEditingController(text: widget.initialStep?.lineName ?? '');
    _detailController = TextEditingController(text: widget.initialStep?.bookingDetails ?? '');
    _durationController = TextEditingController(text: widget.initialStep?.durationMinutes.toString() ?? '10');
    _costController = TextEditingController(text: widget.initialStep?.cost?.toInt().toString() ?? '');
  }

 @override
  Widget build(BuildContext context) {
    // 内部変数計算
    final isWalk = _selectedType == TransportType.walk || _selectedType == TransportType.bicycle;
    final isPublic = _selectedType == TransportType.train || _selectedType == TransportType.bus || _selectedType == TransportType.subway || _selectedType == TransportType.shinkansen || _selectedType == TransportType.plane;
    final duration = int.tryParse(_durationController.text) ?? 0;
    final endTime = widget.startTime.add(Duration(minutes: duration));
    final timeRangeStr = '${DateFormat('HH:mm').format(widget.startTime)} - ${DateFormat('HH:mm').format(endTime)}';

    // 👇 TrippleModalScaffoldへ移行 (StepはMediumサイズでOK)
    return TrippleModalScaffold(
      title: widget.initialStep == null ? 'Add Step' : 'Edit Step',
      heightRatio: TrippleModalSize.mediumRatio,
      
      onSave: () {
        final newStep = StepDetail(
          transportType: _selectedType,
          departureStation: _depController.text.isNotEmpty ? _depController.text : null,
          arrivalStation: _arrController.text.isNotEmpty ? _arrController.text : null,
          lineName: _lineController.text.isNotEmpty ? _lineController.text : null,
          bookingDetails: _detailController.text.isNotEmpty ? _detailController.text : null,
          durationMinutes: int.tryParse(_durationController.text) ?? 0,
          cost: double.tryParse(_costController.text),
          departureTime: widget.startTime,
        );
        widget.onSave(newStep);
        Navigator.pop(context);
      },
      saveLabel: widget.initialStep == null ? 'Add Step' : 'Update Step',

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_filled_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(timeRangeStr, style: AppTextStyles.label.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Method', style: AppTextStyles.label),
          const SizedBox(height: 12),
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: TransportType.values.where((t) => t != TransportType.other).map((type) {
                  return TrippleSelectionChip(
                    label: type.displayName,
                    icon: type.icon,
                    isSelected: _selectedType == type,
                    onTap: () => setState(() => _selectedType = type),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (!isWalk) ...[
                Expanded(child: TrippleTextField(controller: _depController, label: 'From', hintText: 'Station')),
                const SizedBox(width: 16),
              ],
              Expanded(child: TrippleTextField(controller: _arrController, label: 'To', hintText: 'Destination')),
            ],
          ),
          const SizedBox(height: 24),
          if (isPublic) ...[
            TrippleTextField(controller: _lineController, label: 'Details', hintText: 'Line Name'),
            const SizedBox(height: 12),
            TrippleTextField(controller: _detailController, hintText: 'Booking', label: null),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              Expanded(child: TrippleTextField(controller: _costController, label: 'Cost (¥)', hintText: '0', keyboardType: TextInputType.number)),
              const SizedBox(width: 16),
              Expanded(child: TrippleTextField(controller: _durationController, label: 'Min', hintText: '10', keyboardType: TextInputType.number, onChanged: (_) => setState((){}))),
            ],
          ),
        ],
      ),
    );
  }
}