import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';

class ScanButton extends StatelessWidget {
  final Function(XFile?) onImagePicked;
  final Function(String?) onTextPasted;

  const ScanButton({
    super.key,
    required this.onImagePicked,
    required this.onTextPasted,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48), // ボタンの下に綺麗に出す
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // メニューも角丸
      tooltip: 'Scan Reservation',
      onSelected: (value) async {
        if (value == 'image') {
          final ImagePicker picker = ImagePicker();
          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
          if (image != null) onImagePicked(image);
        } else if (value == 'text') {
          _showTextPasteDialog(context);
        }
      },
      // 👇 ボタンのデザインをカスタマイズ！
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1), // 薄いプライマリー色
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.document_scanner_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 6),
            Text(
              'Scan',
              style: AppTextStyles.label.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'image',
          child: Row(
            children: [
              Icon(Icons.image_rounded, color: AppColors.primary),
              SizedBox(width: 12),
              Text('Import Image', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'text',
          child: Row(
            children: [
              Icon(Icons.paste_rounded, color: AppColors.primary),
              SizedBox(width: 12),
              Text('Paste Text', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  void _showTextPasteDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.paste_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Paste Info'),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: 'Paste reservation email or text here...',
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) onTextPasted(controller.text);
            },
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }
}