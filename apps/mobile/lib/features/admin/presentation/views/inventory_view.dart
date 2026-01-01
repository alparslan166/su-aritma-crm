import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:mobile/widgets/admin_app_bar.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../../../core/error/error_handler.dart";
import "../../application/inventory_list_notifier.dart";
import "../../data/models/inventory_item.dart";
import "inventory_form_sheet.dart" show InventoryFormSheet;

class InventoryView extends ConsumerWidget {
  const InventoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryListProvider);
    final notifier = ref.read(inventoryListProvider.notifier);
    final content = state.when(
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.inventory_outlined,
                  title: "Stok listesi boş",
                  subtitle: "Depoya malzeme eklediğinizde burada göreceksiniz.",
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            cacheExtent: 500,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final item = items[index];
              return RepaintBoundary(
                child: _InventoryTile(
                  item: item,
                  onTap: () =>
                      context.push("/admin/inventory/${item.id}", extra: item),
                ),
              );
            },
          ),
        );
      },
      error: (error, _) => _InventoryError(
        message: ErrorHandler.getUserFriendlyMessage(error),
        onRetry: () => ref.read(inventoryListProvider.notifier).refresh(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
    final padding = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: const AdminAppBar(title: Text("Stok Durumu")),
      body: Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(
            right: 16,
            bottom: 16 + padding,
            child: FloatingActionButton.extended(
              onPressed: () => _openAddInventorySheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text("Ürün Ekle"),
            ),
          ),
        ],
      ),
    );
  }

  void _openAddInventorySheet(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const Dialog(
        insetPadding: EdgeInsets.all(16),
        child: InventoryFormSheet(),
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.item, required this.onTap});

  final InventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 6 adetten az kalanlar kırmızı, diğerleri yeşil
    final statusColor = item.stockQty < 6
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withValues(alpha: 0.15),
                      statusColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    item.stockQty.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          "${item.stockQty} ${item.unit ?? "adet"}",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${item.unitPrice.toStringAsFixed(2)} ₺",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryError extends StatelessWidget {
  const _InventoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 40),
          const SizedBox(height: 8),
          Text(
            "Stok listesi alınamadı",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: onRetry, child: const Text("Yenile")),
        ],
      ),
    );
  }
}
