import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Web判定用

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// 画像を選択してアップロードし、ダウンロードURLを返す
  Future<String?> pickAndUploadImage({required String folder}) async {
    try {
      // 1. 画像を選択
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, 
      );

      if (image == null) return null;

      // 2. 保存先のパス
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('$folder/$fileName');

      // 3. アップロード (プラットフォーム別対応)
      if (kIsWeb) {
        // 🌐 Web: bytesデータとしてアップロード
        final data = await image.readAsBytes();
        await ref.putData(data, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        // 📱 Mobile: ファイルパスからアップロード
        final file = File(image.path);
        await ref.putFile(file);
      }

      // 4. URLを取得
      final String downloadUrl = await ref.getDownloadURL();
      return downloadUrl;

    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }
}