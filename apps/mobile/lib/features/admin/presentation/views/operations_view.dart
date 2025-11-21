import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:mobile/widgets/admin_app_bar.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../application/operation_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/operation.dart";

class OperationsView extends ConsumerWidget {
  const OperationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationListProvider);
    final notifier = ref.read(operationListProvider.notifier);
    final repository = ref.read(adminRepositoryProvider);

    final content = state.when(
      data: (operations) {
        if (operations.isEmpty) {
          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.build_outlined,
                  title: "Operasyon listesi boş",
                  subtitle: "Yeni operasyon eklediğinizde burada listelenecek.",
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemCount: operations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            cacheExtent: 500,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final operation = operations[index];
              return RepaintBoundary(
                child: _OperationTile(
                  operation: operation,
                  onEdit: () =>
                      _showEditDialog(context, ref, operation, repository),
                  onDelete: () =>
                      _showDeleteDialog(context, ref, operation, repository),
                ),
              );
            },
          ),
        );
      },
      error: (error, _) => _ErrorState(
        message: error.toString(),
        onRetry: () => notifier.refresh(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );

    final padding = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: const AdminAppBar(title: "Operasyonlar"),
      body: Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(
            right: 16,
            bottom: 16 + padding,
            child: FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, ref, repository),
              icon: const Icon(Icons.add),
              label: const Text("Operasyon Ekle"),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(
    BuildContext context,
    WidgetRef ref,
    AdminRepository repository,
  ) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Operasyon Ekle"),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "Operasyon Adı",
              hintText: "Örn: Su arıtma tankı değişimi",
            ),
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Operasyon adı girin";
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                await repository.createOperation(
                  name: nameController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ref.read(operationListProvider.notifier).refresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Operasyon eklendi")),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Hata: $error")));
                }
              }
            },
            child: const Text("Ekle"),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Operation operation,
    AdminRepository repository,
  ) {
    final nameController = TextEditingController(text: operation.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Operasyon Düzenle"),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: "Operasyon Adı"),
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Operasyon adı girin";
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                await repository.updateOperation(
                  id: operation.id,
                  name: nameController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ref.read(operationListProvider.notifier).refresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Operasyon güncellendi")),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Hata: $error")));
                }
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    Operation operation,
    AdminRepository repository,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Operasyonu Sil"),
        content: Text(
          "${operation.name} operasyonunu silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await repository.deleteOperation(operation.id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ref.read(operationListProvider.notifier).refresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("${operation.name} silindi")),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Silinemedi: $error")));
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({
    required this.operation,
    required this.onEdit,
    required this.onDelete,
  });

  final Operation operation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2563EB).withValues(alpha: 0.1),
                      const Color(0xFF10B981).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.build,
                  color: Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  operation.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF2563EB)),
                onPressed: onEdit,
                tooltip: "Düzenle",
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
                tooltip: "Sil",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              "Operasyon listesi alınamadı",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text("Tekrar Dene"),
            ),
          ],
        ),
      ),
    );
  }
}
