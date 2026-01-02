import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; 
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';
import 'package:new_tripple/shared/widgets/tripple_toast.dart';
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';

class JoinTripModal extends StatefulWidget {
  const JoinTripModal({super.key});

  @override
  State<JoinTripModal> createState() => _JoinTripModalState();
}

class _JoinTripModalState extends State<JoinTripModal> {
  final TextEditingController _controller = TextEditingController();
  bool _isScanning = false; 

  @override
  Widget build(BuildContext context) {
    // 📷 スキャンモード (フルスクリーンが良いのでここだけScaffoldのまま)
    if (_isScanning) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    setState(() {
                      _controller.text = barcode.rawValue!;
                      _isScanning = false;
                    });
                  }
                }
              },
            ),
            Positioned(
              top: 50, right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => setState(() => _isScanning = false),
              ),
            ),
            const Center(
              child: Text(
                'Scan QR Code',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
              ),
            ),
          ],
        ),
      );
    }

    // 📝 入力モード (TrippleModalScaffold)
    return TrippleModalScaffold(
      title: 'Join a Trip',
      icon: Icons.group_add_rounded,
      
      // 内容が少ないので Medium でも十分だが、MaxHeightStrategyがあるので安心
      heightRatio: TrippleModalSize.mediumRatio,

      // Joinボタンをフッターに
      onSave: _joinTrip,
      saveLabel: 'Join Trip',

      child: Column(
        children: [
          const Text(
            'Enter the Invite Code shared by your friend, or scan their QR code.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // コード入力
          TrippleTextField(
            controller: _controller,
            label: 'Invite Code',
            hintText: 'Enter Trip ID',
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
              onPressed: () => setState(() => _isScanning = true), // カメラ起動
            ),
          ),
          // ボタンは onSave に移動したので削除
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
    
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      TrippleToast.show(context, 'Joined trip successfully!');
    } else {
      TrippleToast.show(context, 'Invalid code or already joined.', isError: true);
    }
  }
}