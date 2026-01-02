import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';
import 'package:new_tripple/shared/widgets/modal_header.dart';
import 'package:new_tripple/shared/widgets/scan_button.dart';

class TrippleModalScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final List<Widget>? extraHeaderActions;
  final double? heightRatio;
  final VoidCallback? onSave;
  final String saveLabel;
  final VoidCallback? onDelete;
  final String deleteLabel;
  final bool isLoading;
  final Widget? customFooter;
  final Function(XFile?)? onScanImage;
  final Function(String?)? onScanText;
  final bool isScanning;
  final bool isScrollable;

  const TrippleModalScaffold({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.extraHeaderActions,
    this.heightRatio,
    this.onSave,
    this.saveLabel = 'Save',
    this.onDelete,
    this.deleteLabel = 'Delete',
    this.isLoading = false,
    this.customFooter,
    this.onScanImage,
    this.onScanText,
    this.isScanning = false,
    this.isScrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = heightRatio ?? TrippleModalSize.mediumRatio;
    final maxModalHeight = TrippleModalSize.getHeight(context, ratio);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxModalHeight,
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        // 👇 修正: リスト系(false)なら最大まで広げ、フォーム系(true)なら縮める
        mainAxisSize: isScrollable ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrippleModalHeader(
            title: title,
            icon: icon,
            actions: _buildHeaderActions(),
          ),
          
          const SizedBox(height: 24),

          if (isScrollable)
            // フォーム系: 縮小＆スクロール
            Flexible(
              fit: FlexFit.loose, 
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomInset + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    child,
                    const SizedBox(height: 32),
                    _buildFooter(context),
                  ],
                ),
              ),
            )
          else
            // リスト系: 最大化＆フッター固定
            Expanded(
              child: Column(
                children: [
                  Expanded(child: child),
                  // キーボードが出てもフッターが見えるようにパディング調整
                  Padding(
                    padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 16 : 24),
                    child: _buildFooter(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildHeaderActions() {
    final actions = <Widget>[];
    if (onScanImage != null || onScanText != null) {
      if (isScanning) {
        actions.add(const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
      } else {
        actions.add(Transform.scale(scale: 0.9, child: ScanButton(onImagePicked: onScanImage!, onTextPasted: onScanText!)));
      }
    }
    if (extraHeaderActions != null) {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
      actions.addAll(extraHeaderActions!);
    }
    return actions;
  }

  Widget _buildFooter(BuildContext context) {
    if (customFooter != null) return customFooter!;
    if (onSave == null && onDelete == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onDelete != null) ...[
          Center(
            child: TextButton.icon(
              onPressed: (isLoading || isScanning) ? null : onDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              label: Text(deleteLabel, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (onSave != null)
          TripplePrimaryButton(
            text: isLoading ? 'Saving...' : saveLabel,
            onPressed: (isLoading || isScanning) ? () {} : onSave!,
          ),
      ],
    );
  }
}