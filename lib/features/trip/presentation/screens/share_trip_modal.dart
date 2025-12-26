import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/user/data/user_repository.dart'; // UserRepo
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart'; // TrippleTextField
import 'package:qr_flutter/qr_flutter.dart';
import 'package:new_tripple/models/user_profile.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ShareTripModal extends StatefulWidget {
  final Trip trip;

  const ShareTripModal({super.key, required this.trip});

  @override
  State<ShareTripModal> createState() => _ShareTripModalState();
}

class _ShareTripModalState extends State<ShareTripModal> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  List<UserProfile>? _friends;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }
  
  Future<void> _loadFriends() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final repo = context.read<UserRepository>();
    final myProfile = await repo.getUserProfile(uid);
    if (myProfile != null && myProfile.friendIds.isNotEmpty) {
      final friends = await repo.getUsersByIds(myProfile.friendIds);
      if (mounted) setState(() => _friends = friends);
    } else {
      if (mounted) setState(() => _friends = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),

              Text('Invite Friends', style: AppTextStyles.h2),
              const SizedBox(height: 32),

              // --- 1. QR Code ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 8))],
                ),
                child: QrImageView(
                  data: widget.trip.id,
                  version: QrVersions.auto,
                  size: 180.0,
                  foregroundColor: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),

              // --- 2. Copy Code ---
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.trip.id));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied! 📋')));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.trip.id, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      const SizedBox(width: 12),
                      const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 👇 Friends Section (優先表示)
              if (_friends != null && _friends!.isNotEmpty) ...[
                Align(alignment: Alignment.centerLeft, child: Text('Quick Invite Friends', style: AppTextStyles.h3)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _friends!.length,
                    separatorBuilder: (c, i) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final friend = _friends![index];
                      // すでにメンバーかチェック
                      final isMember = widget.trip.memberIds?.contains(friend.uid) ?? false;

                      return GestureDetector(
                        onTap: isMember ? null : () => _inviteUser(friend), // タップで招待！
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: friend.photoUrl != null ? CachedNetworkImageProvider(friend.photoUrl!) : null,
                                  child: friend.photoUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                                ),
                                if (isMember)
                                  Positioned(
                                    right: 0, bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              friend.displayName,
                              style: TextStyle(fontSize: 11, color: isMember ? Colors.grey : AppColors.textPrimary),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                const SizedBox(height: 16),
              ],

              // --- 3. Invite by ID (ここに追加！) ---
              Align(alignment: Alignment.centerLeft, child: Text('Invite by User ID', style: AppTextStyles.h3)),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: TrippleTextField(
                      controller: _searchController,
                      hintText: '@username',
                      suffixIcon: const Icon(Icons.alternate_email_rounded, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: _isSearching ? null : _searchAndInvite,
                    icon: _isSearching 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 招待ロジックを共通化
  Future<void> _inviteUser(UserProfile user) async {
    // _searchAndInvite の中身とほぼ同じだが、引数でUserを受け取る
    setState(() => _isSearching = true);
    try {
      final myUid = FirebaseAuth.instance.currentUser!.uid;
    
      final repo = context.read<UserRepository>();

      final myProfile = await repo.getUserProfile(myUid);
      final myName = myProfile?.displayName ?? 'Unknown';

      await repo.sendTripInvitation(
        toUid: user.uid,
        fromUid: myUid,
        fromName: myName,
        tripId: widget.trip.id,
        tripName: widget.trip.title,
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invited ${user.displayName}! ✨')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _searchAndInvite() async {
    final customId = _searchController.text.trim();
    if (customId.isEmpty) return;

    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus(); // キーボード閉じる

    try {
      final userRepo = context.read<UserRepository>();
      // 1. ユーザー検索
      final user = await userRepo.searchUserByCustomId(customId);

      if (user != null){
        _inviteUser(user);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }
}