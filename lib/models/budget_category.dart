/// 預算類別（信封）：如「伙食」「娛樂」
class BudgetCategory {
  final String id;
  final String name;
  final double monthlyLimit; // 每月預算上限；0 = 未設定上限
  final String iconName; // Material Icons 名稱
  final int colorValue; // ARGB int

  const BudgetCategory({
    required this.id,
    required this.name,
    this.monthlyLimit = 0,
    this.iconName = 'category',
    this.colorValue = 0, // 0 = 未設定（自動分配）
  });

  bool get hasLimit => monthlyLimit > 0;

  BudgetCategory copyWith({
    String? name,
    double? monthlyLimit,
    String? iconName,
    int? colorValue,
  }) => BudgetCategory(
    id: id,
    name: name ?? this.name,
    monthlyLimit: monthlyLimit ?? this.monthlyLimit,
    iconName: iconName ?? this.iconName,
    colorValue: colorValue ?? this.colorValue,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'monthlyLimit': monthlyLimit,
    'iconName': iconName,
    'colorValue': colorValue,
  };

  factory BudgetCategory.fromJson(Map<String, dynamic> json) => BudgetCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    monthlyLimit: (json['monthlyLimit'] as num?)?.toDouble() ?? 0,
    iconName: (json['iconName'] as String?) ?? 'category',
    colorValue: (json['colorValue'] as int?) ?? 0,
  );
}
