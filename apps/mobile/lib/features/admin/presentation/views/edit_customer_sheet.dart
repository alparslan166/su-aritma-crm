import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";

import "../../../../core/error/error_handler.dart";
import "../../application/customer_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/customer.dart";
import "customer_detail_page.dart" show customerDetailProvider;

class EditCustomerSheet extends ConsumerStatefulWidget {
  const EditCustomerSheet({super.key, required this.customer});

  final Customer customer;

  @override
  ConsumerState<EditCustomerSheet> createState() => _EditCustomerSheetState();
}

class _EditCustomerSheetState extends ConsumerState<EditCustomerSheet> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _debtAmountController;
  late final TextEditingController _installmentCountController;
  late final TextEditingController _installmentIntervalDaysController;

  bool? _hasDebt;
  bool _debtHasInstallment = false;
  DateTime? _createdAt;
  DateTime? _nextDebtDate;
  DateTime? _installmentStartDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    final customer = widget.customer;
    _nameController = TextEditingController(text: customer.name);
    _phoneController = TextEditingController(text: customer.phone);
    _emailController = TextEditingController(text: customer.email ?? "");
    _addressController = TextEditingController(text: customer.address);
    _debtAmountController = TextEditingController(
      text: customer.debtAmount?.toStringAsFixed(2) ?? "",
    );
    _installmentCountController = TextEditingController(
      text: customer.installmentCount?.toString() ?? "",
    );
    _installmentIntervalDaysController = TextEditingController(
      text: customer.installmentIntervalDays?.toString() ?? "",
    );

    _hasDebt = customer.hasDebt;
    _debtHasInstallment = customer.hasInstallment;
    _createdAt = customer.createdAt;
    _nextDebtDate = customer.nextDebtDate;
    _installmentStartDate = customer.installmentStartDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _debtAmountController.dispose();
    _installmentCountController.dispose();
    _installmentIntervalDaysController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
    });
    try {
      // Prepare debt data
      final hasDebt = _hasDebt == true;
      final newDebtAmount = hasDebt && _debtAmountController.text.isNotEmpty
          ? double.tryParse(_debtAmountController.text)
          : null;

      // Calculate remaining debt: if new debt is set, add to existing remaining debt
      double? remainingDebtAmount;
      if (hasDebt && newDebtAmount != null) {
        final existingRemaining = widget.customer.remainingDebtAmount ?? 0.0;
        remainingDebtAmount = existingRemaining + newDebtAmount;
      }

      // Calculate total debt: if new debt is set, add to existing debt
      double? debtAmount;
      if (hasDebt && newDebtAmount != null) {
        final existingDebt = widget.customer.debtAmount ?? 0.0;
        debtAmount = existingDebt + newDebtAmount;
      }

      final hasInstallment = hasDebt && _debtHasInstallment;
      final installmentCount =
          hasInstallment && _installmentCountController.text.isNotEmpty
          ? int.tryParse(_installmentCountController.text)
          : null;
      final installmentIntervalDays =
          hasInstallment && _installmentIntervalDaysController.text.isNotEmpty
          ? int.tryParse(_installmentIntervalDaysController.text)
          : null;

      // Show confirmation dialog for debt changes
      if (hasDebt && newDebtAmount != null && newDebtAmount > 0) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Borç Ekleme Onayı"),
            content: Text(
              "${newDebtAmount.toStringAsFixed(2)} TL borç eklenecek.\n"
              "Mevcut borç: ${widget.customer.remainingDebtAmount?.toStringAsFixed(2) ?? "0.00"} TL\n"
              "Yeni toplam borç: ${remainingDebtAmount?.toStringAsFixed(2) ?? "0.00"} TL\n\n"
              "Bu işlemi onaylıyor musunuz?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("İptal"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Onayla"),
              ),
            ],
          ),
        );
        if (confirm != true) {
          if (mounted) {
            setState(() {
              _submitting = false;
            });
          }
          return;
        }
      }

      // Update customer
      await ref
          .read(adminRepositoryProvider)
          .updateCustomer(
            id: widget.customer.id,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            location: null,
            createdAt: _createdAt,
            hasDebt: hasDebt,
            debtAmount: debtAmount,
            remainingDebtAmount: remainingDebtAmount,
            hasInstallment: hasInstallment,
            installmentCount: installmentCount,
            nextDebtDate: _nextDebtDate,
            installmentStartDate: _installmentStartDate,
            installmentIntervalDays: installmentIntervalDays,
          );

      await ref.read(customerListProvider.notifier).refresh();
      // Invalidate customer detail provider to refresh the detail page
      ref.invalidate(customerDetailProvider(widget.customer.id));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Müşteri güncellendi")));
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: "Geri",
        ),
        title: const Text("Müşteri Düzenle"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Kayıt Tarihi
                if (_createdAt != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Kayıt Tarihi: ${DateFormat("dd MMM yyyy").format(_createdAt!)}",
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _createdAt!,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 3650),
                            ),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _createdAt = picked;
                            });
                          }
                        },
                        child: const Text("Tarih Seç"),
                      ),
                    ],
                  ),
                if (_createdAt != null) const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "İsim"),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => value == null || value.trim().length < 2
                      ? "İsim girin"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: "Telefon"),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.trim().length < 6
                      ? "Telefon girin"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "E-posta (opsiyonel)",
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: "Adres",
                    hintText: "Şehir, ilçe, mahalle, sokak, bina no",
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) => value == null || value.trim().length < 3
                      ? "Adres girin"
                      : null,
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  "Borç Bilgileri (Opsiyonel)",
                  style: Theme.of(context).textTheme.titleMedium,
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
                              ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                              : null,
                          side: BorderSide(
                            color: _hasDebt == true
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade300,
                            width: _hasDebt == true ? 2 : 1,
                          ),
                        ),
                        child: const Text("Evet"),
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
                              ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                              : null,
                          side: BorderSide(
                            color: _hasDebt == false
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade300,
                            width: _hasDebt == false ? 2 : 1,
                          ),
                        ),
                        child: const Text("Hayır"),
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
                  // Ödeme Tarihi - Sadece taksit yoksa göster
                  if (!_debtHasInstallment) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Ödeme Tarihi: ${_nextDebtDate != null ? DateFormat("dd MMM yyyy").format(_nextDebtDate!) : "Seçilmedi"}",
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
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _debtHasInstallment = true;
                              _nextDebtDate =
                                  null; // Taksit seçildiğinde ödeme tarihini temizle
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _debtHasInstallment
                                ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                : null,
                            side: BorderSide(
                              color: _debtHasInstallment
                                  ? const Color(0xFF2563EB)
                                  : Colors.grey.shade300,
                              width: _debtHasInstallment ? 2 : 1,
                            ),
                          ),
                          child: const Text("Taksit Var"),
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
                                ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                : null,
                            side: BorderSide(
                              color: !_debtHasInstallment
                                  ? const Color(0xFF2563EB)
                                  : Colors.grey.shade300,
                              width: !_debtHasInstallment ? 2 : 1,
                            ),
                          ),
                          child: const Text("Taksit Yok"),
                        ),
                      ),
                    ],
                  ),
                  if (_debtHasInstallment) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _installmentCountController,
                      decoration: const InputDecoration(
                        labelText: "Taksit Sayısı",
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Taksit Başlama Tarihi: ${_installmentStartDate != null ? DateFormat("dd MMM yyyy").format(_installmentStartDate!) : "Seçilmedi"}",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        TextButton.icon(
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
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: const Text("Tarih Seç"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Ödeme Tekrar Günü
                    TextFormField(
                      controller: _installmentIntervalDaysController,
                      decoration: const InputDecoration(
                        labelText: "Ödeme kaç günde bir olacak?",
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
                const SizedBox(height: 24),
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
                        : const Text("Güncelle"),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
