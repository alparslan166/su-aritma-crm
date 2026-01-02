import "dart:io";
import "dart:typed_data";

import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

import "../../../../core/utils/html_utils.dart" as html;
import "../../data/admin_repository.dart";

class ExportDataPage extends ConsumerStatefulWidget {
  const ExportDataPage({super.key});

  @override
  ConsumerState<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends ConsumerState<ExportDataPage> {
  bool _isExporting = false;

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);

    try {
      final repo = ref.read(adminRepositoryProvider);

      final bytes = await repo.downloadExcelExport().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception("İstek zaman aşımına uğradı. Lütfen tekrar deneyin.");
        },
      );

      final fileName = 'SuAritma_Export_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';

      if (kIsWeb) {
        // Web platform - blob download
        final blob = html.Blob(
          [bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Excel dosyası indiriliyor..."),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Mobile platform - save to documents and share
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        if (mounted) {
          // Share the file so user can save or open it
          await Share.shareXFiles(
            [XFile(filePath)],
            text: 'Su Arıtma CRM - Veri Dışarı Aktarma',
            subject: fileName,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Excel dosyası oluşturuldu!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Dışarı aktarma hatası: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Veri Dışarı Aktar"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_rounded,
                size: 64,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            const Text(
              "Tüm Verilerinizi İndirin",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Sistemdeki tüm verilerinizi Excel dosyası olarak indirin.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Data categories
            _buildDataCategory(
              icon: Icons.people,
              color: const Color(0xFF2563EB),
              title: "Müşteriler",
              description: "İsim, telefon, adres, konum, borç bilgileri",
            ),
            const SizedBox(height: 12),
            _buildDataCategory(
              icon: Icons.engineering,
              color: const Color(0xFF10B981),
              title: "Personeller",
              description: "Personel bilgileri, işe giriş tarihi, durum",
            ),
            const SizedBox(height: 12),
            _buildDataCategory(
              icon: Icons.work,
              color: const Color(0xFFF59E0B),
              title: "İşler",
              description: "Tüm işler, müşteri ve personel atamaları, fiyatlar",
            ),
            const SizedBox(height: 12),
            _buildDataCategory(
              icon: Icons.inventory_2,
              color: const Color(0xFF8B5CF6),
              title: "Stok",
              description: "Envanter durumu, ürün bilgileri, stok miktarları",
            ),
            const SizedBox(height: 12),
            _buildDataCategory(
              icon: Icons.receipt_long,
              color: const Color(0xFFEC4899),
              title: "Faturalar",
              description: "Tüm fatura kayıtları, tutarlar",
            ),
            const SizedBox(height: 12),
            _buildDataCategory(
              icon: Icons.business,
              color: const Color(0xFF6366F1),
              title: "Firma Bilgileri",
              description: "Şirket bilgileri, iletişim, vergi numarası",
            ),
            const SizedBox(height: 32),
            // Download button
            FilledButton.icon(
              onPressed: _isExporting ? null : _exportToExcel,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download),
              label: Text(
                _isExporting ? "İndiriliyor..." : "Excel Olarak İndir",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "İndirilen dosya 7 farklı sayfa içerir.\nHer kategori ayrı bir sayfada görüntülenir.",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCategory({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: color.withOpacity(0.5),
            size: 20,
          ),
        ],
      ),
    );
  }
}
