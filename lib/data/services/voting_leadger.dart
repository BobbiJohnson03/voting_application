import '../models/secure_vote.dart';
import '../repositories/vote_repository.dart';

class VotingLedger {
  final VoteRepository _voteRepository;

  VotingLedger(this._voteRepository);

  // Add vote with comprehensive validation
  Future<void> addVote(SecureVote vote, String secretKey) async {
    // 1. Validate signature
    if (!vote.validateSignature(secretKey)) {
      throw Exception('Invalid vote signature');
    }

    // 2. Validate hash integrity
    if (!vote.isIntegrityValid) {
      throw Exception('Vote hash integrity check failed');
    }

    // 3. Verify hash chain
    final lastVote = await _voteRepository.getLastVoteForSession(
      vote.sessionId,
    );
    if (lastVote != null && vote.previousVoteHash != lastVote.voteHash) {
      throw Exception(
        'Hash chain broken. Expected: ${lastVote.voteHash}, Got: ${vote.previousVoteHash}',
      );
    }

    // 4. For first vote, previousVoteHash should be '0' or similar
    if (lastVote == null && vote.previousVoteHash != '0') {
      throw Exception('First vote should have previousVoteHash = "0"');
    }

    // 5. Check for duplicate ticket usage
    final exists = await _voteRepository.existsByTicketId(vote.ticketId);
    if (exists) {
      throw Exception('Ticket already used for voting: ${vote.ticketId}');
    }

    // All checks passed - save the vote
    await _voteRepository.put(vote);
  }

  // Get vote chain for a session (for verification/audit)
  Future<List<SecureVote>> getVoteChain(String sessionId) async {
    final votes = await _voteRepository.forSession(sessionId);
    votes.sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    return votes;
  }

  // Verify entire hash chain for a session
  Future<bool> verifyChainIntegrity(String sessionId) async {
    final votes = await getVoteChain(sessionId);

    if (votes.isEmpty) return true;

    // Check first vote
    if (votes.first.previousVoteHash != '0') {
      return false;
    }

    // Check subsequent votes
    for (int i = 1; i < votes.length; i++) {
      if (votes[i].previousVoteHash != votes[i - 1].voteHash) {
        return false;
      }

      if (!votes[i].isIntegrityValid) {
        return false;
      }
    }

    return true;
  }

  // Get the current ledger head hash
  Future<String> getLedgerHeadHash(String sessionId) async {
    final lastVote = await _voteRepository.getLastVoteForSession(sessionId);
    return lastVote?.voteHash ?? '0';
  }
}
