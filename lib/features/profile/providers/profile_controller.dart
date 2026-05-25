import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/DB/profile_cache_service.dart';
import '../data/profile_repository.dart';
import '../../auth/providers/auth_controller.dart';

// مخزن Profile
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

// پرایدر Fetch Profile
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(userAuthStateProvider).when(
        data: (user) => user,
        loading: () => null,
        error: (err, stack) => null,
      );

  if (user == null) {
    throw 'User is not logged in';
  }

  final repository = ref.watch(profileRepositoryProvider);
  final cacheService = ProfileCacheService();
  final cachedProfile = await cacheService.getCachedProfile(user.id);
  if (cachedProfile != null) {
    // Return cached profile immediately and let background refresh happen elsewhere.
    return cachedProfile.toMap();
  }
  return await repository.fetchProfile(user.id);
});

// پروایدر Update Profile
final profileUpdateProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>(
        (ref, updatedData) async {
  final user = ref.watch(userAuthStateProvider).when(
        data: (user) => user,
        loading: () => null,
        error: (err, stack) => null,
      );

  if (user == null) {
    throw 'User is not logged in';
  }

  final repository = ref.watch(profileRepositoryProvider);
  return repository.updateProfile(user.id, updatedData);
});
