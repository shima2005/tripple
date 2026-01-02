import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/features/trip/data/trip_repository.dart';
import 'package:new_tripple/features/user/data/user_repository.dart';
import 'package:new_tripple/models/user_profile.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/shared/widgets/tripple_empty_state.dart';
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';

class InboxModal extends StatelessWidget {
  const InboxModal({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    final userRepo = context.read<UserRepository>();
    final tripRepo = context.read<TripRepository>();

    return TrippleModalScaffold(
      title: 'Inbox',
      icon: Icons.notifications_rounded,
      heightRatio: TrippleModalSize.mediumRatio,
      
      isScrollable: false, 

      // 👇 修正: ここにあった Expanded を削除！
      child: StreamBuilder<List<AppNotification>>(
        stream: userRepo.getNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data ?? [];
          
          if (notifications.isEmpty) {
            return const Center(
              child: TrippleEmptyState(
                title: 'No Notifications',
                message: "You're all caught up! We'll let you know when something happens.",
                icon: Icons.notifications_none_rounded,
                accentColor: Colors.orange,
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
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
                        if (notif.type == NotificationType.tripInvite) {
                          await tripRepo.joinTrip(notif.tripId!, userId);
                          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined trip!')));
                        } else {
                          await userRepo.acceptFriendRequest(userId, notif.fromUid);
                          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend added!')));
                        }
                        await userRepo.deleteNotification(userId, notif.id);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.grey),
                      onPressed: () async {
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
    );
  }
}