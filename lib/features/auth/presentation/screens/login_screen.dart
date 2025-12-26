import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/auth/data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {    
    return Scaffold(
      body: Stack(
        children: [
          // 1. 背景グラデーション
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF66a6ff)], // 深い青から明るい青へ
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // 2. 装飾的な円 (デザインアクセント)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),

          // 3. メインコンテンツ
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2), // 上の余白

                // --- ロゴエリア ---
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2), // 半透明
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: const Icon(Icons.flight_takeoff_rounded, size: 64, color: Colors.white),
                ),
                const SizedBox(height: 32),
                
                Text(
                  'tripple', 
                  style: AppTextStyles.h1.copyWith(
                    color: Colors.white, 
                    fontSize: 42, 
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Plan your best trip ever.',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70, fontSize: 16),
                ),

                const Spacer(flex: 3), // 下の余白

                // --- 操作エリア (ボトムシート風) ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Column(
                    children: [
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else ...[
                        // Google Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () => _handleLogin(context, isAnonymous: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: const BorderSide(color: Colors.black12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Googleロゴ (アイコンで代用)
                                const Icon(Icons.g_mobiledata_rounded, size: 36, color: Colors.red),
                                const SizedBox(width: 8),
                                Text('Sign in with Google', style: AppTextStyles.h3.copyWith(fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Apple Login (仮) - デザインだけ置いておく
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {}, // まだ機能なし
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.apple, size: 28, color: Colors.white),
                                const SizedBox(width: 12),
                                Text('Sign in with Apple', style: AppTextStyles.h3.copyWith(fontSize: 16, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Guest Login Button
                        TextButton(
                          onPressed: () => _handleLogin(context, isAnonymous: true),
                          child: Text(
                            'Skip & Start as Guest',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin(BuildContext context, {required bool isAnonymous}) async {
    setState(() => _isLoading = true);
    try {
      if (isAnonymous) {
        // ▼▼▼ 修正: ゲストログインを実行 ▼▼▼
        await context.read<AuthRepository>().signInAnonymously();
      } else {
        // Googleログイン
        await context.read<AuthRepository>().signInWithGoogle();
      }
      // 成功すれば main.dart の StreamBuilder が反応して画面遷移します
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}