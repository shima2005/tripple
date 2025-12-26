import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // 👈 パッケージ追加してね
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';
import 'package:new_tripple/shared/widgets/tripple_toast.dart';

class JoinTripModal extends StatefulWidget {
  const JoinTripModal({super.key});

  @override
  State<JoinTripModal> createState() => _JoinTripModalState();
}

class _JoinTripModalState extends State<JoinTripModal> {
  final TextEditingController _controller = TextEditingController();
  bool _isScanning = false; // デフォルトfalse (入力モード)

  @override
  Widget build(BuildContext context) {
    // 📷 スキャンモード
    if (_isScanning) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(
              errorBuilder: (context, error) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.white, size: 48),
                      const SizedBox(height: 16),
                      Text('Camera Error: ${error.errorCode}', style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() => _isScanning = false),
                        child: const Text('Enter Code Manually'),
                      ),
                    ],
                  ),
                );
              },
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    // スキャン成功！
                    setState(() {
                      _controller.text = barcode.rawValue!;
                      _isScanning = false;
                    });
                    // 自動で参加処理へ
                    _joinTrip();
                    break;
                  }
                }
              },
            ),
            // 閉じるボタン
            Positioned(
              top: 40, right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => setState(() => _isScanning = false),
              ),
            ),
            // ガイド枠
            Center(
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accent, width: 4),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const Positioned(
              bottom: 80, left: 0, right: 0,
              child: Text(
                'Scan Trip QR Code',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    // 📝 入力モード (いつものモーダル)
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.group_add_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text('Join a Trip', style: AppTextStyles.h2),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 32),

          // コード入力
          TrippleTextField(
            controller: _controller,
            label: 'Invite Code',
            hintText: 'Enter Trip ID',
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
              onPressed: () => setState(() => _isScanning = true), // カメラ起動！
            ),
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: TripplePrimaryButton(
              text: 'Join Trip',
              onPressed: _joinTrip,
            ),
          ),
        ],
      ),
    );
  }

  void _joinTrip() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // 参加処理実行
    final success = await context.read<TripCubit>().joinTripByCode(userId, code);

    if (success && mounted) {
      Navigator.pop(context); // 閉じる
      TrippleToast.show(context, 'Welcome aboard! Trip added. ');
    }
  }
}