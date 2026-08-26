// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_memory_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanMemoryModelAdapter extends TypeAdapter<ScanMemoryModel> {
  @override
  final int typeId = 2;

  @override
  ScanMemoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanMemoryModel(
      documentId: fields[0] as String,
      title: fields[1] as String,
      category: fields[2] as String,
      scanCount: fields[3] as int,
      lastScanned: fields[4] as DateTime,
      imagePath: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ScanMemoryModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.documentId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.scanCount)
      ..writeByte(4)
      ..write(obj.lastScanned)
      ..writeByte(5)
      ..write(obj.imagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanMemoryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
