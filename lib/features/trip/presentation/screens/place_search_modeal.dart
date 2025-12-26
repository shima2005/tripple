import 'package:flutter/material.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/services/geocoding_service.dart';

class PlaceSearchModal extends StatefulWidget {
  final String? initialQuery;
  final String? hintText; // 👈 追加: ヒントテキストをカスタマイズ

  const PlaceSearchModal({
    super.key,
    this.initialQuery,
    this.hintText, // 👈 追加
  });

  @override
  State<PlaceSearchModal> createState() => _PlaceSearchModalState();
}

class _PlaceSearchModalState extends State<PlaceSearchModal> {
  late TextEditingController _searchController;
  final _geocodingService = GeocodingService();
  
  List<PlaceSearchResult> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Search Place 📍', style: AppTextStyles.h2),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),

          // 検索ボックス
          TextFormField(
            controller: _searchController,
            style: AppTextStyles.bodyLarge,
            textInputAction: TextInputAction.search,
            autofocus: widget.initialQuery == null,
            decoration: InputDecoration(
              // 👇 修正: 指定がなければデフォルト、あればそれを使う
              hintText: widget.hintText ?? 'e.g. Kiyomizu-dera, Kyoto Station',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                onPressed: _search,
              ),
            ),
            onFieldSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 16),

          // 結果リスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(child: Text('No results found.', style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final place = _results[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.location_on_rounded, color: AppColors.accent),
                            ),
                            title: Text(
                              place.name, 
                              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              place.address,
                              style: AppTextStyles.label.copyWith(color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.pop(context, place),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _search() async {
    if (_searchController.text.isEmpty) return;
    setState(() => _isLoading = true);
    final results = await _geocodingService.searchPlaces(_searchController.text);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }
}