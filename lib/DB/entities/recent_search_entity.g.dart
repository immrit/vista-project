// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_search_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetRecentSearchEntityCollection on Isar {
  IsarCollection<RecentSearchEntity> get recentSearchEntitys =>
      this.collection();
}

const RecentSearchEntitySchema = CollectionSchema(
  name: r'RecentSearchEntity',
  id: 2362590464100775272,
  properties: {
    r'query': PropertySchema(
      id: 0,
      name: r'query',
      type: IsarType.string,
    ),
    r'searchType': PropertySchema(
      id: 1,
      name: r'searchType',
      type: IsarType.byte,
      enumMap: _RecentSearchEntitysearchTypeEnumValueMap,
    ),
    r'timestamp': PropertySchema(
      id: 2,
      name: r'timestamp',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _recentSearchEntityEstimateSize,
  serialize: _recentSearchEntitySerialize,
  deserialize: _recentSearchEntityDeserialize,
  deserializeProp: _recentSearchEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'query': IndexSchema(
      id: -3238105102146786367,
      name: r'query',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'query',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    ),
    r'timestamp': IndexSchema(
      id: 1852253767416892198,
      name: r'timestamp',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'timestamp',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _recentSearchEntityGetId,
  getLinks: _recentSearchEntityGetLinks,
  attach: _recentSearchEntityAttach,
  version: '3.1.0+1',
);

int _recentSearchEntityEstimateSize(
  RecentSearchEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.query.length * 3;
  return bytesCount;
}

void _recentSearchEntitySerialize(
  RecentSearchEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.query);
  writer.writeByte(offsets[1], object.searchType.index);
  writer.writeDateTime(offsets[2], object.timestamp);
}

RecentSearchEntity _recentSearchEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = RecentSearchEntity();
  object.id = id;
  object.query = reader.readString(offsets[0]);
  object.searchType = _RecentSearchEntitysearchTypeValueEnumMap[
          reader.readByteOrNull(offsets[1])] ??
      SearchType.hashtag;
  object.timestamp = reader.readDateTime(offsets[2]);
  return object;
}

P _recentSearchEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (_RecentSearchEntitysearchTypeValueEnumMap[
              reader.readByteOrNull(offset)] ??
          SearchType.hashtag) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _RecentSearchEntitysearchTypeEnumValueMap = {
  'hashtag': 0,
  'user': 1,
};
const _RecentSearchEntitysearchTypeValueEnumMap = {
  0: SearchType.hashtag,
  1: SearchType.user,
};

Id _recentSearchEntityGetId(RecentSearchEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _recentSearchEntityGetLinks(
    RecentSearchEntity object) {
  return [];
}

void _recentSearchEntityAttach(
    IsarCollection<dynamic> col, Id id, RecentSearchEntity object) {
  object.id = id;
}

extension RecentSearchEntityQueryWhereSort
    on QueryBuilder<RecentSearchEntity, RecentSearchEntity, QWhere> {
  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhere> anyQuery() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'query'),
      );
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhere>
      anyTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'timestamp'),
      );
    });
  }
}

extension RecentSearchEntityQueryWhere
    on QueryBuilder<RecentSearchEntity, RecentSearchEntity, QWhereClause> {
  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      queryEqualTo(String query) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'query',
        value: [query],
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      queryNotEqualTo(String query) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'query',
              lower: [],
              upper: [query],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'query',
              lower: [query],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'query',
              lower: [query],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'query',
              lower: [],
              upper: [query],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      queryGreaterThan(
    String query, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'query',
        lower: [query],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      queryLessThan(
    String query, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'query',
        lower: [],
        upper: [query],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      queryBetween(
    String lowerQuery,
    String upperQuery, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'query',
        lower: [lowerQuery],
        includeLower: includeLower,
        upper: [upperQuery],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      queryStartsWith(String QueryPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'query',
        lower: [QueryPrefix],
        upper: ['$QueryPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      queryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'query',
        value: [''],
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      queryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'query',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'query',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'query',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'query',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      timestampEqualTo(DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'timestamp',
        value: [timestamp],
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      timestampNotEqualTo(DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [],
              upper: [timestamp],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [timestamp],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [timestamp],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [],
              upper: [timestamp],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      timestampGreaterThan(
    DateTime timestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestamp',
        lower: [timestamp],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      timestampLessThan(
    DateTime timestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestamp',
        lower: [],
        upper: [timestamp],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterWhereClause>
      timestampBetween(
    DateTime lowerTimestamp,
    DateTime upperTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestamp',
        lower: [lowerTimestamp],
        includeLower: includeLower,
        upper: [upperTimestamp],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension RecentSearchEntityQueryFilter
    on QueryBuilder<RecentSearchEntity, RecentSearchEntity, QFilterCondition> {
  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      queryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'query',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      queryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'query',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      queryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'query',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      queryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'query',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      queryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'query',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      queryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'query',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      queryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'query',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      queryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'query',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      queryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'query',
        value: '',
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      queryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'query',
        value: '',
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      searchTypeEqualTo(SearchType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'searchType',
        value: value,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      searchTypeGreaterThan(
    SearchType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'searchType',
        value: value,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      searchTypeLessThan(
    SearchType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'searchType',
        value: value,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      searchTypeBetween(
    SearchType lower,
    SearchType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'searchType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      timestampGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      timestampLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterFilterCondition>
      timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension RecentSearchEntityQueryObject
    on QueryBuilder<RecentSearchEntity, RecentSearchEntity, QFilterCondition> {}

extension RecentSearchEntityQueryLinks
    on QueryBuilder<RecentSearchEntity, RecentSearchEntity, QFilterCondition> {}

extension RecentSearchEntityQuerySortBy
    on QueryBuilder<RecentSearchEntity, RecentSearchEntity, QSortBy> {
  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      sortByQuery() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'query', Sort.asc);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      sortByQueryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'query', Sort.desc);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      sortBySearchType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'searchType', Sort.asc);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      sortBySearchTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'searchType', Sort.desc);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension RecentSearchEntityQuerySortThenBy
    on QueryBuilder<RecentSearchEntity, RecentSearchEntity, QSortThenBy> {
  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      thenByQuery() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'query', Sort.asc);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      thenByQueryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'query', Sort.desc);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      thenBySearchType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'searchType', Sort.asc);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      thenBySearchTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'searchType', Sort.desc);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QAfterSortBy>
      thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension RecentSearchEntityQueryWhereDistinct
    on QueryBuilder<RecentSearchEntity, RecentSearchEntity, QDistinct> {
  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QDistinct>
      distinctByQuery({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'query', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QDistinct>
      distinctBySearchType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'searchType');
    });
  }

  QueryBuilder<RecentSearchEntity, RecentSearchEntity, QDistinct>
      distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }
}

extension RecentSearchEntityQueryProperty
    on QueryBuilder<RecentSearchEntity, RecentSearchEntity, QQueryProperty> {
  QueryBuilder<RecentSearchEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<RecentSearchEntity, String, QQueryOperations> queryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'query');
    });
  }

  QueryBuilder<RecentSearchEntity, SearchType, QQueryOperations>
      searchTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'searchType');
    });
  }

  QueryBuilder<RecentSearchEntity, DateTime, QQueryOperations>
      timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }
}
