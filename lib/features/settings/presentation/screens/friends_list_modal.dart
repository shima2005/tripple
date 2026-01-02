import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/features/user/data/user_repository.dart';
import 'package:new_tripple/models/user_profile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:new_tripple/shared/widgets/common_inputs.dart';
import 'package:new_tripple/shared/widgets/tripple_empty_state.dart';
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';

class FriendsListModal extends StatefulWidget {
  const FriendsListModal({super.key});

  @override
  State<FriendsListModal> createState() => _FriendsListModalState();
}

class _FriendsListModalState extends State<FriendsListModal> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final repo = context.read<UserRepository>();

    return TrippleModalScaffold(
      title: 'Friends',
      icon: Icons.group_rounded,
      heightRatio: TrippleModalSize.mediumRatio,
      
      isScrollable: false, // Scaffold側でExpandedしてくれる

      extraHeaderActions: [
        IconButton(
          onPressed: () => _showAddFriendDialog(context),
          icon: const Icon(Icons.person_add_rounded, color: AppColors.primary),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          ),
        ),
      ],

      // 👇 修正: ここにあった Expanded を削除！ FutureBuilderを直接渡す
      child: FutureBuilder<UserProfile?>(
        future: repo.getUserProfile(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final myProfile = snapshot.data!;
          final friendIds = myProfile.friendIds;

          if (friendIds.isEmpty) {
            return const Center(
              child: TrippleEmptyState(
                title: 'Find Travel Buddies',
                message: 'Tap the "+" button above to add friends by their ID and plan trips together!',
                icon: Icons.group_add_rounded,
                accentColor: AppColors.primary,
              ),
            );
          }

          return FutureBuilder<List<UserProfile>>(
            future: repo.getUsersByIds(friendIds),
            builder: (context, friendsSnap) {
              if (!friendsSnap.hasData) return const Center(child: CircularProgressIndicator());
              final friends = friendsSnap.data!;

              return ListView.separated(
                itemCount: friends.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      backgroundImage: friend.photoUrl != null ? CachedNetworkImageProvider(friend.photoUrl!) : null,
                      child: friend.photoUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                    ),
                    title: Text(friend.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('@${friend.customId}'),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ... (Dialog部分は変更なし)
  void _showAddFriendDialog(BuildContext context) {
    // ... (省略) ...
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Add Friend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the user ID to send a friend request.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TrippleTextField(
                controller: controller,
                hintText: 'custom_id',
                suffixIcon: const Icon(Icons.alternate_email_rounded, color: Colors.grey),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: isLoading ? null : () async {
                final id = controller.text.trim();
                if (id.isEmpty) return;

                setState(() => isLoading = true);
                final repo = context.read<UserRepository>();
                final user = await repo.searchUserByCustomId(id);
                final myUid = FirebaseAuth.instance.currentUser!.uid;

                if (user != null) {
                  if (user.uid == myUid) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot add yourself')));
                  } else {
                    final myProfile = await repo.getUserProfile(myUid);
                    final myName = myProfile?.displayName ?? 'Unknown';
                    
                    await repo.sendFriendRequest(
                      toUid: user.uid,
                      fromUid: myUid,
                      fromName: myName,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request sent to ${user.displayName}!')));
                    }
                  }
                } else {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
                }
                if (context.mounted) setState(() => isLoading = false);
              },
              child: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }
}