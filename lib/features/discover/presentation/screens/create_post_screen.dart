import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart'; // 👈 プレビュー用に必要
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/discover/domain/discover_cubit.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/features/trip/domain/trip_state.dart';
import 'package:new_tripple/models/post.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/services/storage_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:new_tripple/shared/widgets/tripple_toast.dart'; // 👈 画像表示に必要

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _locationController = TextEditingController();
  final _tagController = TextEditingController();
  
  Trip? _selectedTrip;
  List<String> _tags = [];
  
  String? _headerImageUrl;
  bool _isUploading = false;
  
  // 👇 追加: プレビューモード管理フラグ
  bool _isPreviewMode = false;

  final _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      context.read<TripCubit>().loadMyTrips();
    }
  }

  // ... (画像アップロードや挿入ロジックはそのまま維持) ...
  Future<void> _pickAndInsertBodyImage() async {
    setState(() => _isUploading = true);
    final url = await _storageService.pickAndUploadImage(folder: 'post_images');
    if (url != null) {
      _insertTextAtCursor('\n![]($url)\n');
      if (_headerImageUrl == null) {
        setState(() => _headerImageUrl = url);
      }
    }
    setState(() => _isUploading = false);
  }

  void _insertTextAtCursor(String textToInsert, {int selectionOffset = 0}) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, textToInsert);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + textToInsert.length + selectionOffset),
    );
  }
  
  // ヘッダー画像選択
  Future<void> _pickImage() async {
    setState(() => _isUploading = true);
    final url = await _storageService.pickAndUploadImage(folder: 'post_images');
    if (url != null) {
      setState(() => _headerImageUrl = url);
    }
    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isPreviewMode ? 'Preview' : 'New Trip Log', style: AppTextStyles.h3),
        actions: [
          // 👇 プレビュー切り替えボタン
          IconButton(
            onPressed: () {
              setState(() => _isPreviewMode = !_isPreviewMode);
            },
            icon: Icon(
              _isPreviewMode ? Icons.edit_note_rounded : Icons.visibility_rounded,
              color: AppColors.primary,
            ),
            tooltip: _isPreviewMode ? 'Edit' : 'Preview',
          ),
          const SizedBox(width: 8),
          
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _submitPost,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: const Text('Publish', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. ヘッダー画像 (共通)
                  GestureDetector(
                    onTap: _isPreviewMode ? null : _pickImage, // プレビュー中はタップ無効
                    child: Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(20),
                        image: _headerImageUrl != null
                            ? DecorationImage(image: NetworkImage(_headerImageUrl!), fit: BoxFit.cover)
                            : null,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: _isUploading
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : _headerImageUrl == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                                      ),
                                      child: const Icon(Icons.add_photo_alternate_rounded, size: 32, color: AppColors.primary),
                                    ),
                                    const SizedBox(height: 12),
                                    Text('Set Header Image', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                                  ],
                                )
                              : (!_isPreviewMode 
                                  ? Align(
                                      alignment: Alignment.topRight,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black45,
                                          child: Icon(Icons.edit, color: Colors.white, size: 20),
                                        ),
                                      ),
                                    )
                                  : null), // プレビュー時は編集アイコン消す
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 2. タイトル
                  if (_isPreviewMode)
                    Text(_titleController.text.isEmpty ? 'No Title' : _titleController.text, style: AppTextStyles.h1)
                  else
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Trip Title',
                        hintStyle: AppTextStyles.h1.copyWith(color: Colors.grey[300]),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: AppTextStyles.h1,
                      cursorColor: AppColors.primary,
                      maxLines: null,
                    ),
                  const SizedBox(height: 24),

                  // 3. Trip Plan Link
                  // (プレビュー時も表示してOK、ただし編集機能はオフにしても良い)
                  GestureDetector(
                    onTap: _isPreviewMode ? null : _showTripSelector,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _selectedTrip != null ? AppColors.primary : Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _selectedTrip != null ? AppColors.primary : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.map_rounded, size: 20, color: _selectedTrip != null ? Colors.white : Colors.grey),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedTrip != null ? 'Linked Trip Plan' : 'Link a Trip Plan',
                                  style: TextStyle(fontSize: 12, color: _selectedTrip != null ? AppColors.primary : Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedTrip?.title ?? 'Select from My Trips',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _selectedTrip != null ? Colors.black : Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isPreviewMode)
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 4. 本文 (ここが重要！)
                  if (_isPreviewMode)
                    // 👀 プレビューモード: MarkdownBodyで表示
                    MarkdownBody(
                      data: _contentController.text.isEmpty ? '*No content yet*' : _contentController.text,
                      styleSheet: MarkdownStyleSheet(
                        h1: AppTextStyles.h1.copyWith(fontSize: 24, height: 2.0),
                        h2: AppTextStyles.h2.copyWith(fontSize: 20, height: 1.8),
                        p: AppTextStyles.bodyLarge.copyWith(height: 1.8),
                        strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      imageBuilder: (uri, title, alt) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: uri.toString(),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(height: 200, color: Colors.grey[100]),
                          ),
                        );
                      },
                    )
                  else
                    // ✏️ 編集モード: ツールバー + TextField
                    Column(
                      children: [
                        // ツールバー
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _EditorButton(icon: Icons.title_rounded, label: 'H1', onTap: () => _insertTextAtCursor('# ')),
                              _EditorButton(icon: Icons.format_size_rounded, label: 'H2', onTap: () => _insertTextAtCursor('## ')),
                              _EditorButton(icon: Icons.format_bold_rounded, label: 'Bold', onTap: () => _insertTextAtCursor('****', selectionOffset: -2)),
                              _EditorButton(icon: Icons.image_rounded, label: 'Image', onTap: _pickAndInsertBodyImage),
                              _EditorButton(icon: Icons.horizontal_rule_rounded, label: 'Line', onTap: () => _insertTextAtCursor('\n---\n')),
                            ],
                          ),
                        ),
                        // 入力欄
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                          ),
                          child: TextField(
                            controller: _contentController,
                            maxLines: null,
                            minLines: 15,
                            cursorColor: AppColors.primary,
                            decoration: InputDecoration(
                              hintText: 'Write your story...\nTap the eye icon 👁️ above to preview!',
                              hintStyle: TextStyle(color: Colors.grey[400], height: 1.5),
                              border: InputBorder.none,
                            ),
                            style: AppTextStyles.bodyLarge.copyWith(height: 1.6),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // 5. 場所・タグ入力 (プレビュー時は隠すか、Textで表示)
                  if (!_isPreviewMode) ...[
                    // ... 既存の入力UI ...
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _locationController,
                            cursorColor: AppColors.primary,
                            decoration: const InputDecoration(
                              hintText: 'Location (e.g. Kyoto)',
                              prefixIcon: Icon(Icons.place_rounded, color: Colors.grey),
                              border: InputBorder.none,
                            ),
                          ),
                          const Divider(),
                          TextField(
                            controller: _tagController,
                            cursorColor: AppColors.primary,
                            decoration: const InputDecoration(
                              hintText: 'Add tags...',
                              prefixIcon: Icon(Icons.tag_rounded, color: Colors.grey),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ],
                      ),
                    ),
                    if (_tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          children: _tags.map((tag) => Chip(
                            label: Text('#$tag'),
                            backgroundColor: Colors.white,
                            onDeleted: () => setState(() => _tags.remove(tag)),
                          )).toList(),
                        ),
                      ),
                  ] else ...[
                    // プレビュー時のタグ表示
                    Row(
                      children: [
                        const Icon(Icons.place_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(_locationController.text.isEmpty ? 'No Location' : _locationController.text, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _tags.map((tag) => Text('#$tag', style: const TextStyle(color: Colors.grey))).toList(),
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ... (他のメソッド: _addTag, _showTripSelector, _submitPost などはそのまま)
  void _addTag() {
    final text = _tagController.text.trim();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text);
        _tagController.clear();
      });
    }
  }
  
  void _showTripSelector() {
     // ... 前回の実装と同じ
     showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Select a Trip Plan', style: AppTextStyles.h2),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<TripCubit, TripState>(
                builder: (context, state) {
                  final trips = state.allTrips;
                  if (trips.isEmpty) return const Center(child: Text('No trips available.'));
                  
                  return ListView.separated(
                    itemCount: trips.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      // DateFormatを使うなら import 'package:intl/intl.dart';
                      // formatは適宜
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        title: Text(trip.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        // subtitle: Text('${DateFormat('yyyy/MM/dd').format(trip.startDate)}'),
                        trailing: const Icon(Icons.check_circle_outline_rounded, color: Colors.grey),
                        onTap: () {
                          setState(() {
                            _selectedTrip = trip;
                            if (_locationController.text.isEmpty && trip.destinations.isNotEmpty) {
                              _locationController.text = trip.destinations.first.name;
                            }
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitPost() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty || _headerImageUrl == null) {
      TrippleToast.show(context, 'Title, Content, and Header Image are required.', isError: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final post = Post(
      id: '', 
      authorId: user.uid,
      tripId: _selectedTrip?.id ?? '',
      tripTitle: _selectedTrip?.title ?? '',
      title: _titleController.text,
      content: _contentController.text,
      headerImageUrl: _headerImageUrl!,
      bodyImageUrls: [], // 本文埋め込みになったので空でOK
      locationName: _locationController.text,
      tags: _tags,
      likesCount: 0,
      bookmarksCount: 0,
      createdAt: DateTime.now(),
    );

    await context.read<DiscoverCubit>().createPost(post);
    if (mounted) Navigator.pop(context);
  }
}

// ツールバー用ボタン (前回と同じ)
class _EditorButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _EditorButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}