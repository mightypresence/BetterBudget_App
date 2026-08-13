/// 交易類型
enum TransactionType { income, expense }

/// 一筆收入或支出
class Transaction {
  final String id;
  final TransactionType type;
  final double amount; // 一律為正數，方向由 [type] 決定
  final String? categoryId; // 支出必填；收入可選
  final DateTime date;
  final String note;

  /// 若此交易是共同支出的個人鏡像，記錄其明確來源；舊資料為 `null`。
  final String? sourceSharedTransactionId;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    required this.date,
    this.note = '',
    this.sourceSharedTransactionId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'categoryId': categoryId,
    'date': date.toIso8601String(),
    'note': note,
    'sourceSharedTransactionId': sourceSharedTransactionId,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    type: TransactionType.values.byName(json['type'] as String),
    amount: (json['amount'] as num).toDouble(),
    categoryId: json['categoryId'] as String?,
    date: DateTime.parse(json['date'] as String),
    note: (json['note'] as String?) ?? '',
    sourceSharedTransactionId: json['sourceSharedTransactionId'] as String?,
  );
}
