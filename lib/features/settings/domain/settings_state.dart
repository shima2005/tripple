// lib/features/settings/domain/settings_state.dart

import 'package:flutter/material.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/models/user_profile.dart';

enum AppLanguage { japanese, english }
enum AppCurrency { jpy, usd, eur, krw, cny }

class SettingsState {
  final ThemeMode themeMode;
  final Color themeColor;
  final AppLanguage language;
  final String? homeCountryCode;
  final String? homeTown;
  final bool isGuest;
  final AppCurrency currency;
  final UserProfile? userProfile;

  final bool isNotificationEnabled;        // 通知マスター
  final bool isOngoingNotificationEnabled; // 常時通知
  final bool isReminderEnabled;            // リマインダー
  final int reminderMinutesBefore;         // リマインダー時間 (分)

  const SettingsState({
    this.themeMode = ThemeMode.light,
    this.themeColor = AppColors.primary,
    this.language = AppLanguage.japanese,
    this.homeCountryCode,
    this.homeTown,
    this.isGuest = false,
    this.currency = AppCurrency.jpy,
    this.userProfile,
    this.isNotificationEnabled = false, 
    this.isOngoingNotificationEnabled = true,
    this.isReminderEnabled = true,
    this.reminderMinutesBefore = 15,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Color? themeColor,
    AppLanguage? language,
    String? homeCountryCode,
    String? homeTown,
    bool? isGuest,
    AppCurrency? currency,
    UserProfile? userProfile,
    bool? isNotificationEnabled,
    bool? isOngoingNotificationEnabled,
    bool? isReminderEnabled,
    int? reminderMinutesBefore,
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
      isNotificationEnabled: isNotificationEnabled ?? this.isNotificationEnabled,
      isOngoingNotificationEnabled: isOngoingNotificationEnabled ?? this.isOngoingNotificationEnabled,
      isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
    );
  }
}