import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:open_file/open_file.dart";

import "../../../../core/error/error_handler.dart";
import "../../data/admin_repository.dart";
import "../../data/models/job.dart";

class JobCard extends ConsumerWidget {
  const JobCard({super.key, required this.job, this.onTap});

  final Job job;
  final VoidCallback? onTap;

  // Durum badge'i için tam renk (alpha olmadan)
  Color _statusTextColor() {
    switch (job.status) {
      case "PENDING":
        return const Color(0xFF2563EB); // Mavi
      case "IN_PROGRESS":
        return const Color(0xFFF59E0B); // Turuncu
      case "DELIVERED":
        return Colors.grey.shade700;
      case "ARCHIVED":
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduled = job.scheduledAt != null
        ? "${job.scheduledAt!.day.toString().padLeft(2, "0")}.${job.scheduledAt!.month.toString().padLeft(2, "0")}"
        : "Planlı değil";
    final address = job.location?.address;
    final isDelivered = job.status == "DELIVERED" || job.status == "ARCHIVED";
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2563EB).withValues(alpha: 0.1),
                          const Color(0xFF10B981).withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.work_outline,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusTextColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _statusTextColor().withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _getStatusText(job.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _statusTextColor(),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      job.customer.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          scheduled,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (address != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (job.maintenanceDueAt != null) ...[
                const SizedBox(height: 12),
                _MaintenanceInfo(dueDate: job.maintenanceDueAt!),
              ],
              if (job.materials != null && job.materials!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.inventory_2,
                            size: 16,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Kullanılan Malzemeler",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...job.materials!.map((material) {
                        final total = material.quantity * material.unitPrice;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "${material.inventoryItemName} (${material.quantity} adet)",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              Text(
                                "${total.toStringAsFixed(2)} ₺",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              if (job.price != null ||
                  job.collectedAmount != null ||
                  job.paymentStatus != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.payments,
                            size: 16,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Ödeme Bilgileri",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (job.price != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Ücret:",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              Text(
                                "${job.price!.toStringAsFixed(2)} ₺",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (job.collectedAmount != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Tahsil Edilen:",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              Text(
                                "${job.collectedAmount!.toStringAsFixed(2)} ₺",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (job.paymentStatus != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Ödeme Durumu:",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getPaymentStatusColor(
                                    job.paymentStatus!,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getPaymentStatusText(job.paymentStatus!),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (job.assignments.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: job.assignments
                      .map(
                        (assignment) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                assignment.personnelName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Henüz personel atanmamış",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              // Fatura Oluştur butonu - sadece DELIVERED veya ARCHIVED işler için
              if (isDelivered) ...[
                const SizedBox(height: 16),
                Center(
                  child: FilledButton.icon(
                    onPressed: () => _createInvoice(context, ref, job.id),
                    icon: const Icon(Icons.receipt, size: 18),
                    label: const Text("Fatura Oluştur"),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createInvoice(
    BuildContext context,
    WidgetRef ref,
    String jobId,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Generate PDF
      final repository = ref.read(adminRepositoryProvider);
      final pdfPath = await repository.generateInvoicePdf(jobId);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Open PDF
      await OpenFile.open(pdfPath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fatura oluşturuldu ve açıldı")),
        );
      }
    } catch (error) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        ErrorHandler.showError(context, error);
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case "PENDING":
        return "Beklemede";
      case "IN_PROGRESS":
        return "Devam Ediyor";
      case "DELIVERED":
        return "Teslim Edildi";
      case "ARCHIVED":
        return "Arşivlendi";
      default:
        return status;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toUpperCase()) {
      case "PAID":
        return const Color(0xFF10B981);
      case "PARTIAL":
        return const Color(0xFFF59E0B);
      case "NOT_PAID":
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  String _getPaymentStatusText(String status) {
    switch (status.toUpperCase()) {
      case "PAID":
        return "Ödendi";
      case "PARTIAL":
        return "Kısmi";
      case "NOT_PAID":
        return "Ödenmedi";
      default:
        return status;
    }
  }
}

class _MaintenanceInfo extends StatelessWidget {
  const _MaintenanceInfo({required this.dueDate});

  final DateTime dueDate;

  Color _getColor() {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    if (difference < 0) {
      return const Color(0xFFEF4444);
    } else if (difference <= 1) {
      return const Color(0xFFEF4444);
    } else if (difference <= 3) {
      return const Color(0xFFF59E0B);
    } else if (difference <= 7) {
      return const Color(0xFFF59E0B);
    } else {
      return const Color(0xFF2563EB);
    }
  }

  String _getText() {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    if (difference < 0) {
      return "Bakım kaçırıldı (${difference.abs()} gün önce)";
    } else if (difference == 0) {
      return "Bakım bugün";
    } else if (difference <= 1) {
      return "Bakım 1 gün sonra";
    } else if (difference <= 3) {
      return "Bakım $difference gün sonra";
    } else if (difference <= 7) {
      return "Bakım $difference gün sonra";
    } else {
      return "Bakım ${DateFormat("dd MMM yyyy").format(dueDate)}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.build_circle_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            _getText(),
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
