/// 共同支出分攤模式
enum SplitMode {
  /// 自動按成員顯示收入比例分攤
  byIncomeRatio,

  /// 指定單一成員支付全部
  byPayer,

  /// 平均分攤
  equal,

  /// 自由設定：各成員自訂金額
  custom,
}

/// 共同帳本的一筆交易（支出/收入）
class SharedTransaction {
  final String id;
  final double amount; // 正數
  final bool isIncome; // true = 共同收入（如租金收入），false = 共同支出
  final String categoryName; // 如「房租」「水電」
  final DateTime date;
  final String note;
  final SplitMode splitMode;

  /// byPayer：付款成員 id
  /// custom：各成員金額（memberId -> amount）
  /// 其他模式：可為空
  final Map<String, double> customAmounts;
  final String? payerId;

  /// 是否同步到各成員的個人帳本（依分攤金額，扣個人預算）
  final bool syncToPersonal;

  /// 新增交易當下固化的分攤結果。`null` 代表舊版資料，讀取時動態計算。
  final Map<String, double>? splitSnapshot;

  const SharedTransaction({
    required this.id,
    required this.amount,
    this.isIncome = false,
    this.categoryName = '',
    required this.date,
    this.note = '',
    this.splitMode = SplitMode.equal,
    this.customAmounts = const {},
    this.payerId,
    this.syncToPersonal = true,
    this.splitSnapshot,
  });

  SharedTransaction withSplitSnapshot(Map<String, double> memberAmounts) =>
      SharedTransaction(
        id: id,
        amount: amount,
        isIncome: isIncome,
        categoryName: categoryName,
        date: date,
        note: note,
        splitMode: splitMode,
        customAmounts: customAmounts,
        payerId: payerId,
        syncToPersonal: syncToPersonal,
        splitSnapshot: Map.unmodifiable(memberAmounts),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'isIncome': isIncome,
    'categoryName': categoryName,
    'date': date.toIso8601String(),
    'note': note,
    'splitMode': splitMode.name,
    'customAmounts': customAmounts,
    'payerId': payerId,
    'syncToPersonal': syncToPersonal,
    if (splitSnapshot != null) 'splitSnapshot': splitSnapshot,
  };

  factory SharedTransaction.fromJson(
    Map<String, dynamic> json,
  ) => SharedTransaction(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    isIncome: (json['isIncome'] as bool?) ?? false,
    categoryName: (json['categoryName'] as String?) ?? '',
    date: DateTime.parse(json['date'] as String),
    note: (json['note'] as String?) ?? '',
    splitMode: SplitMode.values.byName(json['splitMode'] as String? ?? 'equal'),
    customAmounts: (json['customAmounts'] as Map<String, dynamic>? ?? {}).map(
      (mapKey, selectedValue) =>
          MapEntry(mapKey, (selectedValue as num).toDouble()),
    ),
    payerId: json['payerId'] as String?,
    syncToPersonal: (json['syncToPersonal'] as bool?) ?? true,
    splitSnapshot: (json['splitSnapshot'] as Map<String, dynamic>?)?.map(
      (memberId, snapshotAmount) =>
          MapEntry(memberId, (snapshotAmount as num).toDouble()),
    ),
  );
}
