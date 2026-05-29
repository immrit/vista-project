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
  
  if (cachedProfile != null && cachedProfile.phoneNumber != null && cachedProfile.phoneNumber!.isNotEmpty && cachedProfile.birthDate != null) {
    // Fire and forget background refresh
    cacheService.refreshCacheInBackground(user.id);
    return cachedProfile.toMap();
  }
  
  // If we don't have phone or birth date, force a refresh
  await cacheService.refreshCacheInBackground(user.id);
  final freshProfile = await cacheService.getCachedProfile(user.id);
  
  if (freshProfile != null) {
    return freshProfile.toMap();
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
