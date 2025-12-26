// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deletion_task_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDeletionTaskEntityCollection on Isar {
  IsarCollection<DeletionTaskEntity> get deletionTaskEntitys =>
      this.collection();
}

const DeletionTaskEntitySchema = CollectionSchema(
  name: r'DeletionTaskEntity',
  id: -779200374176603552,
  properties: {
    r'conversationId': PropertySchema(
      id: 0,
      name: r'conversationId',
      type: IsarType.string,
    ),
    r'deletionMode': PropertySchema(
      id: 1,
      name: r'deletionMode',
      type: IsarType.long,
    ),
    r'messageId': PropertySchema(
      id: 2,
      name: r'messageId',
      type: IsarType.string,
    ),
    r'nextAttempt': PropertySchema(
      id: 3,
      name: r'nextAttempt',
      type: IsarType.long,
    ),
    r'retryCount': PropertySchema(
      id: 4,
      name: r'retryCount',
      type: IsarType.long,
    ),
    r's3Key': PropertySchema(
      id: 5,
      name: r's3Key',
      type: IsarType.string,
    ),
    r'timestamp': PropertySchema(
      id: 6,
      name: r'timestamp',
      type: IsarType.long,
    )
  },
  estimateSize: _deletionTaskEntityEstimateSize,
  serialize: _deletionTaskEntitySerialize,
  deserialize: _deletionTaskEntityDeserialize,
  deserializeProp: _deletionTaskEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'messageId': IndexSchema(
      id: -635287409172016016,
      name: r'messageId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'messageId',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    ),
    r'nextAttempt': IndexSchema(
      id: -5677678946449237809,
      name: r'nextAttempt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'nextAttempt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _deletionTaskEntityGetId,
  getLinks: _deletionTaskEntityGetLinks,
  attach: _deletionTaskEntityAttach,
  version: '3.1.0+1',
);

int _deletionTaskEntityEstimateSize(
  DeletionTaskEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.conversationId.length * 3;
  bytesCount += 3 + object.messageId.length * 3;
  {
    final value = object.s3Key;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _deletionTaskEntitySerialize(
  DeletionTaskEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.conversationId);
  writer.writeLong(offsets[1], object.deletionMode);
  writer.writeString(offsets[2], object.messageId);
  writer.writeLong(offsets[3], object.nextAttempt);
  writer.writeLong(offsets[4], object.retryCount);
  writer.writeString(offsets[5], object.s3Key);
  writer.writeLong(offsets[6], object.timestamp);
}

DeletionTaskEntity _deletionTaskEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DeletionTaskEntity();
  object.conversationId = reader.readString(offsets[0]);
  object.deletionMode = reader.readLong(offsets[1]);
  object.id = id;
  object.messageId = reader.readString(offsets[2]);
  object.nextAttempt = reader.readLong(offsets[3]);
  object.retryCount = reader.readLong(offsets[4]);
  object.s3Key = reader.readStringOrNull(offsets[5]);
  object.timestamp = reader.readLong(offsets[6]);
  return object;
}

P _deletionTaskEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _deletionTaskEntityGetId(DeletionTaskEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _deletionTaskEntityGetLinks(
    DeletionTaskEntity object) {
  return [];
}

void _deletionTaskEntityAttach(
    IsarCollection<dynamic> col, Id id, DeletionTaskEntity object) {
  object.id = id;
}

extension DeletionTaskEntityQueryWhereSort
    on QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QWhere> {
  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhere>
      anyMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'messageId'),
      );
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhere>
      anyNextAttempt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'nextAttempt'),
      );
    });
  }
}

extension DeletionTaskEntityQueryWhere
    on QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QWhereClause> {
  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
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

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
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

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      messageIdEqualTo(String messageId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'messageId',
        value: [messageId],
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      messageIdNotEqualTo(String messageId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'messageId',
              lower: [],
              upper: [messageId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'messageId',
              lower: [messageId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'messageId',
              lower: [messageId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'messageId',
              lower: [],
              upper: [messageId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      messageIdGreaterThan(
    String messageId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'messageId',
        lower: [messageId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      messageIdLessThan(
    String messageId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'messageId',
        lower: [],
        upper: [messageId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      messageIdBetween(
    String lowerMessageId,
    String upperMessageId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'messageId',
        lower: [lowerMessageId],
        includeLower: includeLower,
        upper: [upperMessageId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      messageIdStartsWith(String MessageIdPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'messageId',
        lower: [MessageIdPrefix],
        upper: ['$MessageIdPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      messageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'messageId',
        value: [''],
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      messageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'messageId',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'messageId',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'messageId',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'messageId',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      nextAttemptEqualTo(int nextAttempt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'nextAttempt',
        value: [nextAttempt],
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      nextAttemptNotEqualTo(int nextAttempt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'nextAttempt',
              lower: [],
              upper: [nextAttempt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'nextAttempt',
              lower: [nextAttempt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'nextAttempt',
              lower: [nextAttempt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'nextAttempt',
              lower: [],
              upper: [nextAttempt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      nextAttemptGreaterThan(
    int nextAttempt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'nextAttempt',
        lower: [nextAttempt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      nextAttemptLessThan(
    int nextAttempt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'nextAttempt',
        lower: [],
        upper: [nextAttempt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterWhereClause>
      nextAttemptBetween(
    int lowerNextAttempt,
    int upperNextAttempt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'nextAttempt',
        lower: [lowerNextAttempt],
        includeLower: includeLower,
        upper: [upperNextAttempt],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension DeletionTaskEntityQueryFilter
    on QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QFilterCondition> {
  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      conversationIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conversationId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      conversationIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      conversationIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conversationId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      deletionModeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletionMode',
        value: value,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      deletionModeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deletionMode',
        value: value,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      deletionModeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deletionMode',
        value: value,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      deletionModeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deletionMode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
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

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
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

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
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

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      messageIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      messageIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'messageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      messageIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'messageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      messageIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'messageId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      messageIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'messageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      messageIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'messageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      messageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'messageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      messageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'messageId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      messageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageId',
        value: '',
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      messageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'messageId',
        value: '',
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      nextAttemptEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nextAttempt',
        value: value,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      nextAttemptGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'nextAttempt',
        value: value,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      nextAttemptLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'nextAttempt',
        value: value,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      nextAttemptBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'nextAttempt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      retryCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retryCount',
        value: value,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      retryCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retryCount',
        value: value,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      retryCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retryCount',
        value: value,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      retryCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retryCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      s3KeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r's3Key',
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      s3KeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r's3Key',
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      s3KeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r's3Key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      s3KeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r's3Key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      s3KeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r's3Key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      s3KeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r's3Key',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      s3KeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r's3Key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      s3KeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r's3Key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      s3KeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r's3Key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      s3KeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r's3Key',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      s3KeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r's3Key',
        value: '',
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      s3KeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r's3Key',
        value: '',
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      timestampEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      timestampGreaterThan(
    int value, {
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

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      timestampLessThan(
    int value, {
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

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterFilterCondition>
      timestampBetween(
    int lower,
    int upper, {
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

extension DeletionTaskEntityQueryObject
    on QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QFilterCondition> {}

extension DeletionTaskEntityQueryLinks
    on QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QFilterCondition> {}

extension DeletionTaskEntityQuerySortBy
    on QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QSortBy> {
  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByDeletionMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletionMode', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByDeletionModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletionMode', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageId', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageId', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByNextAttempt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextAttempt', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByNextAttemptDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextAttempt', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByRetryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByS3Key() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r's3Key', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByS3KeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r's3Key', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension DeletionTaskEntityQuerySortThenBy
    on QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QSortThenBy> {
  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByDeletionMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletionMode', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByDeletionModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletionMode', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageId', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageId', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByNextAttempt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextAttempt', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByNextAttemptDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextAttempt', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByRetryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByS3Key() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r's3Key', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByS3KeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r's3Key', Sort.desc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QAfterSortBy>
      thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension DeletionTaskEntityQueryWhereDistinct
    on QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QDistinct> {
  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QDistinct>
      distinctByConversationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conversationId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QDistinct>
      distinctByDeletionMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletionMode');
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QDistinct>
      distinctByMessageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'messageId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QDistinct>
      distinctByNextAttempt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nextAttempt');
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QDistinct>
      distinctByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retryCount');
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QDistinct>
      distinctByS3Key({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r's3Key', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QDistinct>
      distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }
}

extension DeletionTaskEntityQueryProperty
    on QueryBuilder<DeletionTaskEntity, DeletionTaskEntity, QQueryProperty> {
  QueryBuilder<DeletionTaskEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DeletionTaskEntity, String, QQueryOperations>
      conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversationId');
    });
  }

  QueryBuilder<DeletionTaskEntity, int, QQueryOperations>
      deletionModeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletionMode');
    });
  }

  QueryBuilder<DeletionTaskEntity, String, QQueryOperations>
      messageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'messageId');
    });
  }

  QueryBuilder<DeletionTaskEntity, int, QQueryOperations>
      nextAttemptProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nextAttempt');
    });
  }

  QueryBuilder<DeletionTaskEntity, int, QQueryOperations> retryCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retryCount');
    });
  }

  QueryBuilder<DeletionTaskEntity, String?, QQueryOperations> s3KeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r's3Key');
    });
  }

  QueryBuilder<DeletionTaskEntity, int, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }
}
