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
        // Webは既存のポップアップ方式でOK
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _firebaseAuth.signInWithPopup(authProvider);
        return userCredential.user;
      } else {
        // 📱 Mobile (v7対応)
        final googleSignIn = GoogleSignIn.instance;

        // 👇 修正ポイント1: initialize を呼ぶ
        // serverClientId は Firebase コンソールの「プロジェクトの設定」>「SDK の設定と構成」にある
        // 「Web クライアント ID」の文字列をセットしてね！これが無いと Android で idToken が空になることがある。
        await googleSignIn.initialize(
          // clientId: 'あなたのAndroidクライアントID.apps.googleusercontent.com', // 必要に応じて
          serverClientId: '1036053921134-bqb8g40mh65jmplhd8rniv7ggu71166r.apps.googleusercontent.com', 
        );

        // 👇 修正ポイント2: authenticate() で認証開始
        final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

        if (googleUser == null) return null; // キャンセル時

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // 👇 最新仕様：accessToken は null を渡し、idToken のみを使用する
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: null, 
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
        return userCredential.user;
      }
    } catch (e) {
      print('Google Sign-In Error: $e'); // ここで例外が catch されているか確認
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