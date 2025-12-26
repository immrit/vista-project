import 'package:isar/isar.dart';

part 'recent_search_entity.g.dart';

@collection
class RecentSearchEntity {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String query;

  @Index()
  late DateTime timestamp;

  @Enumerated(EnumType.ordinal)
  late SearchType searchType;
}

enum SearchType {
  hashtag,
  user,
}
