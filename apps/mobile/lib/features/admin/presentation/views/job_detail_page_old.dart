import "package:flutter/material.dart";

import "../../data/models/job.dart";

class AdminJobDetailPage extends StatelessWidget {
  const AdminJobDetailPage({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(job.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: "Genel Bilgi",
            children: [
              _Row("Durum", job.status),
              _Row(
                "Planlanan Tarih",
                job.scheduledAt?.toLocal().toString() ?? "-",
              ),
              _Row("Öncelik", job.priority?.toString() ?? "-"),
              _Row("Adres", job.location?.address ?? job.customer.address),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: "Müşteri",
            children: [
              _Row("İsim", job.customer.name),
              _Row("Telefon", job.customer.phone),
              _Row("Adres", job.customer.address),
            ],
          ),
          const SizedBox(height: 16),
          if (job.assignments.isNotEmpty)
            _Section(
              title: "Atanan Personeller",
              children: job.assignments
                  .map((p) => _Row("Personel", p.personnelName))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
