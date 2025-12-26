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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final user = FirebaseAuth.instance.currentUser;
        
        return Scaffold(
          backgroundColor: AppColors.background,
          // 👇 1. SliverAppBarをやめて、SafeArea + SingleChildScrollView の構成に変更
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // ヘッダータイトル
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      'Settings',
                      style: AppTextStyles.h1.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. プロフィール (強化版)
                  _SectionHeader(title: 'Account'),
                  if (user != null)
                    _UserProfileCard(user: user, isGuest: state.isGuest),
                  
                  const SizedBox(height: 24),

                  // 2. ソーシャル
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
                  _SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    trailing: Switch(
                      value: true, 
                      activeColor: AppColors.primary,
                      onChanged: (val) {}, 
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // 3. ホーム設定
                  _SectionHeader(title: 'My Base 🏠'),
                  Text(
                    'Set your home to exclude it from travel stats.',
                    style: AppTextStyles.label.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
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

                  // 4. システム
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
                  
                  // 5. アプリ情報
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
                  
                  // ログアウト
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
                      label: Text('Log Out', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 👇 2. アカウント削除ボタン (下線の隙間を調整)
                  Center(
                    child: TextButton(
                      onPressed: () => _showDeleteAccountDialog(context),
                      child: Container(
                        // パディングで文字と線の隙間を作る
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
                            decoration: TextDecoration.none, // デフォルトの下線は消す
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

  // --- Helpers (変更なし) ---

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text('Select Language', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('日本語'),
              leading: const Text('🇯🇵', style: TextStyle(fontSize: 24)),
              onTap: () {
                context.read<SettingsCubit>().updateLanguage(AppLanguage.japanese);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English'),
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              onTap: () {
                context.read<SettingsCubit>().updateLanguage(AppLanguage.english);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showCurrencySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text('Select Currency', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            _buildCurrencyItem(context, AppCurrency.jpy, 'JPY (¥)', '🇯🇵'),
            _buildCurrencyItem(context, AppCurrency.usd, 'USD (\$)', '🇺🇸'),
            _buildCurrencyItem(context, AppCurrency.eur, 'EUR (€)', '🇪🇺'),
            _buildCurrencyItem(context, AppCurrency.krw, 'KRW (₩)', '🇰🇷'),
            _buildCurrencyItem(context, AppCurrency.cny, 'CNY (元)', '🇨🇳'),
            const SizedBox(height: 40),
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

// --- Sub Widgets ---

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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[200],
                backgroundImage: photo != null ? CachedNetworkImageProvider(photo) : null,
                child: photo == null
                    ? const Icon(Icons.person_rounded, size: 32, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGuest ? 'Guest User' : name,
                      style: AppTextStyles.h3.copyWith(fontSize: 18),
                    ),
                    Text(id, style: AppTextStyles.label.copyWith(color: Colors.grey)),
                    
                    if (isGuest)
                      GestureDetector(
                        onTap: () {
                          context.read<SettingsCubit>().linkAccount(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, size: 16, color: AppColors.accent),
                              const SizedBox(width: 4),
                              Text('Link Account', style: AppTextStyles.label.copyWith(color: AppColors.accent, decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!isGuest)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.grey),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCode,
          hint: Text('Select Home Country', style: AppTextStyles.bodyMedium),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onChanged: onChanged,
          items: [
            const DropdownMenuItem(value: null, child: Text('None (Include all in stats)')),
            ...countries.map((c) => DropdownMenuItem(
              value: c['code'],
              child: Row(
                children: [
                  Text(c['code']!.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(c['name']!, overflow: TextOverflow.ellipsis)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Home Town (e.g. Kyoto)',
          border: InputBorder.none,
          icon: Icon(Icons.home_rounded, color: Colors.grey),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
        title: Text(title, style: AppTextStyles.bodyLarge.copyWith(fontSize: 15)),
        trailing: trailing ?? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) Text(value!, style: AppTextStyles.label.copyWith(fontSize: 13)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}