import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_tripple/features/user/data/user_repository.dart';
import 'package:new_tripple/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/features/settings/domain/settings_state.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/utils/country_converter.dart'; // 既存のコンバータ活用
import 'package:new_tripple/features/auth/data/auth_repository.dart';
import 'package:new_tripple/services/notification_service.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final UserRepository _userRepository;
  StreamSubscription<User?>? _authSubscription;

  SettingsCubit({
    required UserRepository userRepository,
  }) : _userRepository = userRepository,
       super(const SettingsState()) {
    
    _detectAndApplyDeviceSettings();
    // 👇 修正: 起動時だけでなく、ログイン状態の変化をずっと監視する
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _handleAuthChange(user);
    });
  }

  void _detectAndApplyDeviceSettings() {
    try {
      final locale = Platform.localeName; // 例: ja_JP, en_US
      
      AppLanguage detectedLang = AppLanguage.english;
      AppCurrency detectedCurr = AppCurrency.usd;
      String? detectedCountry;

      if (locale.startsWith('ja')) {
        detectedLang = AppLanguage.japanese;
        detectedCurr = AppCurrency.jpy;
        detectedCountry = 'jp';
      } else {
        // 簡易判定 (必要に応じて詳しく分岐可能)
        detectedLang = AppLanguage.english;
        detectedCurr = AppCurrency.usd;
        if (locale.contains('_US')) detectedCountry = 'us';
      }

      emit(state.copyWith(
        language: detectedLang,
        currency: detectedCurr,
        homeCountryCode: detectedCountry,
      ));
    } catch (e) {
      print('Auto-detect settings error: $e');
    }
  }

  Future<void> _handleAuthChange(User? user) async {
    if (user == null) {
      // ログアウト時はゲスト扱い＆設定はそのまま(またはリセット)
      emit(state.copyWith(userProfile: null, isGuest: true));
    } else {
      final isGuest = user.isAnonymous;
      UserProfile? profile;

      if (!isGuest) {
        // ログインユーザーならFirestoreから設定を取得して上書き！
        profile = await _userRepository.getUserProfile(user.uid);
        
        if (profile != null) {
          emit(state.copyWith(
            userProfile: profile,
            isGuest: false,
            // 👇 プロフィールの設定をStateに反映 (nullなら今のまま)
            homeCountryCode: profile.homeCountry ?? state.homeCountryCode,
            homeTown: profile.homeTown ?? state.homeTown,
            language: profile.language != null ? _parseLanguage(profile.language) : state.language,
            currency: profile.currency != null ? _parseCurrency(profile.currency) : state.currency,
          ));
        } else {
          // プロフィール未作成の場合 (初回登録直後など)
          emit(state.copyWith(isGuest: false));
        }
      } else {
        emit(state.copyWith(isGuest: true));
      }
    }
  }

  // 国リストのキャッシュ
  List<Map<String, String>> _countryList = [];
  List<Map<String, String>> get countryList => _countryList;

  // 🔄 初期化: 設定の読み込み
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    final colorValue = prefs.getInt('themeColor');
    final countryCode = prefs.getString('homeCountry');
    final town = prefs.getString('homeTown');
    final modeIndex = prefs.getInt('themeMode') ?? 1;
    final langIndex = prefs.getInt('language') ?? 0;
    final currIndex = prefs.getInt('currency') ?? 0;

    // 👇 通知設定の読み込み
    final notify = prefs.getBool('isNotificationEnabled') ?? false;
    final ongoing = prefs.getBool('isOngoingNotificationEnabled') ?? true;
    final reminder = prefs.getBool('isReminderEnabled') ?? true;
    final minutes = prefs.getInt('reminderMinutesBefore') ?? 15;
    
    await _loadCountriesFromAsset();

    emit(state.copyWith(
      themeColor: colorValue != null ? Color(colorValue) : AppColors.primary,
      homeCountryCode: countryCode,
      homeTown: town,
      isGuest: user?.isAnonymous ?? true,
      themeMode: ThemeMode.values[modeIndex],
      language: AppLanguage.values[langIndex],
      currency: AppCurrency.values[currIndex],
      // 👇 反映
      isNotificationEnabled: notify,
      isOngoingNotificationEnabled: ongoing,
      isReminderEnabled: reminder,
      reminderMinutesBefore: minutes,
    ));
  }
  //プロフィール更新
  Future<void> updateUserProfile(UserProfile newProfile) async {
    try {
      await _userRepository.saveUserProfile(newProfile);
      // State更新 (再取得せず直接セットして高速化)
      emit(state.copyWith(userProfile: newProfile, isGuest: false));
    } catch (e) {
      print('Profile update error: $e');
    }
  }

  Future<void> updateHomeCountry(String? code) async {
    emit(state.copyWith(homeCountryCode: code));
    await _syncToProfile(homeCountry: code);
  }

  Future<void> updateHomeTown(String city) async {
    emit(state.copyWith(homeTown: city));
    await _syncToProfile(homeTown: city);
  }

  Future<void> updateLanguage(AppLanguage lang) async {
    emit(state.copyWith(language: lang));
    final code = lang == AppLanguage.japanese ? 'ja' : 'en';
    await _syncToProfile(language: code);
  }

  Future<void> updateCurrency(AppCurrency curr) async {
    emit(state.copyWith(currency: curr));
    final code = curr.name.toLowerCase(); // jpy, usd...
    await _syncToProfile(currency: code);
  }

  // 🔄 共通同期メソッド
  Future<void> _syncToProfile({
    String? homeCountry,
    String? homeTown,
    String? language,
    String? currency,
  }) async {
    final profile = state.userProfile;
    if (profile == null) return; // ゲストや未ロード時はスキップ

    // 変更点だけ更新した新しいプロフィールを作成
    // ※引数がnullの場合は「変更なし」とみなして現在のprofileの値を使うロジックにする
    // (引数で明示的にnullを渡して消去したい場合は別ロジックが必要ですが、今回は上書きのみ想定)
    
    final updatedProfile = profile.copyWith(
      homeCountry: homeCountry ?? profile.homeCountry,
      homeTown: homeTown ?? profile.homeTown,
      language: language ?? profile.language,
      currency: currency ?? profile.currency,
    );

    // 楽観的更新
    emit(state.copyWith(userProfile: updatedProfile));

    try {
      await _userRepository.saveUserProfile(updatedProfile);
    } catch (e) {
      print('Sync settings error: $e');
      // 失敗したらロールバックする処理を入れるとより親切
    }
  }


  // 👇 追加: アカウント連携
  Future<void> linkAccount(BuildContext context) async {
    try {
      final authRepo = RepositoryProvider.of<AuthRepository>(context);
      await authRepo.linkWithGoogle();
      
      // 成功したら画面を更新（ゲストフラグを外す）
      final user = FirebaseAuth.instance.currentUser;
      emit(state.copyWith(isGuest: user?.isAnonymous ?? true));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account linked successfully! 🎉 Data saved.')),//TODO
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))), // エラー表示
      );
    }
  }

  // 内部: GeoJSONから国名とコードのリストを作る
  Future<void> _loadCountriesFromAsset() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/geo/countries.geo.json');
      final data = json.decode(jsonString);
      final features = data['features'] as List;

      final Set<String> uniqueCodes = {};
      final List<Map<String, String>> countries = [];

      for (var feature in features) {
        final String? alpha3 = feature['id'] as String?;
        final String? name = feature['properties']['name'] as String?;
        
        if (alpha3 != null && name != null) {
          final alpha2 = CountryConverter.toAlpha2(alpha3); // 3文字->2文字変換
          if (alpha2 != null && !uniqueCodes.contains(alpha2)) {
            uniqueCodes.add(alpha2);
            countries.add({'code': alpha2, 'name': name});
          }
        }
      }
      
      // 名前順にソート
      countries.sort((a, b) => a['name']!.compareTo(b['name']!));
      _countryList = countries;
      
    } catch (e) {
      print('Settings: Failed to load countries: $e');
    }
  }
  Future<void> updateThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    // 0: system, 1: light, 2: dark とマッピングして保存すると良い
    await prefs.setInt('themeMode', mode.index); 
    emit(state.copyWith(themeMode: mode));
  }

  // 👇 通知設定の更新メソッド群
  Future<void> toggleNotification(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isNotificationEnabled', isEnabled);
    
    if (isEnabled) {
      // ONにしたタイミングで権限リクエスト
      await NotificationService().requestPermissions();
    }
    emit(state.copyWith(isNotificationEnabled: isEnabled));
  }

  Future<void> toggleOngoingNotification(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOngoingNotificationEnabled', isEnabled);
    emit(state.copyWith(isOngoingNotificationEnabled: isEnabled));
  }

  Future<void> toggleReminder(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isReminderEnabled', isEnabled);
    emit(state.copyWith(isReminderEnabled: isEnabled));
  }

  Future<void> updateReminderTime(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminderMinutesBefore', minutes);
    emit(state.copyWith(reminderMinutesBefore: minutes));
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel(); // 監視終了
    return super.close();
  }
  
  // ログアウト機能
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    // _handleAuthChange が自動で呼ばれて state が更新される
  }
}

AppLanguage _parseLanguage(String? code) {
  if (code == 'ja') return AppLanguage.japanese;
  return AppLanguage.english; // デフォルト
}

AppCurrency _parseCurrency(String? code) {
  if (code == 'jpy') return AppCurrency.jpy;
  if (code == 'usd') return AppCurrency.usd;
  if (code == 'eur') return AppCurrency.eur;
  if (code == 'krw') return AppCurrency.krw;
  if (code == 'cny') return AppCurrency.cny;
  return AppCurrency.usd; // デフォルト
}