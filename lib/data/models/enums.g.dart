// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enums.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VotingTypeAdapter extends TypeAdapter<VotingType> {
  @override
  final int typeId = 0;

  @override
  VotingType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return VotingType.nonsecret;
      case 1:
        return VotingType.secret;
      default:
        return VotingType.nonsecret;
    }
  }

  @override
  void write(BinaryWriter writer, VotingType obj) {
    switch (obj) {
      case VotingType.nonsecret:
        writer.writeByte(0);
        break;
      case VotingType.secret:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VotingTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AnswersSchemaAdapter extends TypeAdapter<AnswersSchema> {
  @override
  final int typeId = 1;

  @override
  AnswersSchema read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AnswersSchema.yesNo;
      case 1:
        return AnswersSchema.yesNoAbstain;
      case 2:
        return AnswersSchema.custom;
      default:
        return AnswersSchema.yesNo;
    }
  }

  @override
  void write(BinaryWriter writer, AnswersSchema obj) {
    switch (obj) {
      case AnswersSchema.yesNo:
        writer.writeByte(0);
        break;
      case AnswersSchema.yesNoAbstain:
        writer.writeByte(1);
        break;
      case AnswersSchema.custom:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnswersSchemaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VotingStatusAdapter extends TypeAdapter<VotingStatus> {
  @override
  final int typeId = 2;

  @override
  VotingStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return VotingStatus.open;
      case 1:
        return VotingStatus.closed;
      case 2:
        return VotingStatus.archived;
      case 3:
        return VotingStatus.score;
      default:
        return VotingStatus.open;
    }
  }

  @override
  void write(BinaryWriter writer, VotingStatus obj) {
    switch (obj) {
      case VotingStatus.open:
        writer.writeByte(0);
        break;
      case VotingStatus.closed:
        writer.writeByte(1);
        break;
      case VotingStatus.archived:
        writer.writeByte(2);
        break;
      case VotingStatus.score:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VotingStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AuditActionAdapter extends TypeAdapter<AuditAction> {
  @override
  final int typeId = 3;

  @override
  AuditAction read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AuditAction.sessionCreated;
      case 1:
        return AuditAction.voteSubmitted;
      case 2:
        return AuditAction.ticketIssued;
      case 3:
        return AuditAction.meetingJoined;
      case 4:
        return AuditAction.votingClosed;
      case 5:
        return AuditAction.securityViolation;
      default:
        return AuditAction.sessionCreated;
    }
  }

  @override
  void write(BinaryWriter writer, AuditAction obj) {
    switch (obj) {
      case AuditAction.sessionCreated:
        writer.writeByte(0);
        break;
      case AuditAction.voteSubmitted:
        writer.writeByte(1);
        break;
      case AuditAction.ticketIssued:
        writer.writeByte(2);
        break;
      case AuditAction.meetingJoined:
        writer.writeByte(3);
        break;
      case AuditAction.votingClosed:
        writer.writeByte(4);
        break;
      case AuditAction.securityViolation:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserRoleAdapter extends TypeAdapter<UserRole> {
  @override
  final int typeId = 4;

  @override
  UserRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UserRole.participant;
      case 1:
        return UserRole.moderator;
      case 2:
        return UserRole.admin;
      default:
        return UserRole.participant;
    }
  }

  @override
  void write(BinaryWriter writer, UserRole obj) {
    switch (obj) {
      case UserRole.participant:
        writer.writeByte(0);
        break;
      case UserRole.moderator:
        writer.writeByte(1);
        break;
      case UserRole.admin:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
