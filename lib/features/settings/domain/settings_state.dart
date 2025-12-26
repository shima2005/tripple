import 'package:flutter/material.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/models/user_profile.dart';

enum AppLanguage { japanese, english }
enum AppCurrency { jpy, usd, eur, krw, cny }

class SettingsState {
  final ThemeMode themeMode;
  final Color themeColor; // 選択されたテーマカラー
  final AppLanguage language;
  final String? homeCountryCode; // ホームカントリー (ISO 2文字)
  final String? homeTown;        // ホームタウン (テキスト)
  final bool isGuest;            // ゲストかどうか
  final AppCurrency currency;
  final UserProfile? userProfile;

  const SettingsState({
    this.themeMode = ThemeMode.light,
    this.themeColor = AppColors.primary,
    this.language = AppLanguage.japanese,
    this.homeCountryCode,
    this.homeTown,
    this.isGuest = false,
    this.currency = AppCurrency.jpy,
    this.userProfile
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Color? themeColor,
    AppLanguage? language,
    String? homeCountryCode,
    String? homeTown,
    bool? isGuest,
    AppCurrency? currency,
    UserProfile? userProfile
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      language: language ?? this.language,
      homeCountryCode: homeCountryCode ?? this.homeCountryCode,
      homeTown: homeTown ?? this.homeTown,
      isGuest: isGuest ?? this.isGuest,
      currency: currency ?? this.currency,
      userProfile: userProfile ?? this.userProfile,
    );
  }
}