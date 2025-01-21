// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'RecentSearch.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecentSearchAdapter extends TypeAdapter<RecentSearch> {
  @override
  final int typeId = 1;

  @override
  RecentSearch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecentSearch(
      query: fields[0] as String,
      timestamp: fields[1] as DateTime,
      searchType: fields[2] as SearchType,
    );
  }

  @override
  void write(BinaryWriter writer, RecentSearch obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.query)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.searchType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentSearchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SearchTypeAdapter extends TypeAdapter<SearchType> {
  @override
  final int typeId = 2;

  @override
  SearchType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SearchType.hashtag;
      case 1:
        return SearchType.user;
      default:
        return SearchType.hashtag;
    }
  }

  @override
  void write(BinaryWriter writer, SearchType obj) {
    switch (obj) {
      case SearchType.hashtag:
        writer.writeByte(0);
        break;
      case SearchType.user:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
