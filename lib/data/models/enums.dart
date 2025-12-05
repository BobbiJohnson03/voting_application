import 'package:hive/hive.dart';
part 'enums.g.dart';

/* typ głosowania */
@HiveType(typeId: 0)
enum VotingType {
  @HiveField(0)
  nonsecret,
  @HiveField(1)
  secret,
}

/* schemat odpowiedzi */
@HiveType(typeId: 1)
enum AnswersSchema {
  @HiveField(0)
  yesNo,
  @HiveField(1)
  yesNoAbstain,
  @HiveField(2)
  custom,
}

/* Status głosowania */
@HiveType(typeId: 2)
enum VotingStatus {
  @HiveField(0)
  open,
  @HiveField(1)
  closed,
  @HiveField(2)
  archived,
  @HiveField(3)
  score, // Voting finished, results available for viewing
}

@HiveType(typeId: 3)
enum AuditAction {
  @HiveField(0)
  sessionCreated,
  @HiveField(1)
  voteSubmitted,
  @HiveField(2)
  ticketIssued,
  @HiveField(3)
  meetingJoined,
  @HiveField(4)
  votingClosed,
  @HiveField(5)
  securityViolation, // Added for security events
}

@HiveType(typeId: 4)
enum UserRole {
  @HiveField(0)
  participant,
  @HiveField(1)
  moderator,
  @HiveField(2)
  admin,
}
