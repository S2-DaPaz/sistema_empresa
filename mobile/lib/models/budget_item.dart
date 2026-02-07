class BudgetItemData {
  BudgetItemData({
    required this.id,
    required this.description,
    required this.qty,
    required this.unitPrice,
    this.productId,
  });

  final String id;
  String description;
  double qty;
  double unitPrice;
  int? productId;

  factory BudgetItemData.create() {
    return BudgetItemData(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      description: '',
      qty: 1,
      unitPrice: 0,
    );
  }

  factory BudgetItemData.fromMap(Map<String, dynamic> item) {
    final qty = item['qty'] ?? item['quantity'] ?? 1;
    final unitPrice = item['unit_price'] ?? item['unitPrice'] ?? 0;
    return BudgetItemData(
      id: item['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      description: item['description']?.toString() ?? '',
      qty: double.tryParse(qty.toString()) ?? 0,
      unitPrice: double.tryParse(unitPrice.toString()) ?? 0,
      productId: item['product_id'] as int?,
    );
  }

  BudgetItemData copyWith({
    String? description,
    double? qty,
    double? unitPrice,
    int? productId,
  }) {
    return BudgetItemData(
      id: id,
      description: description ?? this.description,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      productId: productId ?? this.productId,
    );
  }
}
