import "package:flutter/material.dart";

import "../admin/presentation/views/import_contacts_sheet.dart";

class ImportDataPage extends StatelessWidget {
  const ImportDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("İçeri Aktar"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.contacts,
                color: Color(0xFF2563EB),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            const Text(
              "Rehberden Müşteri Aktar",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Description
            Text(
              "Telefonunuzun rehberindeki kişileri seçerek hızlıca müşteri olarak ekleyebilirsiniz.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            
            // Features list
            _buildFeatureItem(
              Icons.check_circle_outline,
              "Çoklu seçim yapabilirsiniz",
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              Icons.person_add_alt_1,
              "İsim ve telefon otomatik doldurulur",
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              Icons.edit_note,
              "Diğer bilgileri daha sonra düzenleyebilirsiniz",
            ),
            
            const Spacer(),
            
            // Import button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ImportContactsSheet(),
                    ),
                  );
                },
                icon: const Icon(Icons.contacts),
                label: const Text("Rehbere Git"),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF10B981), size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
