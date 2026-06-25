import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/nearby_repository.dart';
import '../models/nearby_models.dart';

final nearbyRepositoryProvider =
    Provider<NearbyRepository>((_) => NearbyRepository());

final nearbyPreferencesProvider =
    FutureProvider.autoDispose<NearbyPreferences>((ref) async {
  return ref.watch(nearbyRepositoryProvider).getPreferences();
});

final nearbyMatchesProvider =
    FutureProvider.autoDispose<List<NearbyMatch>>((ref) async {
  return ref.watch(nearbyRepositoryProvider).matches();
});

final nearbyReceivedLikesProvider =
    FutureProvider.autoDispose<NearbyReceivedLikes>((ref) async {
  return ref.watch(nearbyRepositoryProvider).likesReceived();
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
  final Set<String> _seenIds = {};

  DiscoverNotifier(this._repo) : super(const DiscoverState());

  Future<void> load({bool reset = false, bool? setRandomOnline}) async {
    if (_fetching) return;
    _fetching = true;
    final randomOnline = setRandomOnline ?? state.isRandomOnline;
    // offset = total unique users seen so far; backend returns next batch
    final offset = reset ? 0 : _seenIds.length;
    if (reset) _seenIds.clear();
    state = state.copyWith(
        loading: true, clearError: true, isRandomOnline: randomOnline);
    try {
      final raw = randomOnline
          ? await _repo.discoverRandomOnline(limit: 20)
          : await _repo.discover(limit: 20, offset: offset);
      // Backend guarantees recently-online filter — deduplicate only
      final cards = raw.where((c) {
        if (_seenIds.contains(c.userId)) return false;
        _seenIds.add(c.userId);
        return true;
      }).toList();
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
    if (rest.length <= 5 && !_fetching) {
      load();
    }
  }

  /// Puts a card back on top of the deck — used to rewind a swipe whose action
  /// the server rejected (e.g. daily-like limit reached).
  void reinsertTop(NearbyCandidate card) {
    state = state.copyWith(cards: [card, ...state.cards]);
  }

  /// Manual rewind: ask the server to undo the last swipe toward [card], then
  /// put it back on top. Returns false if the server rejected the undo.
  Future<bool> undo(NearbyCandidate card) async {
    try {
      await _repo.undoLike(card.userId);
      reinsertTop(card);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<NearbyActResult> act(String targetId, String action) async {
    try {
      final res = await _repo.like(targetId, action);
      return NearbyActResult(result: res);
    } on NearbyException catch (e) {
      return NearbyActResult(errorCode: e.code);
    } catch (_) {
      return const NearbyActResult(errorCode: 'network_error');
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

/// Outcome of a swipe action — either a server [result] or a user-facing
/// [errorCode] the screen can surface (and rewind the swipe for).
class NearbyActResult {
  final NearbyLikeResult? result;
  final String? errorCode;
  const NearbyActResult({this.result, this.errorCode});

  bool get ok => errorCode == null;
}
