import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/nearby_repository.dart';
import '../models/nearby_models.dart';

final nearbyRepositoryProvider = Provider<NearbyRepository>((_) => NearbyRepository());

final nearbyPreferencesProvider =
    FutureProvider.autoDispose<NearbyPreferences>((ref) async {
  return ref.watch(nearbyRepositoryProvider).getPreferences();
});

final nearbyMatchesProvider =
    FutureProvider.autoDispose<List<NearbyMatch>>((ref) async {
  return ref.watch(nearbyRepositoryProvider).matches();
});

/// Discovery deck state. Holds the current stack of candidate cards plus
/// loading/error status so the swipe UI can drive itself.
class DiscoverState {
  final bool loading;
  final String? errorCode; // null = ok
  final List<NearbyCandidate> cards;
  final bool isRandomOnline;

  const DiscoverState({
    this.loading = true,
    this.errorCode,
    this.cards = const [],
    this.isRandomOnline = false,
  });

  DiscoverState copyWith({
    bool? loading,
    String? errorCode,
    List<NearbyCandidate>? cards,
    bool clearError = false,
    bool? isRandomOnline,
  }) =>
      DiscoverState(
        loading: loading ?? this.loading,
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
        cards: cards ?? this.cards,
        isRandomOnline: isRandomOnline ?? this.isRandomOnline,
      );
}

final discoverProvider =
    StateNotifierProvider.autoDispose<DiscoverNotifier, DiscoverState>(
  (ref) => DiscoverNotifier(ref.watch(nearbyRepositoryProvider)),
);

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  final NearbyRepository _repo;
  bool _fetching = false;

  DiscoverNotifier(this._repo) : super(const DiscoverState());

  Future<void> load({bool reset = false, bool? setRandomOnline}) async {
    if (_fetching) return;
    _fetching = true;
    final randomOnline = setRandomOnline ?? state.isRandomOnline;
    state = state.copyWith(loading: true, clearError: true, isRandomOnline: randomOnline);
    try {
      final cards = randomOnline
          ? await _repo.discoverRandomOnline(limit: 20)
          : await _repo.discover(limit: 20);
      state = DiscoverState(
        loading: false,
        cards: reset ? cards : [...state.cards, ...cards],
        isRandomOnline: randomOnline,
      );
    } on NearbyException catch (e) {
      state = state.copyWith(loading: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(loading: false, errorCode: 'network_error');
    } finally {
      _fetching = false;
    }
  }

  /// Removes the top card locally (after a swipe is committed).
  void popTop() {
    if (state.cards.isEmpty) return;
    final rest = state.cards.sublist(1);
    state = state.copyWith(cards: rest);
    // Prefetch more when the deck runs low.
    if (rest.length <= 3 && !_fetching) {
      load();
    }
  }

  Future<NearbyLikeResult?> act(String targetId, String action) async {
    try {
      return await _repo.like(targetId, action);
    } on NearbyException catch (e) {
      state = state.copyWith(errorCode: e.code);
      return null;
    } catch (_) {
      return null;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}
