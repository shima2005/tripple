import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  // GoogleSignInはモバイルでのみ使用するため、初期化を遅延させるか、使用時にinstanceを呼ぶ
  // ここでは使用時に直接 GoogleSignIn.instance を呼び出します

  AuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  // 現在のユーザー (同期)
  User? get currentUser => _firebaseAuth.currentUser;

  // 認証状態の監視 Stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // ✨ Googleログイン (v7完全対応版)
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // 🌐 Web: Firebase Auth標準のポップアップ認証を使う (一番安定)
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        
        // ポップアップでログイン画面を出す
        final UserCredential userCredential = 
            await _firebaseAuth.signInWithPopup(authProvider);
            
        return userCredential.user;
        
      } else {
        // 📱 Mobile: google_sign_in パッケージ (v7対応) を使う
        
        // 1. シングルトンインスタンスを取得 (コンストラクタは廃止されました)
        final googleSignIn = GoogleSignIn.instance;
        
        // 2. 認証フローを開始 (signInメソッドは廃止されました)
        // authenticate() はキャンセルされると例外を投げる仕様に変わりました
        final GoogleSignInAccount? googleUser;
        try {
          googleUser = await googleSignIn.authenticate();
        } catch (e) {
          // キャンセルされた場合など
          print('Google Sign-In canceled or failed: $e');
          return null; 
        }

        // 3. 認証トークンを取得
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // 4. Firebase用のクレデンシャルを作成
        // v7以降、googleAuth.accessToken は削除されたため null を渡します。
        // idToken があればFirebase認証は成功します。
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: null, 
          idToken: googleAuth.idToken,
        );

        // 5. Firebaseにサインイン
        final UserCredential userCredential = 
            await _firebaseAuth.signInWithCredential(credential);

        return userCredential.user;
      }
    } catch (e) {
      print('Google Sign-In Error: $e');
      throw Exception('ログインに失敗しました: $e');
    }
  }

  Future<User?> signInAnonymously() async {
    try {
      final UserCredential userCredential = 
          await _firebaseAuth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      print('Anonymous Sign-In Error: $e');
      throw Exception('ゲストログインに失敗しました: $e');
    }
  }

  // ログアウト
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut(); // モバイルならGoogle側のセッションも切る
      } catch (e) {
        // 無視してOK
      }
    }
    await _firebaseAuth.signOut();
  }

  // 👇 追加: ゲストアカウントをGoogleアカウントにリンクする
  Future<User?> linkWithGoogle() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception('No user to link');

      OAuthCredential? credential;

      if (kIsWeb) {
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        final result = await user.linkWithPopup(authProvider);
        return result.user;
      } else {
        // Mobile
        final googleSignIn = GoogleSignIn.instance;
        final googleUser = await googleSignIn.authenticate(); // v7対応
        
        final googleAuth = await googleUser.authentication;
        credential = GoogleAuthProvider.credential(
          accessToken: null,
          idToken: googleAuth.idToken,
        );

        final result = await user.linkWithCredential(credential);
        return result.user;
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        throw Exception('このGoogleアカウントは既に他のユーザーで使用されています。ログアウトして切り替えてください。');
      }
      throw Exception('アカウント連携に失敗しました: ${e.message}');
    } catch (e) {
      throw Exception('エラーが発生しました: $e');
    }
  }
  // 👇 追加: アカウント削除
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception('No user found');
      
      // 本当はここでFirestoreのデータ削除などを呼ぶべきだが、
      // まずはAuthアカウント自体の削除を行う
      await user.delete(); 
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('セキュリティのため、再ログインしてから実行してください。');
      }
      throw Exception('退会処理に失敗しました: ${e.message}');
    } catch (e) {
      throw Exception('エラーが発生しました: $e');
    }
  }

  // 👇 追加: プロフィール更新
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      // 変更をアプリに即座に反映させるためリロード
      await user.reload();
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }
}