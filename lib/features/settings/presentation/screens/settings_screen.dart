import 'package:flutter/cupertino.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/settings/domain/settings_cubit.dart';
import 'package:new_tripple/features/settings/domain/settings_state.dart';
import 'package:new_tripple/features/settings/presentation/screens/friends_list_modal.dart';
import 'package:new_tripple/features/settings/presentation/screens/legal_screen.dart';
import 'package:new_tripple/features/settings/presentation/screens/profile_edit_modal.dart';
import 'package:new_tripple/features/auth/data/auth_repository.dart';
import 'package:new_tripple/shared/widgets/custom_header.dart';
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final user = FirebaseAuth.instance.currentUser;
        
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const CustomHeader(title: "Settings"),

                  // 1. Account
                  _SectionHeader(title: 'Account'),
                  if (user != null)
                    _UserProfileCard(user: user, isGuest: state.isGuest),
                  
                  const SizedBox(height: 24),

                  // 2. Social (分離！)
                  // 友達リストはここへ。項目が増えても大丈夫なように独立させます。
                  _SectionHeader(title: 'Social'),
                  _SettingsTile(
                    icon: Icons.group_rounded,
                    title: 'Friends',
                    onTap: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const FriendsListModal(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Notifications (分離！)
                  _SectionHeader(title: 'Notifications'),
                  
                  // メインスイッチ
                  _SettingsTile(
                    icon: Icons.notifications_active_rounded,
                    title: 'Allow Notifications',
                    trailing: Switch(
                      value: state.isNotificationEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        context.read<SettingsCubit>().toggleNotification(val);
                      },
                    ),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [
                        // isNotificationEnabled が true の時だけ中身を表示
                        // false の時は空のColumnになり、高さが0になる → AnimatedSizeがそれをアニメーションで表現
                        if (state.isNotificationEnabled) ...[
                          _SettingsTile(
                            icon: Icons.navigation_rounded,
                            title: 'Ongoing Travel Mode',
                            trailing: Switch(
                              value: state.isOngoingNotificationEnabled,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                context.read<SettingsCubit>().toggleOngoingNotification(val);
                              },
                            ),
                          ),
                          
                          // リマインダー
                          _SettingsTile(
                            icon: Icons.alarm_rounded,
                            title: 'Schedule Reminder',
                            trailing: Switch(
                              value: state.isReminderEnabled,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                context.read<SettingsCubit>().toggleReminder(val);
                              },
                            ),
                          ),

                          // リマインダー時間
                          if (state.isReminderEnabled)
                            _SettingsTile(
                              icon: Icons.timer_outlined,
                              title: 'Remind me before...',
                              value: '${state.reminderMinutesBefore} min',
                              onTap: () => _showReminderTimePicker(context, state.reminderMinutesBefore),
                            ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. My Base
                  _SectionHeader(title: 'My Base'),
                  _CountrySelector(
                    selectedCode: state.homeCountryCode,
                    onChanged: (code) => context.read<SettingsCubit>().updateHomeCountry(code),
                  ),
                  const SizedBox(height: 12),
                  _HomeTownInput(
                    initialValue: state.homeTown,
                    onSubmitted: (value) => context.read<SettingsCubit>().updateHomeTown(value),
                  ),
                  const SizedBox(height: 24),

                  // 4. System
                  _SectionHeader(title: 'System'),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    title: 'Language',
                    value: state.language == AppLanguage.japanese ? '日本語' : 'English',
                    onTap: () => _showLanguageSelector(context),
                  ),
                  _SettingsTile(
                    icon: Icons.currency_exchange_rounded,
                    title: 'Default Currency',
                    value: state.currency.name.toUpperCase(),
                    onTap: () => _showCurrencySelector(context),
                  ),
                  const SizedBox(height: 24),
                  
                  // 5. About
                  _SectionHeader(title: 'About App'),
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LegalScreen(title: 'Terms of Service', content: kTermsOfService)),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LegalScreen(title: 'Privacy Policy', content: kPrivacyPolicy)),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.assignment_outlined,
                    title: 'Licenses',
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'tripple',
                      applicationIcon: const Icon(Icons.flight_takeoff_rounded, size: 48, color: AppColors.primary),
                      applicationLegalese: '© 2025 tripple Project',
                    ),
                  ),

                  const SizedBox(height: 40),
                  
                  // Log Out
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Log Out',
                    // 必要なら矢印を消してもいいけど、統一感重視でそのままでもOK
                    // trailing: const SizedBox.shrink(), 
                    onTap: () => _showLogoutDialog(context),
                  ),

                  // Delete Account
                  Center(
                    child: TextButton(
                      onPressed: () => _showDeleteAccountDialog(context),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 2), 
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.error.withValues(alpha: 0.7),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Text(
                          'Delete Account',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.error.withValues(alpha: 0.7),
                            fontSize: 12,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 👇 CupertinoPicker (iOS風ドラムロール) で実装
  void _showReminderTimePicker(BuildContext context, int currentMinutes) {
    // 選択肢: 1〜10分、15分、20分、30分
    final options = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30];

    // 現在の設定値がリストのどこにあるか探す (なければデフォルト15分)
    int initialIndex = options.indexOf(currentMinutes);
    if (initialIndex == -1) {
      initialIndex = options.indexOf(15);
      if (initialIndex == -1) initialIndex = 10; // 15分もなければ適当な位置へ
    }

    // スクロール中の値を保持する変数 (初期値セット)
    int tempSelectedMinutes = options[initialIndex];

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(
              height: 190,
              child: CupertinoPicker(
                backgroundColor: Colors.white,
                itemExtent: 32, // 項目の高さ
                scrollController: FixedExtentScrollController(initialItem: initialIndex),
                onSelectedItemChanged: (index) {
                  tempSelectedMinutes = options[index];
                },
                children: options.map((min) => Center(
                  child: Text(
                    '$min minutes',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                    ),
                  ),
                )).toList(),
              ),
            ),
            // Doneボタン
            CupertinoButton(
              child: const Text(
                'Done', 
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)
              ),
              onPressed: () {
                // Cubitに保存して閉じる
                context.read<SettingsCubit>().updateReminderTime(tempSelectedMinutes);
                Navigator.pop(context);
              },
            )
          ],
        ),
      ),
    );
  }

  // --- Helpers (他は変更なし) ---

  // 👇 修正: 言語選択モーダル
  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // これがないと高さ制限がかかることがあるので念のため
      builder: (context) => TrippleModalScaffold(
        title: 'Select Language',
        icon: Icons.language_rounded,
        heightRatio: TrippleModalSize.compactRatio, // 小さめでOK
        isScrollable: true, // コンテンツに合わせて縮む

        child: Column(
          children: [
            ListTile(
              title: const Text('日本語'),
              leading: const Text('🇯🇵', style: TextStyle(fontSize: 24)),
              onTap: () {
                context.read<SettingsCubit>().updateLanguage(AppLanguage.japanese);
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('English'),
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              onTap: () {
                context.read<SettingsCubit>().updateLanguage(AppLanguage.english);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 👇 修正: 通貨選択モーダル
  void _showCurrencySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TrippleModalScaffold(
        title: 'Select Currency',
        icon: Icons.currency_exchange_rounded,
        heightRatio: TrippleModalSize.mediumRatio, // 項目多めなのでMedium
        isScrollable: true, // これも縮んでOK

        child: Column(
          children: [
            _buildCurrencyItem(context, AppCurrency.jpy, 'JPY (¥)', '🇯🇵'),
            const Divider(height: 1),
            _buildCurrencyItem(context, AppCurrency.usd, 'USD (\$)', '🇺🇸'),
            const Divider(height: 1),
            _buildCurrencyItem(context, AppCurrency.eur, 'EUR (€)', '🇪🇺'),
            const Divider(height: 1),
            _buildCurrencyItem(context, AppCurrency.krw, 'KRW (₩)', '🇰🇷'),
            const Divider(height: 1),
            _buildCurrencyItem(context, AppCurrency.cny, 'CNY (元)', '🇨🇳'),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyItem(BuildContext context, AppCurrency curr, String label, String flag) {
    return ListTile(
      title: Text(label),
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      onTap: () {
        context.read<SettingsCubit>().updateCurrency(curr);
        Navigator.pop(context);
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'Your account and data will be permanently deleted. This action cannot be undone.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<AuthRepository>().deleteAccount();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete Permanently', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SettingsCubit>().logout();
            },
            child: const Text('Log Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// --- Sub Widgets (変更なし) ---

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTextStyles.label.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  final User user;
  final bool isGuest;

  const _UserProfileCard({required this.user, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final profile = state.userProfile;
        
        final name = profile?.displayName ?? user.displayName ?? 'No Name';
        final id = profile?.customId.isNotEmpty == true ? '@${profile!.customId}' : (isGuest ? 'Guest' : 'No ID set');
        final photo = profile?.photoUrl ?? user.photoURL;

        return Container(
          padding: const EdgeInsets.all(12), // 👈 16->12
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16), // 👈 20->16
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24, // 👈 30->24
                backgroundColor: Colors.grey[200],
                backgroundImage: photo != null ? CachedNetworkImageProvider(photo) : null,
                child: photo == null
                    ? const Icon(Icons.person_rounded, size: 28, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12), // 👈 16->12
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGuest ? 'Guest User' : name,
                      style: AppTextStyles.h3.copyWith(fontSize: 16), // 👈 18->16
                    ),
                    Text(id, style: AppTextStyles.label.copyWith(color: Colors.grey, fontSize: 11)), // 👈 調整
                    
                    if (isGuest)
                      GestureDetector(
                        onTap: () {
                          context.read<SettingsCubit>().linkAccount(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, size: 14, color: AppColors.accent),
                              const SizedBox(width: 4),
                              Text('Link Account', style: AppTextStyles.label.copyWith(color: AppColors.accent, decoration: TextDecoration.underline, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!isGuest)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.grey, size: 20), // 👈 アイコン小さく
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ProfileEditModal(profile: profile),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CountrySelector extends StatelessWidget {
  final String? selectedCode;
  final Function(String?) onChanged;

  const _CountrySelector({required this.selectedCode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    final countries = cubit.countryList;
    final normalizedValue = selectedCode?.toLowerCase();
    final bool valueExists = countries.any((c) => c['code']?.toLowerCase() == normalizedValue);

    return Container(
      // 👇 高さをSettingsTileに合わせるためパディング調整
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), // 👈 16->12
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valueExists ? normalizedValue : null, 
          hint: Text('Select Home Country', style: AppTextStyles.bodyMedium.copyWith(fontSize: 14)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          onChanged: onChanged,
          items: [
            const DropdownMenuItem(value: null, child: Text('None (Include all in stats)', style: TextStyle(fontSize: 14))),
            ...countries.map((c) => DropdownMenuItem(
              value: c['code']?.toLowerCase(),
              child: Row(
                children: [
                  Text(c['code']!.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(c['name']!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _HomeTownInput extends StatefulWidget {
  final String? initialValue;
  final Function(String) onSubmitted;

  const _HomeTownInput({this.initialValue, required this.onSubmitted});

  @override
  State<_HomeTownInput> createState() => _HomeTownInputState();
}

class _HomeTownInputState extends State<_HomeTownInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // 👇 高さを合わせる
      height: 48, 
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), // 👈 16->12
      child: TextField(
        controller: _controller,
        style: const TextStyle(fontSize: 14), // 👈 文字サイズ調整
        decoration: const InputDecoration(
          hintText: 'Home Town (e.g. Kyoto)',
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
          border: InputBorder.none,
          icon: Icon(Icons.home_rounded, color: Colors.grey, size: 20), // 👈 アイコンサイズ
          contentPadding: EdgeInsets.only(bottom: 2), // 位置微調整
        ),
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.title, this.value, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), // 👈 マージン縮小 12->8
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), // 👈 半径縮小 16->12
      child: ListTile(
        dense: true, // 👈 ★これで全体をコンパクトにする！
        visualDensity: const VisualDensity(vertical: -1), // 👈 さらに縦幅を詰める
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), // 👈 パディング調整
        leading: Container(
          padding: const EdgeInsets.all(6), // 👈 8->6
          decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.textPrimary, size: 18), // 👈 20->18
        ),
        title: Text(title, style: AppTextStyles.bodyLarge.copyWith(fontSize: 14)), // 👈 15->14
        trailing: trailing ?? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) Text(value!, style: AppTextStyles.label.copyWith(fontSize: 12)), // 👈 13->12
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey), // 👈 14->12
          ],
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}