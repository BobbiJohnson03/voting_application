// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meeting_pass.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MeetingPassAdapter extends TypeAdapter<MeetingPass> {
  @override
  final int typeId = 13;

  @override
  MeetingPass read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MeetingPass(
      passId: fields[0] as String,
      meetingId: fields[1] as String,
      issuedAt: fields[2] as DateTime?,
      revoked: fields[3] as bool,
      deviceFingerprintHash: fields[4] as String?,
      revokedReason: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MeetingPass obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.passId)
      ..writeByte(1)
      ..write(obj.meetingId)
      ..writeByte(2)
      ..write(obj.issuedAt)
      ..writeByte(3)
      ..write(obj.revoked)
      ..writeByte(4)
      ..write(obj.deviceFingerprintHash)
      ..writeByte(5)
      ..write(obj.revokedReason);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeetingPassAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
