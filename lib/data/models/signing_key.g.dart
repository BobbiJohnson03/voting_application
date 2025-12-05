// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signing_key.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SigningKeyAdapter extends TypeAdapter<SigningKey> {
  @override
  final int typeId = 9;

  @override
  SigningKey read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SigningKey(
      keyId: fields[0] as String,
      sessionId: fields[1] as String,
      kty: fields[2] as String,
      secret: fields[3] as String,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SigningKey obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.keyId)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.kty)
      ..writeByte(3)
      ..write(obj.secret)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SigningKeyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
