import 'package:new_tripple/models/expense_item.dart';

class Balance {
  final String userId;
  final double amount; // 正なら受け取る側、負なら払う側
  Balance({required this.userId, required this.amount});
}

class PaymentInstruction {
  final String fromUserId;
  final String toUserId;
  final double amount;
  final String currency;

  PaymentInstruction({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.currency,
  });
}

class ExpenseCalculator {
  static Map<String, List<PaymentInstruction>> calculateDebts(
    List<ExpenseItem> expenses,
    List<String> allMemberIds,
  ) {
    final Map<String, List<PaymentInstruction>> result = {};

    // 1. 通貨ごとにグループ化
    final expensesByCurrency = <String, List<ExpenseItem>>{};
    for (var e in expenses) {
      expensesByCurrency.putIfAbsent(e.currency, () => []).add(e);
    }

    // 2. 通貨ごとに計算
    expensesByCurrency.forEach((currency, list) {
      final balances = <String, double>{};
      
      // 全員0で初期化
      for (var uid in allMemberIds) {
        balances[uid] = 0.0;
      }

      for (var expense in list) {
        // A. 立て替えた人 (プラス)
        // 立て替えた額がそのままプラスになる
        balances[expense.payerId] = (balances[expense.payerId] ?? 0) + expense.amount;

        // B. 消費した人/負担すべき人 (マイナス)
        // ここで自分の分を引くことで、結果的に「立て替え - 自分の分 = 受け取る額」になる
        
        // ★修正点: share (Per Person) も equal と同じロジックで処理する
        if (expense.splitMode == SplitMode.equal || expense.splitMode == SplitMode.share) {
          if (expense.payeeIds.isNotEmpty) {
            // 合計額 ÷ 人数
            final splitAmount = expense.amount / expense.payeeIds.length;
            for (var payeeId in expense.payeeIds) {
              balances[payeeId] = (balances[payeeId] ?? 0) - splitAmount;
            }
          }
        } else if (expense.splitMode == SplitMode.custom) {
          expense.customAmounts?.forEach((uid, amount) {
            balances[uid] = (balances[uid] ?? 0) - amount;
          });
        }
      }

      // 3. 精算アクションの生成
      final instructions = <PaymentInstruction>[];
      
      // 貸しがある人(正) と 借りがある人(負)
      // 浮動小数点の誤差対策で 1円(または1単位)未満は無視する等の調整を入れても良いが、今回は0.1判定
      var receivers = balances.entries.where((e) => e.value > 0.1).toList();
      var payers = balances.entries.where((e) => e.value < -0.1).toList();

      receivers.sort((a, b) => b.value.compareTo(a.value)); // たくさん受け取る順
      payers.sort((a, b) => a.value.compareTo(b.value));    // たくさん払う順 (絶対値大)

      int rIndex = 0;
      int pIndex = 0;

      while (rIndex < receivers.length && pIndex < payers.length) {
        final receiver = receivers[rIndex];
        final payer = payers[pIndex];
        
        final receiverCanGet = receiver.value;
        final payerMustPay = -payer.value; // 正の値に直す

        // 小さい方の金額で相殺する
        final amount = receiverCanGet < payerMustPay ? receiverCanGet : payerMustPay;

        if (amount > 0) {
          instructions.add(PaymentInstruction(
            fromUserId: payer.key,
            toUserId: receiver.key,
            amount: amount,
            currency: currency,
          ));
        }

        // 残高更新処理
        // 完全に払い切ったら次の人へ
        // ※doubleの比較なので、差分が極小なら次へ進める処理を入れる
        if ((receiverCanGet - amount).abs() < 0.01) {
          rIndex++;
        } else {
          receivers[rIndex] = MapEntry(receiver.key, receiverCanGet - amount);
        }

        if ((payerMustPay - amount).abs() < 0.01) {
          pIndex++;
        } else {
          payers[pIndex] = MapEntry(payer.key, -(payerMustPay - amount));
        }
      }
      
      result[currency] = instructions;
    });

    return result;
  }
}