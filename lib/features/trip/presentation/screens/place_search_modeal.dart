import 'package:flutter/material.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/services/geocoding_service.dart';
// 👇 TrippleModalScaffold
import 'package:new_tripple/shared/widgets/tripple_modal_scaffold.dart';
import 'package:new_tripple/core/constants/modal_constants.dart';

class PlaceSearchModal extends StatefulWidget {
  final String? initialQuery;
  final String? hintText; 

  const PlaceSearchModal({
    super.key,
    this.initialQuery,
    this.hintText,
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
    // 👇 TrippleModalScaffoldへ移行
    return TrippleModalScaffold(
      title: 'Search Place',
      icon: Icons.search_rounded,
      heightRatio: TrippleModalSize.highRatio,
      
      // リストを持つのでfalse (Scaffoldの修正により、最大化される)
      isScrollable: false,

      child: Column(
        children: [
          // 検索バー
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.hintText ?? 'Search for a city or place',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _isLoading 
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear()),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // 結果リスト (Expandedで埋める)
          Expanded(
            child: _results.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.public, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text('Enter a location to search', style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  )
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