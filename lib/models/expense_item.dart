import 'package:cloud_firestore/cloud_firestore.dart';

enum SplitMode {
  equal,   // 均等割り
  custom,  // 個別金額指定
  share,   // 支払い担当割合 (1人分、2人分など)
}

class ExpenseItem {
  final String id;
  final String title;
  final double amount;
  final String currency; // 'JPY', 'USD', 'EUR' etc.
  final String payerId; // 支払った人のID (メンバーID or ゲストID)
  final List<String> payeeIds; // 支払い対象者のIDリスト
  final SplitMode splitMode;
  final Map<String, double>? customAmounts; // {userId: 1000, guestId: 500}
  final DateTime date;
  final String category; // 'food', 'transport', 'hotel', 'other'
  final String? linkedScheduleId; // 予算(ScheduledItem)と紐付ける場合

  const ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    this.currency = 'JPY',
    required this.payerId,
    required this.payeeIds,
    this.splitMode = SplitMode.equal,
    this.customAmounts,
    required this.date,
    this.category = 'other',
    this.linkedScheduleId,
  });

  // Firestore連携用
  factory ExpenseItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data();
    if (data == null) throw Exception("Document is empty");
    return ExpenseItem(
      id: snapshot.id,
      title: data['title'] ?? '',
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] ?? 'JPY',
      payerId: data['payerId'] ?? '',
      payeeIds: List<String>.from(data['payeeIds'] ?? []),
      splitMode: SplitMode.values.firstWhere((e) => e.name == data['splitMode'], orElse: () => SplitMode.equal),
      customAmounts: (data['customAmounts'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())),
      date: (data['date'] as Timestamp).toDate(),
      category: data['category'] ?? 'other',
      linkedScheduleId: data['linkedScheduleId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'amount': amount,
      'currency': currency,
      'payerId': payerId,
      'payeeIds': payeeIds,
      'splitMode': splitMode.name,
      'customAmounts': customAmounts,
      'date': Timestamp.fromDate(date),
      'category': category,
      'linkedScheduleId': linkedScheduleId,
    };
  }
}

// ゲスト参加者（アプリを入れてない友達など）を扱うための簡易クラス
class TripGuest {
  final String id; // UUIDなどで生成
  final String name;

  TripGuest({required this.id, required this.name});

  factory TripGuest.fromMap(Map<String, dynamic> map) => TripGuest(id: map['id'], name: map['name']);
  Map<String, dynamic> toMap() => {'id': id, 'name': name};
}