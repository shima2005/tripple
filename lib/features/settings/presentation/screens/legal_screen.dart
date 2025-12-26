import 'package:flutter/material.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, style: AppTextStyles.h2)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          content,
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }
}

// ダミーテキスト (後でちゃんとしたものに差し替えてね)
const String kTermsOfService = """
利用規約 (Terms of Service)

1. はじめに
この利用規約（以下「本規約」）は、本アプリの利用条件を定めるものです。

2. 禁止事項
ユーザーは、本アプリの利用にあたり、以下の行為をしてはなりません。
- 法令または公序良俗に違反する行為
- 犯罪行為に関連する行為
- 本アプリのサーバーまたはネットワークの機能を破壊したり、妨害したりする行為

3. 免責事項
当方は、本アプリに事実上または法律上の瑕疵（安全性、信頼性、正確性、完全性、有効性、特定の目的への適合性、セキュリティなどに関する欠陥、エラーやバグ、権利侵害などを含みます。）がないことを明示的にも黙示的にも保証しておりません。

(以下省略)
""";

const String kPrivacyPolicy = """
プライバシーポリシー (Privacy Policy)

1. 収集する情報
本アプリは、以下の情報を取得します。
- 旅行の記録データ（場所、日時、メモ、写真URL）
- Googleアカウント情報（ログイン時のみ）

2. 利用目的
取得した情報は、以下の目的で利用します。
- 本アプリの機能提供のため
- ユーザーごとのデータ管理のため

3. 第三者提供
法令に基づく場合を除き、あらかじめユーザーの同意を得ることなく、第三者に個人情報を提供することはありません。

(以下省略)
""";