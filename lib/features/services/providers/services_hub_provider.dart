import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:Vista/core/security/input_policy.dart';
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
      // Normalize to the canonical 09xxxxxxxxx form client-side so the backend
      // matches formats it doesn't handle itself (0098…, +98…, (0912)…,
      // spaces/dashes). Non-mobile / unparseable numbers are dropped.
      final phones = <String>{};
      for (final c in contacts) {
        for (final p in c.phones) {
          final n = normalizePhone09(p.number);
          if (n != null && n.isNotEmpty) phones.add(n);
        }
      }
      if (phones.isEmpty) {
        _isLoaded = true;
        state = const AsyncValue.data([]);
        return;
      }

      // Send in batches of 200 so a huge address book isn't one giant payload.
      final phoneList = phones.toList();
      final result = <ContactVistaUser>[];
      for (var i = 0; i < phoneList.length; i += 200) {
        final batch = phoneList.sublist(
            i, i + 200 > phoneList.length ? phoneList.length : i + 200);
        result.addAll(await _repo.findContacts(batch));
      }
      _isLoaded = true;
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
