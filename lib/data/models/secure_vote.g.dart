// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secure_vote.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SecureVoteAdapter extends TypeAdapter<SecureVote> {
  @override
  final int typeId = 11;

  @override
  SecureVote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SecureVote(
      id: fields[0] as String,
      sessionId: fields[1] as String,
      questionId: fields[2] as String,
      selectedOptionIds: (fields[3] as List).cast<String>(),
      submittedAt: fields[4] as DateTime,
      ticketId: fields[5] as String,
      previousVoteHash: fields[6] as String,
      voteHash: fields[7] as String,
      nonce: fields[8] as String,
      signature: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SecureVote obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.questionId)
      ..writeByte(3)
      ..write(obj.selectedOptionIds)
      ..writeByte(4)
      ..write(obj.submittedAt)
      ..writeByte(5)
      ..write(obj.ticketId)
      ..writeByte(6)
      ..write(obj.previousVoteHash)
      ..writeByte(7)
      ..write(obj.voteHash)
      ..writeByte(8)
      ..write(obj.nonce)
      ..writeByte(9)
      ..write(obj.signature);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecureVoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
