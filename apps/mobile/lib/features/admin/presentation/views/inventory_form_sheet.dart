import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../application/inventory_list_notifier.dart";
import "../../data/admin_repository.dart";

class InventoryFormSheet extends ConsumerStatefulWidget {
  const InventoryFormSheet({super.key});

  @override
  ConsumerState<InventoryFormSheet> createState() => _InventoryFormSheetState();
}

class _InventoryFormSheetState extends ConsumerState<InventoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stockQtyController = TextEditingController();
  final _unitPriceController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _stockQtyController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .createInventoryItem(
            name: _nameController.text.trim(),
            category: "Genel", // Varsayılan kategori
            stockQty: int.parse(_stockQtyController.text.trim()),
            criticalThreshold: 0, // Varsayılan kritik eşik
            unitPrice: double.parse(_unitPriceController.text.trim()),
            photoUrl: null,
          );
      await ref.read(inventoryListProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Yeni ürün eklendi")));
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Ürün eklenemedi: $error")));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Ürün Ekle", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key("inventory-name-field"),
                controller: _nameController,
                decoration: const InputDecoration(labelText: "İsim"),
                validator: (value) => value == null || value.trim().length < 2
                    ? "İsim girin"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key("inventory-stock-qty-field"),
                controller: _stockQtyController,
                decoration: const InputDecoration(labelText: "Stok Miktarı"),
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
                key: const Key("inventory-unit-price-field"),
                controller: _unitPriceController,
                decoration: const InputDecoration(labelText: "Birim Fiyat (₺)"),
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
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Kaydet"),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }
}
