import '../models/member.dart';
import '../models/shared_transaction.dart';

/// 共同交易的唯一分攤規則來源，也負責把 legacy 動態分攤固化為 snapshot。
class SharedTransactionSplitService {
  const SharedTransactionSplitService();

  Map<String, double> calculate(
    SharedTransaction transaction,
    List<Member> members,
  ) {
    final splitSnapshot = transaction.splitSnapshot;
    if (splitSnapshot != null) return Map.unmodifiable(splitSnapshot);
    if (members.isEmpty) return const {};
    switch (transaction.splitMode) {
      case SplitMode.equal:
        return _splitEqual(transaction.amount, members);
      case SplitMode.byIncomeRatio:
        return _splitByIncomeRatio(transaction.amount, members);
      case SplitMode.byPayer:
        final matchingPayers = members.where(
          (member) => member.id == transaction.payerId,
        );
        if (matchingPayers.isEmpty) return const {};
        final payer = matchingPayers.first;
        return {payer.id: transaction.amount};
      case SplitMode.custom:
        final memberIds = members.map((member) => member.id).toSet();
        return transaction.customAmounts.entries
            .where((entry) => memberIds.contains(entry.key))
            .fold<Map<String, double>>({}, (memberAmounts, entry) {
              memberAmounts[entry.key] = entry.value;
              return memberAmounts;
            });
    }
  }

  SharedTransaction freeze(
    SharedTransaction transaction,
    List<Member> members,
  ) => transaction.splitSnapshot == null
      ? transaction.withSplitSnapshot(calculate(transaction, members))
      : transaction;

  List<SharedTransaction> freezeLegacyTransactions(
    List<SharedTransaction> transactions,
    List<Member> members,
  ) => transactions
      .map((transaction) => freeze(transaction, members))
      .toList(growable: false);

  Map<String, double> _splitEqual(double amount, List<Member> members) {
    final perMemberAmount = amount / members.length;
    final memberAmounts = <String, double>{};
    for (var memberIndex = 0; memberIndex < members.length; memberIndex++) {
      final member = members[memberIndex];
      memberAmounts[member.id] = memberIndex == members.length - 1
          ? amount - perMemberAmount * (members.length - 1)
          : perMemberAmount;
    }
    return memberAmounts;
  }

  Map<String, double> _splitByIncomeRatio(double amount, List<Member> members) {
    final totalShownIncome = members.fold<double>(
      0,
      (runningTotal, member) => runningTotal + member.shownIncome,
    );
    if (totalShownIncome <= 0) return _splitEqual(amount, members);
    final memberAmounts = <String, double>{};
    var assignedAmount = 0.0;
    for (var memberIndex = 0; memberIndex < members.length; memberIndex++) {
      final member = members[memberIndex];
      if (memberIndex == members.length - 1) {
        memberAmounts[member.id] = amount - assignedAmount;
      } else {
        final memberAmount = amount * member.shownIncome / totalShownIncome;
        memberAmounts[member.id] = memberAmount;
        assignedAmount += memberAmount;
      }
    }
    return memberAmounts;
  }
}
