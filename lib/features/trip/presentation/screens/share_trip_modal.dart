import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/user/data/user_repository.dart'; 
import 'package:new_tripple/models/trip.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:new_tripple/models/user_profile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';

class ShareTripModal extends StatefulWidget {
  final Trip trip;

  const ShareTripModal({super.key, required this.trip});

  @override
  State<ShareTripModal> createState() => _ShareTripModalState();
}

class _ShareTripModalState extends State<ShareTripModal> {
  List<UserProfile>? _friends;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }
  
  Future<void> _loadFriends() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userRepo = context.read<UserRepository>();
    final profile = await userRepo.getUserProfile(uid);
    if (profile != null && profile.friendIds.isNotEmpty) {
      final friends = await userRepo.getUsersByIds(profile.friendIds);
      if (mounted) setState(() => _friends = friends);
    } else {
      if (mounted) setState(() => _friends = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TrippleModalScaffold(
      title: 'Invite Members',
      icon: Icons.person_add_rounded,
      heightRatio: TrippleModalSize.mediumRatio,
      
      // TabBarを使うのでScaffold自体のスクロールはOFF
      isScrollable: false,

      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // TabBar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Search ID'),
                  Tab(text: 'QR Code'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // TabBarView
            Expanded(
              child: TabBarView(
                children: [
                  // 👇 修正1: 検索タブ自体をスクロール可能(CustomScrollView)にしたので、ここではそのまま配置
                  _buildSearchTab(),

                  // 修正2: QRタブは短いのでSingleChildScrollViewで包む
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _buildQrTab(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 👇 Search Tab (CustomScrollViewで安全対策) ---
  Widget _buildSearchTab() {
    return CustomScrollView(
      slivers: [
        // 1. 固定部分 (検索バー + タイトル)
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              Text('Quick Invite Friends', style: AppTextStyles.label),
              const SizedBox(height: 8),
            ],
          ),
        ),

        // 2. リスト部分 (読み込み中 / 空 / リスト)
        if (_friends == null)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_friends!.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false, // スクロールしない（中央寄せ）
            child: Center(child: Text('No friends found.', style: TextStyle(color: Colors.grey[400]))),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final friend = _friends![index];
                final isAlreadyMember = widget.trip.memberIds?.contains(friend.uid) ?? false;
                return ListTile(
                  contentPadding: EdgeInsets.zero, // Padding調整
                  leading: CircleAvatar(
                    backgroundImage: (friend.photoUrl != null) ? CachedNetworkImageProvider(friend.photoUrl!) : null,
                    child: (friend.photoUrl == null) ? const Icon(Icons.person) : null,
                  ),
                  title: Text(friend.displayName),
                  subtitle: Text('@${friend.customId}'),
                  trailing: isAlreadyMember
                      ? const Text('Joined', style: TextStyle(color: Colors.grey))
                      : TextButton(
                          onPressed: () => _inviteUser(friend),
                          child: const Text('Invite'),
                        ),
                );
              },
              childCount: _friends!.length,
            ),
          ),
          
        // 下部の余白確保
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // --- QR Tab ---
  Widget _buildQrTab() {
    final inviteCode = widget.trip.id;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: QrImageView(
            data: inviteCode,
            version: QrVersions.auto,
            size: 200.0,
            foregroundColor: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Let your friend scan this code',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Invite Code: $inviteCode',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
             Clipboard.setData(ClipboardData(text: inviteCode));
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
          }, 
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy Code'),
        ),
      ],
    );
  }

  // ... (招待ロジックは変更なし)
  Future<void> _inviteUser(UserProfile user) async {
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
    }
  }
}