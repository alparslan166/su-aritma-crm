import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:mobile/widgets/admin_app_bar.dart";

import "../../../../core/error/error_handler.dart";
import "../../data/admin_repository.dart";
import "../../data/models/customer.dart";

/// Müşteri borç ödemesi için fatura oluşturma sayfası
/// İş gerektirmez, sadece müşteri ve ödeme bilgileriyle çalışır
class PaymentInvoiceCreatePage extends ConsumerStatefulWidget {
  const PaymentInvoiceCreatePage({
    super.key,
    required this.customer,
    this.paymentAmount,
    this.paymentDate,
  });

  final Customer customer;
  final double? paymentAmount;
  final DateTime? paymentDate;

  @override
  ConsumerState<PaymentInvoiceCreatePage> createState() =>
      _PaymentInvoiceCreatePageState();
}

class _PaymentInvoiceCreatePageState
    extends ConsumerState<PaymentInvoiceCreatePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerNameController;
  late TextEditingController _customerPhoneController;
  late TextEditingController _customerAddressController;
  late TextEditingController _customerEmailController;
  late TextEditingController _amountController;
  late TextEditingController _taxController;
  late TextEditingController _totalController;
  late TextEditingController _notesController;
  late DateTime _paymentDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _customerNameController = TextEditingController(text: customer.name);
    _customerPhoneController = TextEditingController(text: customer.phone);
    _customerAddressController = TextEditingController(text: customer.address);
    _customerEmailController = TextEditingController(
      text: customer.email ?? "",
    );
    _paymentDate = widget.paymentDate ?? DateTime.now();
    _amountController = TextEditingController(
      text: widget.paymentAmount?.toStringAsFixed(2) ?? "",
    );
    _taxController = TextEditingController(text: "0.00");
    _totalController = TextEditingController(
      text: widget.paymentAmount?.toStringAsFixed(2) ?? "",
    );
    _notesController = TextEditingController(text: "Borç ödemesi");

    // Calculate total when amount or tax changes
    _amountController.addListener(_calculateTotal);
    _taxController.addListener(_calculateTotal);
  }

  void _calculateTotal() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final tax = double.tryParse(_taxController.text) ?? 0.0;
    final total = amount + tax;
    _totalController.text = total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _customerEmailController.dispose();
    _amountController.dispose();
    _taxController.dispose();
    _totalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(adminRepositoryProvider);
      
      // Create customer-only invoice (no job required)
      final invoice = await repository.createCustomerInvoice(
        customerId: widget.customer.id,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        customerEmail: _customerEmailController.text.trim().isEmpty
            ? null
            : _customerEmailController.text.trim(),
        subtotal: double.tryParse(_amountController.text) ?? 0,
        tax: double.tryParse(_taxController.text) ?? 0,
        total: double.tryParse(_totalController.text) ?? 0,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        invoiceDate: _paymentDate,
      );

      // Open PDF after creation
      await repository.openInvoicePdf(invoice.id);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ödeme faturası oluşturuldu ve açıldı")),
        );
      }
    } catch (error) {
      if (mounted) {
        ErrorHandler.showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AdminAppBar(title: Text("Ödeme Faturası Oluştur")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bilgi Kartı
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Bu fatura borç ödemesi için oluşturulacaktır. İş bilgisi içermez.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Müşteri Bilgileri",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: "Müşteri Adı *",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? "Müşteri adı gerekli"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerPhoneController,
                      decoration: const InputDecoration(
                        labelText: "Telefon *",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? "Telefon gerekli"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerAddressController,
                      decoration: const InputDecoration(
                        labelText: "Adres *",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? "Adres gerekli"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerEmailController,
                      decoration: const InputDecoration(
                        labelText: "E-posta (opsiyonel)",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ödeme Bilgileri",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setState(() => _paymentDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Ödeme Tarihi *",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(DateFormat("dd MMM yyyy").format(_paymentDate)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Fatura Tutarları",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: "Ödeme Tutarı (₺) *",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Tutar gerekli";
                        }
                        final num = double.tryParse(value);
                        if (num == null || num <= 0) {
                          return "Geçerli bir tutar girin";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _taxController,
                      decoration: const InputDecoration(
                        labelText: "KDV (₺)",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _totalController,
                      decoration: const InputDecoration(
                        labelText: "Toplam (₺) *",
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Notlar (opsiyonel)",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: "Fatura notları",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _createInvoice,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Ödeme Faturası Oluştur"),
            ),
          ],
        ),
      ),
    );
  }
}
