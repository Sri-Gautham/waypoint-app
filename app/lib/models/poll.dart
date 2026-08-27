/// A poll attached to a chat message — lets the group vote on dates,
/// destination, or activities together. Single-choice: voting for a new
/// option moves your vote off whatever you'd picked before.
class Poll {
  Poll({required this.question, required List<String> options}) : votesByOption = {for (final o in options) o: <String>{}};

  final String question;
  final Map<String, Set<String>> votesByOption;

  List<String> get options => votesByOption.keys.toList();
  int get totalVotes => votesByOption.values.fold(0, (sum, voters) => sum + voters.length);

  String? optionVotedBy(String voter) {
    for (final entry in votesByOption.entries) {
      if (entry.value.contains(voter)) return entry.key;
    }
    return null;
  }

  void vote(String option, String voter) {
    for (final voters in votesByOption.values) {
      voters.remove(voter);
    }
    votesByOption[option]?.add(voter);
  }
}
