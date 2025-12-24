import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:mobile/widgets/admin_app_bar.dart";

import "../../../../core/error/error_handler.dart";
import "../../data/admin_repository.dart";
import "../../data/models/job.dart";

class InvoiceCreatePage extends ConsumerStatefulWidget {
  const InvoiceCreatePage({super.key, required this.job});

  final Job job;

  @override
  ConsumerState<InvoiceCreatePage> createState() => _InvoiceCreatePageState();
}

class _InvoiceCreatePageState extends ConsumerState<InvoiceCreatePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerNameController;
  late TextEditingController _customerPhoneController;
  late TextEditingController _customerAddressController;
  late TextEditingController _customerEmailController;
  late TextEditingController _jobTitleController;
  late TextEditingController _subtotalController;
  late TextEditingController _taxController;
  late TextEditingController _totalController;
  late TextEditingController _notesController;
  late DateTime _jobDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final job = widget.job;
    _customerNameController = TextEditingController(text: job.customer.name);
    _customerPhoneController = TextEditingController(text: job.customer.phone);
    _customerAddressController = TextEditingController(
      text: job.customer.address,
    );
    _customerEmailController = TextEditingController(
      text: job.customer.email ?? "",
    );
    _jobTitleController = TextEditingController(text: job.title);
    _jobDate =
        job.deliveredAt ?? job.scheduledAt ?? job.createdAt ?? DateTime.now();
    _subtotalController = TextEditingController(
      text: job.price != null ? job.price!.toStringAsFixed(2) : "",
    );
    _taxController = TextEditingController(text: "0.00");
    _totalController = TextEditingController(
      text: job.price != null ? job.price!.toStringAsFixed(2) : "",
    );
    _notesController = TextEditingController();

    // Calculate total when subtotal or tax changes
    _subtotalController.addListener(_calculateTotal);
    _taxController.addListener(_calculateTotal);
  }

  void _calculateTotal() {
    final subtotal = double.tryParse(_subtotalController.text) ?? 0.0;
    final tax = double.tryParse(_taxController.text) ?? 0.0;
    final total = subtotal + tax;
    _totalController.text = total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _customerEmailController.dispose();
    _jobTitleController.dispose();
    _subtotalController.dispose();
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
      final invoice = await repository.createInvoiceDraft(
        jobId: widget.job.id,
        subtotal: double.tryParse(_subtotalController.text),
        tax: double.tryParse(_taxController.text),
        total: double.tryParse(_totalController.text),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      // Update invoice with editable fields
      await repository.updateInvoice(
        invoiceId: invoice.id,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        customerEmail: _customerEmailController.text.trim().isEmpty
            ? null
            : _customerEmailController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
        jobDate: _jobDate,
        subtotal: double.tryParse(_subtotalController.text),
        tax: double.tryParse(_taxController.text),
        total: double.tryParse(_totalController.text),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fatura taslağı oluşturuldu")),
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
      appBar: const AdminAppBar(title: Text("Fatura Oluştur")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                      "İş Bilgileri",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _jobTitleController,
                      decoration: const InputDecoration(
                        labelText: "İş Başlığı *",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? "İş başlığı gerekli"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _jobDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _jobDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "İş Tarihi *",
                          border: OutlineInputBorder(),
                        ),
                        child: Text(DateFormat("dd MMM yyyy").format(_jobDate)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Personel Bilgisi
            if (widget.job.assignments.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, size: 20, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            "Personel Bilgisi",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...widget.job.assignments.map((assignment) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              assignment.personnelName,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            if (widget.job.assignments.isNotEmpty) const SizedBox(height: 16),
            // Kullanılan Malzemeler
            if (widget.job.materials != null && widget.job.materials!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2, size: 20, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            "Kullanılan Malzemeler",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...widget.job.materials!.map((material) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                material.inventoryItemName,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              "${material.quantity} adet",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "₺${(material.quantity * material.unitPrice).toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Toplam Malzeme",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "₺${widget.job.materials!.fold<double>(0, (sum, m) => sum + (m.quantity * m.unitPrice)).toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.job.materials != null && widget.job.materials!.isNotEmpty)
              const SizedBox(height: 16),
            // Ödeme Durumu
            Card(
              color: _getPaymentStatusColor(widget.job.paymentStatus).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getPaymentStatusIcon(widget.job.paymentStatus),
                          size: 20,
                          color: _getPaymentStatusColor(widget.job.paymentStatus),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Ödeme Durumu",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Durum:"),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getPaymentStatusColor(widget.job.paymentStatus),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getPaymentStatusText(widget.job.paymentStatus),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Toplam Tutar:"),
                        Text(
                          "₺${widget.job.price?.toStringAsFixed(2) ?? '0.00'}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Alınan Ücret:"),
                        Text(
                          "₺${widget.job.collectedAmount?.toStringAsFixed(2) ?? '0.00'}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    if ((widget.job.price ?? 0) - (widget.job.collectedAmount ?? 0) > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Kalan Borç:"),
                          Text(
                            "₺${((widget.job.price ?? 0) - (widget.job.collectedAmount ?? 0)).toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                      controller: _subtotalController,
                      decoration: const InputDecoration(
                        labelText: "Ara Toplam (₺) *",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Ara toplam gerekli";
                        }
                        final num = double.tryParse(value);
                        if (num == null || num < 0) {
                          return "Geçerli bir sayı girin";
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
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final num = double.tryParse(value);
                          if (num == null || num < 0) {
                            return "Geçerli bir sayı girin";
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _totalController,
                      decoration: const InputDecoration(
                        labelText: "Toplam (₺) *",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
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
                  : const Text("Fatura Taslağı Oluştur"),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPaymentStatusColor(String? status) {
    switch (status) {
      case "PAID":
        return Colors.green;
      case "PARTIAL":
        return Colors.orange;
      case "NOT_PAID":
      default:
        return Colors.red;
    }
  }

  IconData _getPaymentStatusIcon(String? status) {
    switch (status) {
      case "PAID":
        return Icons.check_circle;
      case "PARTIAL":
        return Icons.pending;
      case "NOT_PAID":
      default:
        return Icons.cancel;
    }
  }

  String _getPaymentStatusText(String? status) {
    switch (status) {
      case "PAID":
        return "Ödendi";
      case "PARTIAL":
        return "Kısmi Ödeme";
      case "NOT_PAID":
      default:
        return "Ödenmedi";
    }
  }
}
