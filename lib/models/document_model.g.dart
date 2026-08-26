// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DocumentModelAdapter extends TypeAdapter<DocumentModel> {
  @override
  final int typeId = 0;

  @override
  DocumentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DocumentModel(
      id: fields[0] as String,
      title: fields[1] as String,
      extractedText: fields[2] as String,
      imagePath: fields[3] as String,
      createdAt: fields[4] as DateTime,
      language: fields[5] as String,
      category: fields[6] as String,
      isFavourite: fields[7] as bool,
      isPinned: fields[8] as bool,
      highlights: (fields[9] as List?)?.cast<int>() ?? const <int>[],
      imageUrl: fields[10] as String?,
      blurredTypes: (fields[11] as List?)?.cast<String>() ?? const <String>[],
    );
  }

  @override
  void write(BinaryWriter writer, DocumentModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.extractedText)
      ..writeByte(3)
      ..write(obj.imagePath)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.language)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.isFavourite)
      ..writeByte(8)
      ..write(obj.isPinned)
      ..writeByte(9)
      ..write(obj.highlights)
      ..writeByte(10)
      ..write(obj.imageUrl)
      ..writeByte(11)
      ..write(obj.blurredTypes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DocumentModelAdapter &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
}