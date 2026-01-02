import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";

import "../../../../core/error/error_handler.dart";
import "../../application/customer_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/inventory_item.dart";
import "../../../dashboard/presentation/home_page_provider.dart";
import "customer_detail_page.dart";
import "../../application/customer_detail_provider.dart";

class AddJobToCustomerSheet extends ConsumerStatefulWidget {
  const AddJobToCustomerSheet({
    super.key,
    required this.customerId,
    this.scrollController,
  });

  final String customerId;
  final ScrollController? scrollController;

  @override
  ConsumerState<AddJobToCustomerSheet> createState() =>
      _AddJobToCustomerSheetState();
}

class _AddJobToCustomerSheetState extends ConsumerState<AddJobToCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _debtAmountController = TextEditingController();
  final _installmentCountController = TextEditingController();
  final _installmentIntervalDaysController = TextEditingController();
  DateTime? _scheduledAt;
  bool _hasInstallment = false;
  bool? _hasDebt; // null = not selected, true = yes, false = no
  bool _debtHasInstallment = false;
  DateTime? _nextDebtDate;
  DateTime? _installmentStartDate;
  final Map<String, int> _selectedMaterials = {};
  bool _deductFromStock = true; // Stoktan düşülsün mü?
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _debtAmountController.dispose();
    _installmentCountController.dispose();
    _installmentIntervalDaysController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _scheduledAt = picked;
      });
    }
  }

  Future<void> _selectMaterials() async {
    final inventory = await ref.read(adminRepositoryProvider).fetchInventory();
    if (!mounted) return;

    final result =
        await showDialog<({Map<String, int> selection, bool deductFromStock})>(
          context: context,
          builder: (context) => _MaterialSelectionDialog(
            inventory: inventory,
            initialSelection: _selectedMaterials,
          ),
        );
    if (result != null) {
      setState(() {
        _selectedMaterials.clear();
        _selectedMaterials.addAll(result.selection);
        _deductFromStock = result.deductFromStock;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
    });
    try {
      final materialIds = _selectedMaterials.entries
          .map((e) => {"inventoryItemId": e.key, "quantity": e.value})
          .toList();

      // Prepare debt data
      final hasDebt = _hasDebt == true;
      final debtAmount = hasDebt && _debtAmountController.text.isNotEmpty
          ? double.tryParse(_debtAmountController.text)
          : null;
      final hasInstallmentForDebt = hasDebt && _debtHasInstallment;
      final installmentCount =
          hasInstallmentForDebt && _installmentCountController.text.isNotEmpty
          ? int.tryParse(_installmentCountController.text)
          : null;
      final installmentIntervalDays =
          hasInstallmentForDebt &&
              _installmentIntervalDaysController.text.isNotEmpty
          ? int.tryParse(_installmentIntervalDaysController.text)
          : null;

      // Create job
      await ref
          .read(adminRepositoryProvider)
          .createJobForCustomer(
            customerId: widget.customerId,
            title: _titleController.text.trim(),
            scheduledAt: _scheduledAt,
            price: _priceController.text.isNotEmpty
                ? double.tryParse(_priceController.text)
                : null,
            hasInstallment: _hasInstallment,
            materialIds: materialIds.isNotEmpty ? materialIds : null,
          );

      // Update customer debt if specified
      if (hasDebt && debtAmount != null) {
        await ref
            .read(adminRepositoryProvider)
            .updateCustomer(
              id: widget.customerId,
              hasDebt: true,
              debtAmount: debtAmount,
              hasInstallment: hasInstallmentForDebt,
              installmentCount: installmentCount,
              installmentIntervalDays: installmentIntervalDays,
            );
      }

      await ref.read(customerListProvider.notifier).refresh();
      ref.invalidate(customerDetailProvider(widget.customerId));

      // Ana sayfa grafik ve istatistiklerini statik olarak yenile
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(customerCategoryDataProvider);
      ref.invalidate(overduePaymentsCustomersProvider);
      ref.invalidate(upcomingMaintenanceProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("İş eklendi")));
    } catch (error) {
      if (!mounted) return;
      ErrorHandler.showError(context, error);
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(
                  "Müşteriye İş Ekle",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(),
          // Form content
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // İş Bilgileri
                    Text(
                      "İş Bilgileri",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: "İş Başlığı",
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) =>
                          value == null || value.trim().length < 2
                          ? "İş başlığı girin"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: "Ücret (TL)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _hasInstallment,
                      title: const Text("İş için Taksit"),
                      subtitle: const Text("İş ücreti taksitlendirilecek"),
                      onChanged: (value) {
                        setState(() {
                          _hasInstallment = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      readOnly: true,
                      controller: TextEditingController(
                        text: _scheduledAt != null
                            ? DateFormat("dd.MM.yyyy").format(_scheduledAt!)
                            : "",
                      ),
                      decoration: InputDecoration(
                        labelText: "Planlanan Tarih",
                        hintText: "Tarih seçin",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _pickDate,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _selectMaterials,
                      icon: const Icon(Icons.inventory_2),
                      label: Text(
                        _selectedMaterials.isEmpty
                            ? "Malzeme Seç"
                            : "${_selectedMaterials.length} malzeme seçildi",
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Borç Bilgileri
                    Text(
                      "Borç Bilgileri (Opsiyonel)",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _hasDebt = true;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _hasDebt == true
                                  ? const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.1)
                                  : null,
                              side: BorderSide(
                                color: _hasDebt == true
                                    ? const Color(0xFF2563EB)
                                    : Colors.grey.shade300,
                                width: _hasDebt == true ? 2 : 1,
                              ),
                            ),
                            child: const Text("Borç Var"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _hasDebt = false;
                                _debtAmountController.clear();
                                _debtHasInstallment = false;
                                _installmentCountController.clear();
                                _installmentIntervalDaysController.clear();
                                _nextDebtDate = null;
                                _installmentStartDate = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _hasDebt == false
                                  ? const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.1)
                                  : null,
                              side: BorderSide(
                                color: _hasDebt == false
                                    ? const Color(0xFF2563EB)
                                    : Colors.grey.shade300,
                                width: _hasDebt == false ? 2 : 1,
                              ),
                            ),
                            child: const Text("Borç Yok"),
                          ),
                        ),
                      ],
                    ),
                    if (_hasDebt == true) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _debtAmountController,
                        decoration: const InputDecoration(
                          labelText: "Borç Miktarı (TL)",
                          labelStyle: TextStyle(color: Colors.black),
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (_hasDebt == true &&
                              (value == null || value.trim().isEmpty)) {
                            return "Borç miktarı girin";
                          }
                          if (value != null && value.trim().isNotEmpty) {
                            final amount = double.tryParse(value);
                            if (amount == null || amount <= 0) {
                              return "Geçerli bir miktar girin";
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Ödeme Tarihi
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Ödeme Tarihi: ${_nextDebtDate != null ? DateFormat("dd MMM yyyy", "tr_TR").format(_nextDebtDate!) : "Seçilmedi"}",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _nextDebtDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 3650),
                                ),
                              );
                              if (picked != null) {
                                setState(() {
                                  _nextDebtDate = picked;
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: const Text("Tarih Seç"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _debtHasInstallment = true;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _debtHasInstallment
                                    ? const Color(
                                        0xFF2563EB,
                                      ).withValues(alpha: 0.1)
                                    : null,
                                side: BorderSide(
                                  color: _debtHasInstallment
                                      ? const Color(0xFF2563EB)
                                      : Colors.grey.shade300,
                                  width: _debtHasInstallment ? 2 : 1,
                                ),
                              ),
                              child: const Text("Taksitli Satış Var"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _debtHasInstallment = false;
                                  _installmentCountController.clear();
                                  _installmentIntervalDaysController.clear();
                                  _installmentStartDate = null;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: !_debtHasInstallment
                                    ? const Color(
                                        0xFF2563EB,
                                      ).withValues(alpha: 0.1)
                                    : null,
                                side: BorderSide(
                                  color: !_debtHasInstallment
                                      ? const Color(0xFF2563EB)
                                      : Colors.grey.shade300,
                                  width: !_debtHasInstallment ? 2 : 1,
                                ),
                              ),
                              child: const Text("Taksitli Satış Yok"),
                            ),
                          ),
                        ],
                      ),
                      if (_debtHasInstallment) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _installmentCountController,
                          decoration: const InputDecoration(
                            labelText: "Kaç taksit olacak?",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (_debtHasInstallment &&
                                (value == null || value.trim().isEmpty)) {
                              return "Taksit sayısı girin";
                            }
                            if (value != null && value.trim().isNotEmpty) {
                              final count = int.tryParse(value);
                              if (count == null || count <= 0) {
                                return "Geçerli bir sayı girin";
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // Taksit Başlama Tarihi
                        TextFormField(
                          readOnly: true,
                          controller: TextEditingController(
                            text: _installmentStartDate != null
                                ? DateFormat(
                                    "dd.MM.yyyy",
                                  ).format(_installmentStartDate!)
                                : "",
                          ),
                          decoration: InputDecoration(
                            labelText: "Taksit Başlama Tarihi",
                            hintText: "Tarih seçin",
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _installmentStartDate ?? DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 3650),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _installmentStartDate = picked;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Ödeme Tekrar Günü
                        TextFormField(
                          controller: _installmentIntervalDaysController,
                          decoration: const InputDecoration(
                            labelText: "Ödeme kaç günde bir olacak?",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.repeat),
                            helperText:
                                "Her kaç günde bir taksit ödemesi yapılacak? (örn: 30)",
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (_debtHasInstallment &&
                                (value == null || value.trim().isEmpty)) {
                              return "Ödeme tekrar günü girin";
                            }
                            if (value != null && value.trim().isNotEmpty) {
                              final days = int.tryParse(value);
                              if (days == null || days <= 0) {
                                return "Geçerli bir gün sayısı girin";
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "İş Ekle",
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom + 80,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialSelectionDialog extends StatefulWidget {
  const _MaterialSelectionDialog({
    required this.inventory,
    required this.initialSelection,
  });

  final List<InventoryItem> inventory;
  final Map<String, int> initialSelection;

  @override
  State<_MaterialSelectionDialog> createState() =>
      _MaterialSelectionDialogState();
}

class _MaterialSelectionDialogState extends State<_MaterialSelectionDialog> {
  final Map<String, int> _selection = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _deductFromStock = true; // Varsayılan olarak stoktan düşülsün

  @override
  void initState() {
    super.initState();
    _selection.addAll(widget.initialSelection);
    for (final item in widget.inventory) {
      _controllers[item.id] = TextEditingController(
        text: widget.initialSelection[item.id]?.toString() ?? "",
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Malzeme Seç"),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.inventory.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text("Stokta ürün bulunmuyor"),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.inventory.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = widget.inventory[index];
                    final controller = _controllers[item.id]!;
                    final quantity = int.tryParse(controller.text) ?? 0;
                    final isSelected = quantity > 0;
                    return InkWell(
                      onTap: () {
                        if (isSelected) {
                          controller.text = "";
                          _selection.remove(item.id);
                        } else {
                          controller.text = "1";
                          _selection[item.id] = 1;
                        }
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            // Checkbox
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (checked) {
                                  if (checked == true) {
                                    controller.text = "1";
                                    _selection[item.id] = 1;
                                  } else {
                                    controller.text = "";
                                    _selection.remove(item.id);
                                  }
                                  setState(() {});
                                },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Ürün bilgisi
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Stok: ${item.stockQty} ${item.unit}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Miktar girişi with + and - buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Minus button
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    onPressed: () {
                                      final currentQty =
                                          int.tryParse(controller.text) ?? 0;
                                      if (currentQty > 0) {
                                        final newQty = currentQty - 1;
                                        controller.text = newQty > 0
                                            ? newQty.toString()
                                            : "";
                                        if (newQty > 0) {
                                          _selection[item.id] = newQty;
                                        } else {
                                          _selection.remove(item.id);
                                        }
                                        setState(() {});
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      Icons.remove_circle_outline,
                                      size: 22,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Text field
                                SizedBox(
                                  width: 40,
                                  height: 32,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: "0",
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 6,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      final qty = int.tryParse(value) ?? 0;
                                      if (qty > 0) {
                                        _selection[item.id] = qty;
                                      } else {
                                        _selection.remove(item.id);
                                      }
                                      setState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Plus button
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    onPressed: () {
                                      final currentQty =
                                          int.tryParse(controller.text) ?? 0;
                                      // Stok sayısını geçme kontrolü
                                      if (currentQty < item.stockQty) {
                                        final newQty = currentQty + 1;
                                        controller.text = newQty.toString();
                                        _selection[item.id] = newQty;
                                        setState(() {});
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      Icons.add_circle_outline,
                                      size: 22,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (_selection.isNotEmpty) ...[
              const Divider(),
              CheckboxListTile(
                value: _deductFromStock,
                onChanged: (value) {
                  setState(() {
                    _deductFromStock = value ?? true;
                  });
                },
                title: const Text(
                  "Stoktan düşülsün mü?",
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  "İşaretlenirse seçilen malzemeler stoktan düşürülür",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("İptal"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop((selection: _selection, deductFromStock: _deductFromStock)),
          child: const Text("Tamam"),
        ),
      ],
    );
  }
}
