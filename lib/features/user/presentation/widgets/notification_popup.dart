import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/features/trip/data/trip_repository.dart';
import 'package:new_tripple/features/user/data/user_repository.dart';
import 'package:new_tripple/models/user_profile.dart';
import 'package:new_tripple/core/theme/app_colors.dart';

class NotificationPopup extends StatelessWidget {
  final VoidCallback onClose;

  const NotificationPopup({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    final userRepo = context.read<UserRepository>();
    final tripRepo = context.read<TripRepository>();

    return Material(
      color: Colors.transparent,
      elevation: 8,
      child: Container(
        width: 320, // 固定幅
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(Icons.close, size: 20, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // List
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: userRepo.getNotifications(userId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final notifications = snapshot.data!;

                  if (notifications.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No notifications', style: TextStyle(color: Colors.grey))),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return _buildNotificationItem(context, notif, userRepo, tripRepo, userId);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context, 
    AppNotification notif, 
    UserRepository userRepo, 
    TripRepository tripRepo,
    String myUid,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          CircleAvatar(
            radius: 18,
            backgroundColor: notif.type == NotificationType.tripInvite ? AppColors.primary.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            child: Icon(
              notif.type == NotificationType.tripInvite ? Icons.flight_rounded : Icons.person_add_rounded,
              size: 18,
              color: notif.type == NotificationType.tripInvite ? AppColors.primary : Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black, fontSize: 13),
                    children: [
                      TextSpan(text: '${notif.fromName} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (notif.type == NotificationType.tripInvite) ...[
                        const TextSpan(text: 'invited you to '),
                        TextSpan(text: notif.tripName ?? 'Trip', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ] else ...[
                        const TextSpan(text: 'sent a friend request.'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => userRepo.deleteNotification(myUid, notif.id),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Decline', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          try {
                            if (notif.type == NotificationType.tripInvite) {
                              await tripRepo.joinTrip(notif.tripId!, myUid);
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined trip!')));
                            } else {
                              await userRepo.acceptFriendRequest(myUid, notif.fromUid);
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend added!')));
                            }
                            await userRepo.deleteNotification(myUid, notif.id);
                          } catch (e) {
                            // 👇 エラー内容を表示して原因特定
                            print(e);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Accept', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}