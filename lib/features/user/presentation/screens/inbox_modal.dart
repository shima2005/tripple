import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/features/trip/data/trip_repository.dart';
import 'package:new_tripple/features/user/data/user_repository.dart';
import 'package:new_tripple/models/user_profile.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/shared/widgets/tripple_empty_state.dart';

class InboxModal extends StatelessWidget {
  const InboxModal({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    final userRepo = context.read<UserRepository>();
    final tripRepo = context.read<TripRepository>();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inbox', style: AppTextStyles.h2),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: userRepo.getNotifications(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notifications = snapshot.data ?? [];
                
                if (notifications.isEmpty) {
                // 👇 ここを差し替え
                  return const TrippleEmptyState(
                    title: 'No Notifications',
                    message: "You're all caught up! We'll let you know when something happens.",
                    icon: Icons.notifications_none_rounded,
                    accentColor: Colors.orange, // 通知っぽい色に
                  );
                }

                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (c, i) => const Divider(),
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: notif.type == NotificationType.tripInvite 
                            ? AppColors.primary.withOpacity(0.1) 
                            : Colors.orange.withOpacity(0.1),
                        child: Icon(
                          notif.type == NotificationType.tripInvite ? Icons.flight : Icons.person_add,
                          color: notif.type == NotificationType.tripInvite ? AppColors.primary : Colors.orange,
                        ),
                      ),
                      title: Text(notif.type == NotificationType.tripInvite ? 'Trip Invite' : 'Friend Request', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(notif.type == NotificationType.tripInvite 
                          ? '${notif.fromName} invited you to "${notif.tripName}"'
                          : '${notif.fromName} wants to be friends'
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: AppColors.accent),
                            onPressed: () async {
                              // 承諾処理
                              if (notif.type == NotificationType.tripInvite) {
                                await tripRepo.joinTrip(notif.tripId!, userId);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined trip!')));
                              } else {
                                await userRepo.acceptFriendRequest(userId, notif.fromUid);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend added!')));
                              }
                              // 通知削除
                              await userRepo.deleteNotification(userId, notif.id);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.grey),
                            onPressed: () async {
                              // 拒否（削除のみ）
                              await userRepo.deleteNotification(userId, notif.id);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}