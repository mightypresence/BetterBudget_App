/// 共同帳本成員
class Member {
  final String id;
  final String name;

  /// 個人真實月收入（自己的帳本 / 私房錢基準）
  final double actualIncome;

  /// 在共同帳本顯示的月收入（可低於 [actualIncome]，差額即私房錢）
  final double shownIncome;

  const Member({
    required this.id,
    required this.name,
    this.actualIncome = 0,
    this.shownIncome = 0,
  });

  /// 私房錢 = 實際收入 − 顯示收入
  double get privateSavings =>
      (actualIncome - shownIncome).clamp(0, double.infinity);

  Member copyWith({String? name, double? actualIncome, double? shownIncome}) =>
      Member(
        id: id,
        name: name ?? this.name,
        actualIncome: actualIncome ?? this.actualIncome,
        shownIncome: shownIncome ?? this.shownIncome,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'actualIncome': actualIncome,
    'shownIncome': shownIncome,
  };

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['id'] as String,
    name: json['name'] as String,
    actualIncome: (json['actualIncome'] as num?)?.toDouble() ?? 0,
    shownIncome: (json['shownIncome'] as num?)?.toDouble() ?? 0,
  );
}
