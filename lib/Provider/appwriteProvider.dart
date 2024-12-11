import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appwriteClientProvider = Provider<Client>((ref) {
  final client = Client();
  client
      .setEndpoint('http://45.150.32.75:9865/v1') // آدرس سرور Appwrite
      .setProject('675605fc0007545481a2') // آیدی پروژه
      .setSelfSigned(
          status: true); // برای توسعه از گواهی‌های خود امضا شده استفاده کنید
  return client;
});

final accountProvider = Provider<Account>((ref) {
  return Account(ref.read(appwriteClientProvider));
});

final databasesProvider = Provider<Databases>((ref) {
  final client = ref.read(appwriteClientProvider);
  return Databases(client);
});

final storageProvider = Provider<Storage>((ref) {
  final client =
      ref.read(appwriteClientProvider); // از client موجود استفاده می‌کنیم
  return Storage(client);
});
