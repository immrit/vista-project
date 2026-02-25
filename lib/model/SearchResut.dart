// مدل جستجو
import 'ProfileModel.dart';
import 'publicPostModel.dart';

class SearchState {
  final bool isLoading;
  final String currentQuery;
  final List<PublicPostModel> hashtagResults;
  final List<ProfileModel> userResults;
  final String? error;
  final int selectedTab;
  final int userOffset;
  final bool hasMoreUsers;

  const SearchState({
    this.isLoading = false,
    this.currentQuery = '',
    this.hashtagResults = const [],
    this.userResults = const [],
    this.error,
    this.selectedTab = 0,
    this.userOffset = 0,
    this.hasMoreUsers = true,
  });

  SearchState copyWith({
    bool? isLoading,
    String? currentQuery,
    List<PublicPostModel>? hashtagResults,
    List<ProfileModel>? userResults,
    String? error,
    int? selectedTab,
    int? userOffset,
    bool? hasMoreUsers,
  }) {
    return SearchState(
      isLoading: isLoading ?? this.isLoading,
      currentQuery: currentQuery ?? this.currentQuery,
      hashtagResults: hashtagResults ?? this.hashtagResults,
      userResults: userResults ?? this.userResults,
      error: error ?? this.error,
      selectedTab: selectedTab ?? this.selectedTab,
      userOffset: userOffset ?? this.userOffset,
      hasMoreUsers: hasMoreUsers ?? this.hasMoreUsers,
    );
  }
}
