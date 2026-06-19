import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services_hub_repository.dart';
import '../models/top_group_model.dart';
import 'services_hub_provider.dart';

final topGroupsProvider = FutureProvider.autoDispose<List<TopGroup>>((ref) async {
  final repo = ref.watch(servicesHubRepositoryProvider);
  final rawData = await repo.getTopGroupsRaw();
  return rawData.map((e) => TopGroup.fromJson(e as Map<String, dynamic>)).toList();
});
