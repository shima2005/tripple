import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/enums.dart';
import 'package:image_picker/image_picker.dart';

// 👇 ホテル情報の受け渡し用クラス
class AccommodationRequest {
  final int dayIndex; // 何日目の夜か (0始まり)
  final String name; // ホテル名またはエリア名
  AccommodationRequest({required this.dayIndex, required this.name});
}

class GeminiService {
  // ⚠️ APIキーは安全に管理！
  static const String _apiKey = 'AIzaSyDolCnVMwJEDFTPFcvaUQmd_V9m1rhV4hY';

  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash', 
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 1.0, 
      ),
    );
  }

  Future<List<ScheduledItem>> createInitialTripPlan({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> mustVisitPlaces,
    List<String> excludedPlaces = const [],
    List<DateTime> freeDates = const [],
    String transportType = 'public_transport',
    bool autoSuggest = true,
    // 👇 追加パラメータ
    String tripStyle = 'balanced', // relaxed, packed, history, food...
    List<AccommodationRequest> accommodations = const [],
    String? startLocation, // 初日の出発地
    String? startTime,     // 初日の出発時刻 (HH:mm)
    String? endLocation,   // 最終日の到着地
    String? endTime,       // 最終日の到着リミット (HH:mm)
  }) async {
    
    final days = endDate.difference(startDate).inDays + 1;
    final freeDateStrings = freeDates.map((d) => DateFormat('yyyy-MM-dd').format(d)).join(', ');
    
    // ホテル情報の整理
    String hotelInfo = "宿泊先は、具体的なホテル名ではなく「京都駅周辺」「祇園エリア」のような大まかなエリアで提案してください。";
    if (accommodations.isNotEmpty) {
      hotelInfo = "以下の宿泊先（エリア）を考慮してスケジュールを組んでください:\n";
      for (var acc in accommodations) {
        hotelInfo += "- ${acc.dayIndex + 1}日目の夜: ${acc.name}\n";
      }
    }

    // 発着情報の整理
    String startEndInfo = "";
    if (startLocation != null) startEndInfo += "- 初日は '$startLocation' を $startTime 頃に出発します。\n";
    if (endLocation != null) startEndInfo += "- 最終日は '$endLocation' に $endTime 頃に到着するようにしてください。\n";

    final prompt = '''
あなたはプロの旅行プランナーです。以下の条件で旅行プラン（滞在スケジュール）を作成し、JSONリストで出力してください。

【基本条件】
- 行き先: $destination
- 期間: ${DateFormat('yyyy-MM-dd').format(startDate)} から ${DateFormat('yyyy-MM-dd').format(endDate)} まで ($days 日間)
- 移動手段: $transportType
- 旅行スタイル: $tripStyle (これに合わせてペース配分やスポット選定を行ってください)

【指定条件】
- 必須の訪問場所: ${mustVisitPlaces.join(', ')} (優先的に組み込んでください)
- 除外する場所: ${excludedPlaces.join(', ')} (絶対に含めないでください)
- 以下の日付は「自由行動日」とし、予定を入れないでください: [$freeDateStrings]
- $startEndInfo
- $hotelInfo

【AIへの指示】
- ${autoSuggest ? '必須場所だけでは時間が余る場合、旅行スタイル($tripStyle)に合ったおすすめスポットを追加して時間を埋めてください。' : '必須の場所のみで構成し、無理な追加はしないでください。'}
- 宿泊先が決まっている場合は、その日の最後の予定終了後にそこへ向かうことを考慮してください。また、チェックイン等以外の宿泊先の予定（要は普通に泊まって寝るとき）は日付をまたいで時間を設定してください。例えば、start_timeを19:00、durationを14時間にすれば翌日の朝9時に出発できます。
- 施設の営業時間や定休日を考慮してください。
- 指定された開始地点(一番最初の'$startLocation')の前、および到着地点(一番最後の'$endLocation')の後には予定を入れないでください。すなわちかならず一番最初が'$startLocation'、一番最後が'$endLocation'で終わるようにしてください。
- 指定された移動手段に基づいて、各スケジュールの開始時間を移動時間分ずらして調整してください。また、各スケジュール間に最低でも1分は移動時間を持たせてください。
- **「移動（〜へ移動、電車に乗るなど）」はスケジュールに絶対含めないでください。


【出力JSONフォーマット】
[
  {
    "day_offset": 0, // 初日を0とする
    "start_time": "10:00", // 推奨開始時刻
    "name": "スポット名",
    "description": "説明(30文字以内)",
    "category": "sightseeing", // sightseeing, food, leisure, shopping, accommodation(ホテル), other
    "duration": 90, // 滞在時間(分)
    "lat": 35.1234,
    "lng": 135.1234
  },
  ...
]
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;

      print(responseText);

      if (responseText == null) throw Exception('No response');

      final List<dynamic> jsonList = json.decode(responseText);
      final List<ScheduledItem> items = [];

      for (var item in jsonList) {
        final int dayOffset = item['day_offset'];
        final itemDate = startDate.add(Duration(days: dayOffset));
        
        // 自由行動日のスキップ
        if (freeDates.any((free) => 
            free.year == itemDate.year && 
            free.month == itemDate.month && 
            free.day == itemDate.day)) {
          continue; 
        }

        final timeParts = (item['start_time'] as String).split(':');
        final itemDateTime = DateTime(
          itemDate.year, itemDate.month, itemDate.day,
          int.parse(timeParts[0]), int.parse(timeParts[1]),
        );

        ItemCategory category;
        switch (item['category']) {
          case 'sightseeing': category = ItemCategory.sightseeing; break;
          case 'food': category = ItemCategory.food; break;
          case 'leisure': category = ItemCategory.leisure; break;
          case 'shopping': category = ItemCategory.shopping; break;
          case 'accommodation': category = ItemCategory.accommodation; break;
          default: category = ItemCategory.other;
        }

        items.add(ScheduledItem(
          id: '',
          dayIndex: dayOffset,
          time: itemDateTime,
          name: item['name'],
          notes: item['description'],
          category: category,
          durationMinutes: item['duration'],
          latitude: (item['lat'] as num?)?.toDouble(),
          longitude: (item['lng'] as num?)?.toDouble(),
        ));
      }
      
      return items;

    } catch (e) {
      print('Gemini Error: $e');
      throw Exception('AIプラン作成失敗: $e');
    }
  }

  /// 2. 日程の最適化 & 提案
  Future<List<ScheduledItem>> optimizeDailySchedule({
    required List<ScheduledItem> currentItems,
    required DateTime date,
    required int dayIndex,
    required String destination,
    bool allowSuggestions = false,
  }) async {
    
    final itemsJson = currentItems.map((i) => {
      "name": i.name,
      "is_fixed": i.isTimeFixed,
      "time": DateFormat('HH:mm').format(i.time),
      "duration": i.durationMinutes,
      "category": i.category.name,
    }).toList();

    final prompt = '''
あなたは旅行プランナーです。ある1日のスケジュールを最適化してください。

【コンテキスト】
- 日付: ${DateFormat('yyyy-MM-dd').format(date)}
- エリア: $destination
- 現在の予定リスト: ${jsonEncode(itemsJson)}

【重要ルール: 固定予定の扱い】
- **"is_fixed": true のアイテムは、開始時刻("time")を絶対に変更しないでください。** これらは「アンカー（予約済み/約束あり）」として扱います。
- "is_fixed": false のアイテムは、アンカー以外の空き時間に、移動効率と営業時間を考慮して配置してください。
- どうしても時間が被る場合は、"is_fixed": false のアイテムを削除するか、時間を短縮してください。

【その他の指示】
1. **ルート最適化**: 固定された予定の間を縫うように、移動ロスが少ない順序に並べ替えてください。
2. ${allowSuggestions ? '**スポット追加**: スケジュールに「2時間以上の空き」がある場合、あるいはあきらかにスポットにいる時間が長すぎる場合、その場所・時間帯に適したおすすめスポットを追加して埋めてください。' : '**追加禁止**: 新しいスポットは追加せず、既存のリストのみを使用してください。'}
3. **時間調整**:
   - 各スポットの標準的な滞在時間を確保してください。
   - 移動時間を考慮して開始時刻を決定してください。
   - **施設の営業時間や、その場所に行くのに適した時間帯（ランチ、夕景など）を必ず考慮してください。**
4.dayIndex: . この値が0の場合は一番最初のアイテムの開始時間を変えないでください。
5.最後のアイテムが空港、駅、自宅など、旅の終わりだと思われる場合、終了時間をできるだけ変えないでください。

【出力JSONフォーマット】
[
  {
    "name": "スポット名",
    "start_time": "10:00", // 固定アイテムは元のまま、他は最適化
    "description": "説明",
    "category": "sightseeing",
    "duration": 90,
    "lat": 35.1234,
    "lng": 135.1234
  },
  ...
]
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;
      if (responseText == null) throw Exception('No response');

      final List<dynamic> jsonList = json.decode(responseText);
      final List<ScheduledItem> optimizedList = [];

      for (var item in jsonList) {
        // 時刻パース
        final timeParts = (item['start_time'] as String).split(':');
        final itemTime = DateTime(
          date.year, date.month, date.day,
          int.parse(timeParts[0]), int.parse(timeParts[1]),
        );

        // 既存アイテムとのマッチング (名前で突合)
        // IDや画像URLを引き継ぐため
        ScheduledItem? originalItem;
        try {
           originalItem = currentItems.firstWhere((i) => i.name == item['name']);
        } catch (_) {
           originalItem = null;
        }

        // カテゴリ変換
        ItemCategory category;
        if (originalItem != null) {
          category = originalItem.category;
        } else {
          switch (item['category']) {
            case 'sightseeing': category = ItemCategory.sightseeing; break;
            case 'food': category = ItemCategory.food; break;
            case 'leisure': category = ItemCategory.leisure; break;
            case 'shopping': category = ItemCategory.shopping; break;
            case 'accommodation': category = ItemCategory.accommodation; break;
            default: category = ItemCategory.other;
          }
        }

        optimizedList.add(ScheduledItem(
          // 既存ならID維持、新規なら空文字(Repositoryで生成)
          id: originalItem?.id ?? '', 
          dayIndex: originalItem?.dayIndex ?? 0, // 呼び出し元で再設定するので0でOK
          time: itemTime,
          name: item['name'],
          notes: originalItem != null ? originalItem.notes : item['description'],
          category: category,
          durationMinutes: item['duration'],
          latitude: (item['lat'] as num?)?.toDouble() ?? originalItem?.latitude,
          longitude: (item['lng'] as num?)?.toDouble() ?? originalItem?.longitude,
          isTimeFixed: originalItem?.isTimeFixed ?? false,
          imageUrl: originalItem?.imageUrl, // 画像を引き継ぐ
        ));
      }
      
      return optimizedList;

    } catch (e) {
      print('Gemini Optimize Error: $e');
      throw Exception('最適化に失敗しました: $e');
    }
  }

  /// 3. 次のスポット提案 (単発)
  Future<List<ScheduledItem>> suggestSpots({
    required ScheduledItem? lastItem, // 直前の予定 (なければnull)
    required DateTime targetDate,
    required String destination,
    required int count,
    required String userRequest, // "静かなカフェ" "こってりラーメン" etc
  }) async {
    
    String contextInfo = "エリア: $destination\n日付: ${DateFormat('yyyy-MM-dd').format(targetDate)}";
    if (lastItem != null) {
      contextInfo += "\n直前の予定: ${lastItem.name} (${DateFormat('HH:mm').format(lastItem.time)} 終了想定)";
      if (lastItem.latitude != null) {
        contextInfo += "\n現在地座標: ${lastItem.latitude}, ${lastItem.longitude}";
      }
    } else {
      contextInfo += "\n(この日の最初の予定です)";
    }

    final prompt = '''
あなたは現地の旅行ガイドです。ユーザーの要望に合わせて、次に訪れるべきスポットを提案してください。

【コンテキスト】
$contextInfo

【ユーザーの要望】
"$userRequest"

【指示】
- 上記の要望に合致するスポットを **$count 個** 提案してください。
- 直前の予定がある場合は、そこからの移動が現実的な場所を選んでください。
- 開始時刻は、直前の予定終了後（または朝10:00）を想定してください。
- **実在する、営業している可能性が高い店舗・スポットのみを提案してください。**
- 架空の店名や、すでに閉店した店は提案しないでください。

【出力JSONフォーマット】
[
  {
    "name": "スポット名",
    "description": "提案理由と魅力（50文字程度で魅力的に！）",
    "category": "food", // sightseeing, food, leisure, shopping, other
    "duration": 60, // 推奨滞在時間(分)
    "lat": 35.1234,
    "lng": 135.1234
  },
  ...
]
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;
      if (responseText == null) throw Exception('No response');

      final List<dynamic> jsonList = json.decode(responseText);
      final List<ScheduledItem> suggestions = [];

      for (var item in jsonList) {
        // 時刻は仮（Cubitで計算するが、一応Dateを持たせる）
        final dummyTime = targetDate; // 仮

        ItemCategory category;
        switch (item['category']) {
          case 'sightseeing': category = ItemCategory.sightseeing; break;
          case 'food': category = ItemCategory.food; break;
          case 'leisure': category = ItemCategory.leisure; break;
          case 'shopping': category = ItemCategory.shopping; break;
          default: category = ItemCategory.other;
        }

        suggestions.add(ScheduledItem(
          id: '', // 保存時に生成
          dayIndex: 0, // 呼び出し元で調整
          time: dummyTime,
          name: item['name'],
          notes: item['description'], // ここに提案理由が入る
          category: category,
          durationMinutes: item['duration'],
          latitude: (item['lat'] as num?)?.toDouble(),
          longitude: (item['lng'] as num?)?.toDouble(),
        ));
      }
      return suggestions;

    } catch (e) {
      print('Gemini Suggest Error: $e');
      throw Exception('提案に失敗しました: $e');
    }
  }

  /// 4. 画像/テキストから予約情報を抽出 (マルチモーダル)
  Future<Map<String, dynamic>> extractFromImageOrText({
    XFile? image,
    String? text,
  }) async {
    if (image == null && text == null) throw Exception('Image or text is required');

    final promptText = '''
あなたは旅行アシスタントです。入力された予約情報（スクショまたはテキスト）を解析し、以下のJSONフォーマットで出力してください。

【判定ルール】
- **type**: 
  - ホテル、レストラン、観光スポット、アクティビティ → "stay"
  - 飛行機、電車、バス、船、レンタカー → "transport"

【出力JSONスキーマ】
{
  "type": "stay" or "transport",
  "title": "ホテル名 または 便名/路線名",
  "start_time": "YYYY-MM-DD HH:MM", (不明ならnull)
  "end_time": "YYYY-MM-DD HH:MM", (不明ならnull)
  "location": "場所の名前/住所" (stayの場合),
  "origin": "出発地" (transportの場合),
  "destination": "到着地" (transportの場合),
  "memo": "予約番号、座席番号、その他の重要なメモ",
  "cost": 10000 (数値、不明なら0)
}

※ 日付の年は、現在または近い未来（${DateTime.now().year}年）を補完してください。
''';

    final contentParts = <Part>[TextPart(promptText)];

    // 画像がある場合
    if (image != null) {
      final bytes = await image.readAsBytes();
      contentParts.add(DataPart('image/jpeg', bytes)); // 形式はjpeg決め打ちで大体いけます
    }
    // テキストがある場合
    if (text != null) {
      contentParts.add(TextPart("\n\n【入力テキスト】\n$text"));
    }

    try {
      final response = await _model.generateContent([Content.multi(contentParts)]);
      final responseText = response.text;
      if (responseText == null) throw Exception('No response');

      // JSON部分だけ抽出 (Markdownの ```json ... ``` を除去)
      final cleanJson = responseText.replaceAll(RegExp(r'^```json\s*|\s*```$'), '');
      return json.decode(cleanJson) as Map<String, dynamic>;

    } catch (e) {
      print('Extract Error: $e');
      throw Exception('読み取りに失敗しました。');
    }
  }
}
