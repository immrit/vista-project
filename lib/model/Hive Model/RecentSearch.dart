import 'package:hive/hive.dart';

part 'RecentSearch.g.dart';

@HiveType(typeId: 2) // تغییر به 2 برای مطابقت با adapter
enum SearchType {
  @HiveField(0)
  hashtag,

  @HiveField(1)
  user
}

@HiveType(typeId: 1)
class RecentSearch extends HiveObject {
  @HiveField(0)
  final String query;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final SearchType searchType;

  RecentSearch({
    required this.query,
    required this.timestamp,
    required this.searchType,
  });
}
