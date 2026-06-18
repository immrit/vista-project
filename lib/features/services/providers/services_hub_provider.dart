import 'package:flutter_riverpod/flutter_riverpod.dart';
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

final contactsProvider = StateNotifierProvider.autoDispose<
    ContactsNotifier, AsyncValue<List<ContactVistaUser>>>(
  (ref) => ContactsNotifier(ref.watch(servicesHubRepositoryProvider)),
);

class ContactsNotifier
    extends StateNotifier<AsyncValue<List<ContactVistaUser>>> {
  final ServicesHubRepository _repo;

  ContactsNotifier(this._repo) : super(const AsyncValue.data([]));

  Future<void> load([List<String>? phones]) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.findContacts(phones ?? []);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
