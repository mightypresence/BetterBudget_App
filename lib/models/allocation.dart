/// 一筆收入分配到單一類別的金額
class Allocation {
  final String categoryId;
  final double amount;

  const Allocation({required this.categoryId, required this.amount});

  Map<String, dynamic> toJson() => {'categoryId': categoryId, 'amount': amount};

  factory Allocation.fromJson(Map<String, dynamic> json) => Allocation(
    categoryId: json['categoryId'] as String,
    amount: (json['amount'] as num).toDouble(),
  );
}

/// 一筆收入的完整分配記錄（核心特色）
class IncomeAllocation {
  final String transactionId; // 對應的收入交易
  final List<Allocation> allocations;

  const IncomeAllocation({
    required this.transactionId,
    this.allocations = const [],
  });

  double get totalAllocated =>
      allocations.fold(0, (sum, allocation) => sum + allocation.amount);

  Map<String, dynamic> toJson() => {
    'transactionId': transactionId,
    'allocations': allocations
        .map((allocation) => allocation.toJson())
        .toList(),
  };

  factory IncomeAllocation.fromJson(Map<String, dynamic> json) =>
      IncomeAllocation(
        transactionId: json['transactionId'] as String,
        allocations: (json['allocations'] as List? ?? [])
            .map(
              (currentItem) =>
                  Allocation.fromJson(currentItem as Map<String, dynamic>),
            )
            .toList(),
      );
}
