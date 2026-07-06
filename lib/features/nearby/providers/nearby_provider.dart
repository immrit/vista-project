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

  // NOTE: the old swipe-deck rewind API (popTop/reinsertTop/undo + the
  // /undo endpoint) was removed — the UI moved to a browse model and nothing
  // called it. Re-add deliberately if a Tinder-style rewind button ships.

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
