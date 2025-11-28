import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:mobile/widgets/admin_app_bar.dart";

import "../../../../core/error/error_handler.dart";
import "../../application/inventory_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/inventory_item.dart";

class AdminInventoryDetailPage extends ConsumerStatefulWidget {
  const AdminInventoryDetailPage({
    super.key,
    required this.inventoryId,
    this.initialItem,
  });

  final String inventoryId;
  final InventoryItem? initialItem;

  @override
  ConsumerState<AdminInventoryDetailPage> createState() =>
      _AdminInventoryDetailPageState();
}

class _AdminInventoryDetailPageState
    extends ConsumerState<AdminInventoryDetailPage> {
  InventoryItem? _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.initialItem;
  }

  @override
  Widget build(BuildContext context) {
    // Use current item if available, otherwise use initial, otherwise fetch
    final item = _currentItem ?? widget.initialItem;
    if (item == null) {
      return Scaffold(
        appBar: const AdminAppBar(title: Text("Ürün Detayı")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AdminAppBar(
        title: Text(item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditSheet(item),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteItem(item),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Row(label: "İsim", value: item.name),
                  _Row(label: "Stok Miktarı", value: item.stockQty.toString()),
                  _Row(
                    label: "Birim Fiyat",
                    value: "${item.unitPrice.toStringAsFixed(2)} ₺",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSheet(InventoryItem item) async {
    final nameController = TextEditingController(text: item.name);
    final stockQtyController = TextEditingController(
      text: item.stockQty.toString(),
    );
    final unitPriceController = TextEditingController(
      text: item.unitPrice.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Ürün Düzenle",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: "İsim"),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                            ? "İsim girin"
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: stockQtyController,
                        decoration: const InputDecoration(
                          labelText: "Stok Miktarı",
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Stok miktarı girin";
                          }
                          final qty = int.tryParse(value.trim());
                          if (qty == null || qty < 0) {
                            return "Geçerli bir sayı girin";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: unitPriceController,
                        decoration: const InputDecoration(
                          labelText: "Birim Fiyat (₺)",
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Birim fiyat girin";
                          }
                          final price = double.tryParse(value.trim());
                          if (price == null || price < 0) {
                            return "Geçerli bir fiyat girin";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final repo = ref.read(adminRepositoryProvider);
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            try {
                              final updatedItem = await repo.updateInventoryItem(
                                id: item.id,
                                name: nameController.text.trim(),
                                category:
                                    item.category, // Mevcut kategoriyi koru
                                stockQty: int.parse(
                                  stockQtyController.text.trim(),
                                ),
                                criticalThreshold: item
                                    .criticalThreshold, // Mevcut değeri koru
                                unitPrice: double.parse(
                                  unitPriceController.text.trim(),
                                ),
                                photoUrl:
                                    item.photoUrl, // Mevcut fotoğrafı koru
                                sku: item.sku, // Mevcut SKU'yu koru
                                unit: item.unit, // Mevcut birimi koru
                                reorderPoint:
                                    item.reorderPoint, // Mevcut değeri koru
                                reorderQuantity:
                                    item.reorderQuantity, // Mevcut değeri koru
                                isActive: item.isActive, // Mevcut durumu koru
                              );
                              setState(() {
                                _currentItem = updatedItem;
                              });
                              ref.invalidate(inventoryListProvider);
                              navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text("Ürün güncellendi"),
                                ),
                              );
                            } catch (error) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text("Güncelleme başarısız: $error"),
                                ),
                              );
                            }
                          },
                          child: const Text("Kaydet"),
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ürünü Sil"),
        content: Text("${item.name} kaydını silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteInventoryItem(item.id);
      ref.invalidate(inventoryListProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text("${item.name} silindi")));
    } catch (error) {
      ErrorHandler.showError(context, error);
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
