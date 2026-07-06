import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../data/services_hub_repository.dart';
import '../models/services_hub_model.dart';

final servicesHubRepositoryProvider = Provider<ServicesHubRepository>(
  (_) => ServicesHubRepository(),
);

final servicesHubProvider =
    FutureProvider.autoDispose<ServicesHubData>((ref) async {
  final repo = ref.watch(servicesHubRepositoryProvider);
  return repo.getHub();
});

final contactsProvider =
    StateNotifierProvider<ContactsNotifier, AsyncValue<List<ContactVistaUser>>>(
  (ref) => ContactsNotifier(ref.watch(servicesHubRepositoryProvider)),
);

class ContactsNotifier
    extends StateNotifier<AsyncValue<List<ContactVistaUser>>> {
  final ServicesHubRepository _repo;
  bool _isLoaded = false;

  ContactsNotifier(this._repo) : super(const AsyncValue.loading());

  /// Sentinel so the UI can tell "permission denied" apart from a genuinely
  /// empty result — previously denial rendered as «مخاطبی در ویستا نیست»,
  /// which is a lie and gives the user no way to fix it.
  static const String permissionDenied = 'contacts_permission_denied';

  Future<void> load() async {
    if (_isLoaded && state is AsyncData) return;

    state = const AsyncValue.loading();
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        state = AsyncValue.error(permissionDenied, StackTrace.current);
        return;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final phones = <String>{};
      for (final c in contacts) {
        for (final p in c.phones) {
          phones.add(p.number);
        }
      }

      final result = await _repo.findContacts(phones.toList());
      _isLoaded = true;
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
