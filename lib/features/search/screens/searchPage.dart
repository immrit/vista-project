import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:Vista/DB/entities/recent_search_entity.dart';
import 'package:Vista/DB/isar_database_manager.dart';
import 'package:Vista/core/theme/app_theme.dart';
import 'package:Vista/features/chat/widgets/message_search_bar.dart';
import 'package:Vista/features/posts/data/go_posts_repository.dart';
import 'package:Vista/features/posts/screens/PostDetailPage.dart';
import 'package:Vista/features/posts/screens/profileScreen.dart';
import 'package:Vista/features/search/screens/VistaQRScanner.dart';
import 'package:Vista/l10n/generated/app_localizations.dart';
import 'package:Vista/model/ProfileModel.dart';
import 'package:Vista/model/SearchResut.dart';
import 'package:Vista/model/publicPostModel.dart';
import 'package:Vista/provider/provider.dart';
import 'package:Vista/utils/glassmorphism.dart';
import 'package:Vista/widgets/skeleton_loading.dart';
import 'package:Vista/widgets/verification_badge_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

class SearchPage extends ConsumerStatefulWidget {
  final String? initialHashtag;
  final bool openAsWorkspace;
  final bool autofocus;

  const SearchPage({
    super.key,
    this.initialHashtag,
    this.openAsWorkspace = false,
    this.autofocus = false,
  });

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GoPostsRepository _postsRepository = GoPostsRepository();
  Timer? _debounceTimer;
  Timer? _suggestionDebounceTimer;

  Isar? _isar;
  bool _isInitialized = false;
  bool _hasQuery = false;
  bool _didOpenWorkspaceFromLauncher = false;

  List<HashtagSuggestion> _trendingHashtags = const [];
  List<HashtagSuggestion> _hashtagSuggestions = const [];
  bool _isLoadingTrending = false;
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      _isar = await IsarDatabaseManager().instance;
    } catch (e) {
      debugPrint('Error opening Isar in search page: $e');
    }

    await _loadTrendingHashtags();

    if (!mounted) return;
    setState(() => _isInitialized = true);
    _handleInitialHashtag();
    if (widget.openAsWorkspace &&
        widget.autofocus &&
        (widget.initialHashtag == null ||
            widget.initialHashtag!.trim().isEmpty)) {
      _requestSearchFocus();
    }
  }

  void _requestSearchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  void _handleInitialHashtag() {
    final initialHashtag = widget.initialHashtag;
    if (initialHashtag == null || initialHashtag.trim().isEmpty) return;
    final normalized = initialHashtag.startsWith('#')
        ? initialHashtag.trim()
        : '#${initialHashtag.trim()}';
    if (!widget.openAsWorkspace && !_didOpenWorkspaceFromLauncher) {
      _didOpenWorkspaceFromLauncher = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openSearchWorkspace(initialQuery: normalized);
        }
      });
      return;
    }
    _applyQuery(normalized, fromSubmit: true, keepFocus: true);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (_hasQuery != query.isNotEmpty) {
      setState(() => _hasQuery = query.isNotEmpty);
    }
  }

  Future<void> _loadTrendingHashtags() async {
    if (_isLoadingTrending) return;
    setState(() => _isLoadingTrending = true);
    try {
      final hashtags = await _postsRepository.getTrendingHashtags(limit: 12);
      if (mounted) {
        setState(() => _trendingHashtags = hashtags);
      } else {
        _trendingHashtags = hashtags;
      }
    } catch (_) {
      // best effort only
    } finally {
      if (mounted) {
        setState(() => _isLoadingTrending = false);
      } else {
        _isLoadingTrending = false;
      }
    }
  }

  void _loadHashtagSuggestions(String query) {
    _suggestionDebounceTimer?.cancel();
    _suggestionDebounceTimer =
        Timer(const Duration(milliseconds: 300), () async {
      final keyword = query.trim().replaceFirst('#', '');
      if (keyword.isEmpty) {
        setState(() {
          _hashtagSuggestions = _trendingHashtags.take(8).toList();
          _isLoadingSuggestions = false;
        });
        return;
      }

      setState(() => _isLoadingSuggestions = true);
      try {
        final suggestions =
            await _postsRepository.searchHashtags(keyword: keyword, limit: 10);
        if (!mounted) return;
        setState(() => _hashtagSuggestions = suggestions);
      } catch (_) {
        if (!mounted) return;
        final lower = keyword.toLowerCase();
        setState(() {
          _hashtagSuggestions = _trendingHashtags
              .where((item) => item.tag.toLowerCase().startsWith(lower))
              .take(8)
              .toList();
        });
      } finally {
        if (mounted) {
          setState(() => _isLoadingSuggestions = false);
        } else {
          _isLoadingSuggestions = false;
        }
      }
    });
  }

  void _applyQuery(
    String query, {
    bool fromSubmit = false,
    bool keepFocus = false,
  }) {
    final normalized = query.trim();
    _searchController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    _performSearch(normalized, fromSubmit: fromSubmit);
    if (keepFocus) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
  }

  void _performSearch(String query, {bool fromSubmit = false}) {
    final normalized = query.trim();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      fromSubmit ? Duration.zero : const Duration(milliseconds: 300),
      () async {
        if (!mounted) return;
        if (normalized.isEmpty) {
          ref.read(searchProvider.notifier).clearAll();
          setState(() {
            _hasQuery = false;
            _hashtagSuggestions = const [];
          });
          return;
        }

        if (normalized.startsWith('#')) {
          if (_tabController.index != 2) {
            _tabController.animateTo(2);
          }
          _loadHashtagSuggestions(normalized);
        } else {
          setState(() => _hashtagSuggestions = const []);
        }

        await ref.read(searchProvider.notifier).search(normalized);
      },
    );
  }

  Future<void> _saveRecentSelection({
    required String query,
    required SearchType searchType,
  }) async {
    if (query.isEmpty || _isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        await _isar!.recentSearchEntitys
            .filter()
            .queryEqualTo(query)
            .deleteAll();

        final recentSearch = RecentSearchEntity()
          ..query = query
          ..timestamp = DateTime.now()
          ..searchType = searchType;
        await _isar!.recentSearchEntitys.put(recentSearch);

        final count = await _isar!.recentSearchEntitys.count();
        if (count > 20) {
          final oldItems = await _isar!.recentSearchEntitys
              .where()
              .sortByTimestamp()
              .limit(count - 20)
              .findAll();
          await _isar!.recentSearchEntitys
              .deleteAll(oldItems.map((item) => item.id).toList());
        }
      });
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  Future<void> _deleteRecentSearch(String query) async {
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        await _isar!.recentSearchEntitys
            .filter()
            .queryEqualTo(query)
            .deleteAll();
      });
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error deleting recent search: $e');
    }
  }

  Future<void> _clearRecentSearches() async {
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        await _isar!.recentSearchEntitys.clear();
      });
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  Future<List<RecentSearchEntity>> _getRecentSearches() async {
    if (_isar == null) return const [];
    try {
      return _isar!.recentSearchEntitys.where().sortByTimestampDesc().findAll();
    } catch (_) {
      return const [];
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    _suggestionDebounceTimer?.cancel();
    ref.read(searchProvider.notifier).clearAll();
    setState(() {
      _hasQuery = false;
      _hashtagSuggestions = const [];
    });
  }

  String _highlightQuery(String rawQuery) {
    return rawQuery.trim().replaceFirst(RegExp(r'^[@#]+'), '');
  }

  Future<void> _openSearchWorkspace({String? initialQuery}) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(
          openAsWorkspace: true,
          initialHashtag: initialQuery ?? widget.initialHashtag,
          autofocus: initialQuery == null && widget.initialHashtag == null,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _suggestionDebounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!widget.openAsWorkspace) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildLauncherSearchBar(theme, l10n),
              Expanded(child: _buildLauncherBody(theme)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(theme, l10n),
            if (_hasQuery) _buildTabBar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _hasQuery
                    ? _buildSearchResults(theme, l10n)
                    : _buildZeroState(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLauncherSearchBar(ThemeData theme, AppLocalizations l10n) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openSearchWorkspace,
        child: LiquidGlassContainer(
          blur: 24,
          opacity: isDark ? 0.18 : 0.45,
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.searchUsers,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Icon(Icons.open_in_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLauncherBody(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadTrendingHashtags,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildSectionHeader('ترندهای امروز'),
          const SizedBox(height: 8),
          if (_isLoadingTrending && _trendingHashtags.isEmpty)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_trendingHashtags.isEmpty)
            _buildEmptyState('هنوز ترندی برای نمایش نداریم')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _trendingHashtags.take(12).map((item) {
                return ActionChip(
                  avatar: const Icon(Icons.trending_up_rounded, size: 16),
                  label: Text('#${item.tag}'),
                  onPressed: () => _openSearchWorkspace(
                    initialQuery: '#${item.tag}',
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, AppLocalizations l10n) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LiquidGlassContainer(
        blur: 24,
        opacity: isDark ? 0.18 : 0.45,
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: l10n.searchUsers,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasQuery)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _clearSearch,
                  ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VistaQRScanner(),
                      ),
                    );
                  },
                ),
              ],
            ),
            border: InputBorder.none,
          ),
          onChanged: (value) => _performSearch(value),
          onSubmitted: (value) => _performSearch(value, fromSubmit: true),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        onTap: (index) => ref.read(searchProvider.notifier).setTab(index),
        tabs: const [
          Tab(text: 'همه'),
          Tab(text: 'افراد'),
          Tab(text: 'تگ‌ها'),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme, AppLocalizations l10n) {
    final searchState = ref.watch(searchProvider);
    if (_tabController.index != searchState.selectedTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.index != searchState.selectedTab) {
          _tabController.animateTo(searchState.selectedTab);
        }
      });
    }

    if (searchState.isLoading) {
      return _buildLoadingState();
    }

    return Column(
      children: [
        if (searchState.error != null && searchState.error!.isNotEmpty)
          _buildErrorBanner(searchState.error!, l10n),
        if (_searchController.text.trim().startsWith('#') &&
            (_isLoadingSuggestions || _hashtagSuggestions.isNotEmpty))
          _buildHashtagSuggestions(theme),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAllResults(searchState, l10n),
              _buildUserResults(searchState),
              _buildHashtagResults(searchState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String error, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          dense: true,
          leading:
              const Icon(Icons.error_outline_rounded, color: AppColors.error),
          title: Text(
            error,
            style: const TextStyle(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: TextButton(
            onPressed: () => ref.read(searchProvider.notifier).retry(),
            child: Text(l10n.retry),
          ),
        ),
      ),
    );
  }

  Widget _buildHashtagSuggestions(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: _isLoadingSuggestions
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _hashtagSuggestions.length.clamp(0, 6),
              separatorBuilder: (_, __) => Divider(
                  height: 1, color: theme.dividerColor.withValues(alpha: 0.35)),
              itemBuilder: (context, index) {
                final item = _hashtagSuggestions[index];
                return ListTile(
                  dense: true,
                  leading: const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary,
                    child: Text('#', style: TextStyle(color: Colors.white)),
                  ),
                  title: Text('#${item.tag}'),
                  subtitle: Text('${item.usageCount} پست'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _saveRecentSelection(
                      query: '#${item.tag}',
                      searchType: SearchType.hashtag,
                    );
                    _applyQuery('#${item.tag}', fromSubmit: true);
                  },
                );
              },
            ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).viewPadding.bottom + 110,
      ),
      children: const [
        PostCardSkeleton(),
        PostCardSkeleton(),
      ],
    );
  }

  Widget _buildAllResults(SearchState state, AppLocalizations l10n) {
    if (state.userResults.isEmpty && state.hashtagResults.isEmpty) {
      return _buildEmptyState(l10n.noResultsFound);
    }

    final query = _highlightQuery(_searchController.text);
    return ListView(
      padding: EdgeInsets.only(
        top: 8,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewPadding.bottom + 110,
      ),
      children: [
        if (state.userResults.isNotEmpty) ...[
          _buildSectionHeader('افراد'),
          ...state.userResults.take(5).map(
                (user) => _UserTile(
                  user: user,
                  query: query,
                  onTap: () => _saveRecentSelection(
                    query: '@${user.username}',
                    searchType: SearchType.user,
                  ),
                ),
              ),
          if (state.userResults.length > 5)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: const Text('نمایش همه افراد'),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (state.hashtagResults.isNotEmpty) ...[
          _buildSectionHeader('پست‌ها'),
          _buildPostPreviewGrid(
            state.hashtagResults.take(9).toList(),
            currentQuery: state.currentQuery,
          ),
        ],
      ],
    );
  }

  Widget _buildUserResults(SearchState state) {
    if (state.userResults.isEmpty) {
      return _buildEmptyState('کاربری یافت نشد');
    }

    final query = _highlightQuery(_searchController.text);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (state.hasMoreUsers &&
            !state.isLoadingMoreUsers &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 240) {
          ref.read(searchProvider.notifier).loadMoreUsers();
        }
        return false;
      },
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: 8,
          bottom: MediaQuery.of(context).viewPadding.bottom + 110,
        ),
        itemCount:
            state.userResults.length + (state.isLoadingMoreUsers ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.userResults.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final user = state.userResults[index];
          return _UserTile(
            user: user,
            query: query,
            onTap: () => _saveRecentSelection(
              query: '@${user.username}',
              searchType: SearchType.user,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHashtagResults(SearchState state) {
    if (state.hashtagResults.isEmpty) {
      return _buildEmptyState('پستی یافت نشد');
    }
    return GridView.builder(
      padding: EdgeInsets.only(
        top: 8,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewPadding.bottom + 110,
      ),
      itemCount: state.hashtagResults.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        return _PostGridItem(
          post: state.hashtagResults[index],
          onTap: () {
            if (state.currentQuery.startsWith('#')) {
              _saveRecentSelection(
                query: state.currentQuery,
                searchType: SearchType.hashtag,
              );
            }
          },
        );
      },
    );
  }

  Widget _buildPostPreviewGrid(
    List<PublicPostModel> posts, {
    required String currentQuery,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        return _PostGridItem(
          post: posts[index],
          onTap: () {
            if (currentQuery.startsWith('#')) {
              _saveRecentSelection(
                query: currentQuery,
                searchType: SearchType.hashtag,
              );
            }
          },
        );
      },
    );
  }

  Widget _buildZeroState(ThemeData theme) {
    return FutureBuilder<List<RecentSearchEntity>>(
      future: _getRecentSearches(),
      builder: (context, snapshot) {
        final recents = snapshot.data ?? const <RecentSearchEntity>[];
        return RefreshIndicator(
          onRefresh: _loadTrendingHashtags,
          child: ListView(
            padding: EdgeInsets.only(
              top: 12,
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewPadding.bottom + 110,
            ),
            children: [
              if (recents.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(child: _buildSectionHeader('جستجوهای اخیر')),
                    TextButton(
                      onPressed: _clearRecentSearches,
                      child: const Text('پاک کردن'),
                    ),
                  ],
                ),
                ...recents.take(12).map(
                      (item) => ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        leading: Icon(
                          item.searchType == SearchType.hashtag
                              ? Icons.tag_rounded
                              : Icons.person_search_rounded,
                        ),
                        title: Text(item.query),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => _deleteRecentSearch(item.query),
                        ),
                        onTap: () => _applyQuery(
                          item.query,
                          fromSubmit: true,
                          keepFocus: true,
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
              ],
              _buildSectionHeader('ترندهای امروز'),
              const SizedBox(height: 8),
              if (_isLoadingTrending && _trendingHashtags.isEmpty)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (_trendingHashtags.isEmpty)
                _buildEmptyState('هنوز ترندی برای نمایش نداریم')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _trendingHashtags.take(12).map((item) {
                    return ActionChip(
                      avatar: const Icon(Icons.trending_up_rounded, size: 16),
                      label: Text('#${item.tag}'),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _saveRecentSelection(
                          query: '#${item.tag}',
                          searchType: SearchType.hashtag,
                        );
                        _applyQuery('#${item.tag}', fromSubmit: true);
                      },
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 52,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final ProfileModel user;
  final String query;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName =
        user.fullName.isNotEmpty ? user.fullName : user.username;
    final avatarUrl = user.avatarUrl;

    return ListTile(
      leading: CircleAvatar(
        radius: 23,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
            ? CachedNetworkImageProvider(avatarUrl)
            : null,
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Icon(Icons.person_rounded,
                color: theme.colorScheme.onSurfaceVariant)
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: HighlightedText(
              text: displayName,
              query: query,
              style: theme.textTheme.titleSmall,
              highlightStyle: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
            ),
          ),
          if (user.isVerified) ...[
            const SizedBox(width: 4),
            VerificationBadgeIcon(
              isVerified: user.isVerified,
              verificationType: user.verificationType,
              role: user.role,
              size: 16,
            ),
          ],
        ],
      ),
      subtitle: HighlightedText(
        text: '@${user.username}',
        query: query,
        style: theme.textTheme.bodySmall,
        highlightStyle: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
      ),
      trailing:
          Icon(Icons.chevron_left_rounded, color: theme.colorScheme.outline),
      onTap: () {
        onTap();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProfileScreen(userId: user.id, username: user.username),
          ),
        );
      },
    );
  }
}

class _PostGridItem extends StatelessWidget {
  final PublicPostModel post;
  final VoidCallback? onTap;

  const _PostGridItem({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.imageUrl;
    return GestureDetector(
      onTap: () {
        onTap?.call();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailsPage(postId: post.id),
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: imageUrl != null && imageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Icon(Icons.image_outlined),
                ),
              )
            : const Icon(Icons.article_outlined),
      ),
    );
  }
}
