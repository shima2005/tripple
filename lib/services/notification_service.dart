import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:new_tripple/core/theme/app_colors.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  static const int _ongoingNotificationId = 999;

  Future<void> init() async {
    tz_data.initializeTimeZones();

    try {
      // 👇 修正: 型を「String」と書かずに「final」だけで受け取り、確実に文字列化する
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName.toString()));
      
      print('Timezone set to: $timeZoneName'); 
    } catch (e) {
      print('Timezone init error: $e');
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
      } catch (e2) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    // Android設定
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS設定
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  // 🗓️ スケジュール予約通知（リマインダー）
  // ★修正: 少しリッチにするが、常時通知ほどうるさくしない
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    // Android用のスタイル設定
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trip_reminder_channel',
      'Trip Reminders',
      channelDescription: 'Notifications for trip schedule reminders',
      importance: Importance.high,
      priority: Priority.high,
      color: AppColors.primary,
      icon: '@mipmap/ic_launcher',
      
      // 👇 ここで「ちょい足し」デザイン
      styleInformation: BigTextStyleInformation(
        body, // 本文はそのまま
        
        // タイトルを少し強調
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
        
        // 右下に小さい文字でジャンルを表示（常時通知と統一感が出る）
        summaryText: 'Trip Reminder',
        htmlFormatSummaryText: false,
      ),
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title, // iOS用: プレーンなタイトル
      body,  // iOS用: プレーンな本文
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 🚀 常時表示モード
  // ★修正: iOSとAndroidでテキストを出し分ける
  Future<void> showOngoingNotification({
    required String currentStatus, // Android用 (HTML含む)
    required String nextPlan,      // Android用 (HTML含む)
    required String plainStatus,   // iOS用 (プレーンテキスト)
    required String plainPlan,     // iOS用 (プレーンテキスト)
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trip_ongoing_channel',
      'Trip Navigation',
      channelDescription: 'Persistent notification during the trip',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      color: AppColors.primary,
      icon: '@mipmap/ic_launcher',
      
      // Android: ここでHTML版を表示
      styleInformation: BigTextStyleInformation(
        nextPlan,
        htmlFormatBigText: true,
        contentTitle: currentStatus,
        htmlFormatContentTitle: true,
        summaryText: 'Travel Mode <font color="#FF9800">ON</font>',
        htmlFormatSummaryText: true,
      ),
    );

    await _notificationsPlugin.show(
      _ongoingNotificationId,
      plainStatus, // iOS: ここでプレーン版を表示
      plainPlan,   // iOS: ここでプレーン版を表示
      NotificationDetails(
        android: androidDetails, 
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelOngoingNotification() async {
    await _notificationsPlugin.cancel(_ongoingNotificationId);
  }
}