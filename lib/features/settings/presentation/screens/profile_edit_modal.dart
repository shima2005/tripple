import 'dart:async'; // Timer用
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/features/settings/domain/settings_cubit.dart';
import 'package:new_tripple/features/user/data/user_repository.dart';
import 'package:new_tripple/models/user_profile.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:new_tripple/services/storage_service.dart';
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';

class ProfileEditModal extends StatefulWidget {
  final UserProfile? profile;

  const ProfileEditModal({super.key, this.profile});

  @override
  State<ProfileEditModal> createState() => _ProfileEditModalState();
}

class _ProfileEditModalState extends State<ProfileEditModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _idController;
  String? _photoUrl;
  bool _isLoading = false;
  
  // IDチェック用
  Timer? _debounce;
  String? _idErrorText; // エラーメッセージ
  bool _isIdChecking = false; // チェック中フラグ
  bool _isIdValid = true; // 有効かどうか

  final _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.displayName ?? '');
    _idController = TextEditingController(text: widget.profile?.customId ?? '');
    _photoUrl = widget.profile?.photoUrl;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  // 🔍 リアルタイムIDチェック
  void _onIdChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // 入力が空ならリセット
    if (value.isEmpty) {
      setState(() {
        _idErrorText = null;
        _isIdValid = false;
        _isIdChecking = false;
      });
      return;
    }

    // 簡易バリデーション
    if (value.length < 4 || !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      setState(() {
        _idErrorText = '4文字以上の英数字と_のみ使用可能です';
        _isIdValid = false;
        _isIdChecking = false;
      });
      return;
    }

    setState(() {
      _idErrorText = null;
      _isIdChecking = true; // チェック中...
    });

    // 500ms待ってからFirestoreに問い合わせ (API節約)
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // 自分の今のIDと同じならOK
      if (value == widget.profile?.customId) {
        setState(() {
          _isIdChecking = false;
          _isIdValid = true;
          _idErrorText = null; // エラーなし
        });
        return;
      }

      final repo = context.read<UserRepository>();
      final existingUser = await repo.searchUserByCustomId(value);

      if (mounted) {
        setState(() {
          _isIdChecking = false;
          if (existingUser == null) {
            _isIdValid = true; // ✅ OK!
            _idErrorText = null;
          } else {
            _isIdValid = false; // ❌ 重複
            _idErrorText = 'このIDは既に使用されています';
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 判定結果に応じたサフィックスアイコン
    Widget? suffixIcon;
    if (_isIdChecking) {
      suffixIcon = const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2));
    } else if (_idController.text.isNotEmpty) {
      if (_isIdValid) {
        suffixIcon = const Icon(Icons.check_circle_rounded, color: Colors.green);
      } else if (_idErrorText != null) { // エラーがある場合のみ赤
        suffixIcon = const Icon(Icons.error_rounded, color: Colors.red);
      }
    }

    return TrippleModalScaffold(
      title: 'Edit Profile',
      heightRatio: TrippleModalSize.highRatio,
      
      onSave: (_isIdValid && !_isIdChecking) ? _saveProfile : null, // ID無効なら押せない
      saveLabel: 'Save Profile',
      isLoading: _isLoading,

      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 📷 アイコン画像
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _photoUrl != null ? CachedNetworkImageProvider(_photoUrl!) : null,
                    child: _photoUrl == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 📝 名前
            TrippleTextField(
              controller: _nameController,
              label: 'Display Name',
              validator: (val) => val!.isEmpty ? 'Required' : null,
              hintText: '',
            ),
            const SizedBox(height: 16),

            // 🆔 カスタムID (強化版)
            TrippleTextField(
              controller: _idController,
              label: 'User ID (@)',
              hintText: 'unique_id',
              suffixIcon: suffixIcon, // 結果アイコン表示
              onChanged: _onIdChanged, // 入力監視
              // 独自バリデーション表示
            ),
            // エラーメッセージ/OKメッセージの表示エリア
            if (_idErrorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Align(alignment: Alignment.centerLeft, child: Text(_idErrorText!, style: const TextStyle(color: Colors.red, fontSize: 12))),
              )
            else if (_isIdValid && _idController.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 12),
                child: Align(alignment: Alignment.centerLeft, child: Text('このIDは使用可能です！ 👍', style: TextStyle(color: Colors.green, fontSize: 12))),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() => _isLoading = true);
    final url = await _storageService.pickAndUploadImage(folder: 'user_icons');
    if (url != null) {
      setState(() => _photoUrl = url);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    // 念のため最終チェック
    if (!_isIdValid) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID is not valid')));
        return;
    }
    
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    
    final newProfile = UserProfile(
      uid: uid,
      customId: _idController.text.trim(),
      displayName: _nameController.text.trim(),
      photoUrl: _photoUrl,
      friendIds: widget.profile?.friendIds ?? [],
    );

    // 👇 修正: Cubit経由で保存 (これでSettingsScreenが更新される！)
    await context.read<SettingsCubit>().updateUserProfile(newProfile);
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));//TODO
    }
  }
}