import '../data/repository.dart';
import '../models/member.dart';
import '../models/shared_transaction.dart';
import 'shared_transaction_split_service.dart';

/// 共同帳本核心邏輯：分攤計算、成員結餘、帳本統計
class SharedLedgerService {
  final BudgetRepository repository;
  final SharedTransactionSplitService _splitService =
      const SharedTransactionSplitService();

  SharedLedgerService(this.repository);

  // ── 成員 ────────────────────────────────────────────

  List<Member> getMembers() => repository.getMembers();

  Future<void> upsertMember(Member member) => repository.upsertMember(member);

  Future<void> removeMember(String id) => repository.removeMember(id);

  List<SharedTransaction> getTransactions(DateTime month) =>
      repository
          .getSharedTransactions()
          .where(
            (transaction) =>
                transaction.date.year == month.year &&
                transaction.date.month == month.month,
          )
          .toList()
        ..sort(
          (allocation, rightValue) =>
              rightValue.date.compareTo(allocation.date),
        );

  // ── 帳本統計 ────────────────────────────────────────

  /// 共同帳本顯示總收入（成員 shownIncome 加總）
  double totalShownIncome() => getMembers().fold(
    0,
    (runningTotal, member) => runningTotal + member.shownIncome,
  );

  /// 本月共同支出總額
  double totalSharedExpense(DateTime month) => getTransactions(month)
      .where((transaction) => !transaction.isIncome)
      .fold(
        0,
        (runningTotal, transaction) => runningTotal + transaction.amount,
      );

  /// 本月共同收入總額
  double totalSharedIncome(DateTime month) => getTransactions(month)
      .where((transaction) => transaction.isIncome)
      .fold(
        0,
        (runningTotal, transaction) => runningTotal + transaction.amount,
      );

  /// 共同帳本結餘 = 顯示總收入 + 共同收入 − 共同支出
  double sharedBalance(DateTime month) =>
      totalShownIncome() + totalSharedIncome(month) - totalSharedExpense(month);

  // ── 分攤計算 ────────────────────────────────────────

  /// 計算一筆共同交易的成員分攤（memberId -> 金額）
  Map<String, double> splitOf(
    SharedTransaction transaction,
    List<Member> members,
  ) {
    return _splitService.calculate(transaction, members);
  }

  SharedTransaction freezeSplit(SharedTransaction transaction) =>
      _splitService.freeze(transaction, getMembers());

  /// 指定成員本月的分攤總額
  double memberShareTotal(String memberId, DateTime month) {
    double sum = 0;
    for (final transaction in getTransactions(month)) {
      if (transaction.isIncome) continue; // 收入不分攤
      final split = splitOf(transaction, getMembers());
      sum += split[memberId] ?? 0;
    }
    return sum;
  }

  /// 成員本月結餘 = 顯示收入 − 分攤總額
  double memberBalance(String memberId, DateTime month) {
    final member = getMembers()
        .where((member) => member.id == memberId)
        .firstOrNull;
    if (member == null) return 0;
    return member.shownIncome - memberShareTotal(memberId, month);
  }
}

extension<ElementType> on Iterable<ElementType> {
  ElementType? get firstOrNull {
    final elementIterator = iterator;
    return elementIterator.moveNext() ? elementIterator.current : null;
  }
}
