
import 'package:flutter/material.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart'; // フォント用に追加

class SpeedDialItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  SpeedDialItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
}

class TrippleSpeedDial extends StatefulWidget {
  final List<SpeedDialItem> items;
  final bool isMenuOpen;
  final VoidCallback onToggle;
  final bool showFab;
  final IconData mainIcon;
  final VoidCallback? onMainIconTap;

  const TrippleSpeedDial({
    super.key,
    required this.items,
    required this.isMenuOpen,
    required this.onToggle,
    this.showFab = true,
    this.mainIcon = Icons.add,
    this.onMainIconTap,
  });

  @override
  State<TrippleSpeedDial> createState() => _TrippleSpeedDialState();
}

class _TrippleSpeedDialState extends State<TrippleSpeedDial> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: widget.isMenuOpen ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      parent: _controller,
    );
  }

  @override
  void didUpdateWidget(TrippleSpeedDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMenuOpen != oldWidget.isMenuOpen) {
      if (widget.isMenuOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
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
    if (!widget.showFab) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center, // 👈 修正: 真上に展開するように変更
      children: [
        if (widget.isMenuOpen) ...[
          ...widget.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ScaleTransition(
                scale: _expandAnimation,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center, // 行内でも中央揃え
                  children: [
                    // ラベル
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24), // 👈 修正: 丸っぽく！
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                        ],
                      ),
                      child: Text(
                        item.label,
                        // 👇 修正: アプリ標準のフォントスタイルを適用
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // アイコンボタン
                    FloatingActionButton.small(
                      shape: const CircleBorder(),
                      heroTag: 'speed_dial_item_$index',
                      onPressed: item.onTap,
                      backgroundColor: item.color ?? Colors.white,
                      elevation: 4,
                      child: Icon(item.icon, color: item.color != null ? Colors.white : AppColors.primary),
                    ),
                  ],
                ),
              ),
            );
          })
        ],

        // メインFAB
        FloatingActionButton(
          heroTag: 'speed_dial_main',
          onPressed: () {
            if (widget.onMainIconTap != null) {
              widget.onMainIconTap!();
            } else {
              widget.onToggle();
            }
          },
          backgroundColor: AppColors.primary,
          elevation: 4,
          shape: const CircleBorder(), // 真ん丸を明示
          child: AnimatedRotation(
            turns: widget.isMenuOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              widget.isMenuOpen ? Icons.add : widget.mainIcon,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}