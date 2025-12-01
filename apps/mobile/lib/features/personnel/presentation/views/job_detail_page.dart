import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:geocoding/geocoding.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:latlong2/latlong.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../admin/application/inventory_list_notifier.dart";
import "../../../admin/data/models/inventory_item.dart";
import "../../../../core/network/api_client.dart" show apiClientProvider;
import "../../application/delivery_payload.dart";
import "../../application/job_detail_notifier.dart";
import "../../application/personnel_jobs_notifier.dart";
import "../../data/personnel_repository.dart";
import "../../data/models/personnel_job.dart";
import "../widgets/job_status_chip.dart";

class PersonnelJobDetailPage extends HookConsumerWidget {
  const PersonnelJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personnelJobDetailProvider(jobId));
    return Scaffold(
      appBar: AppBar(title: const Text("İş Detayı")),
      body: state.when(
        data: (detail) => RefreshIndicator(
          onRefresh: () =>
              ref.read(personnelJobDetailProvider(jobId).notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Harita bölümü - en üstte
              _JobMapSection(customer: detail.job.customer),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      detail.job.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  JobStatusChip(status: detail.job.status),
                ],
              ),
              const SizedBox(height: 16),
              _InfoTile(title: "Müşteri", value: detail.job.customer.name),
              _InfoTile(title: "Telefon", value: detail.job.customer.phone),
              _InfoTile(title: "Adres", value: detail.job.customer.address),
              const SizedBox(height: 16),
              _InfoTile(
                title: "Planlanan Tarih",
                value:
                    detail.job.scheduledAt?.toLocal().toString() ??
                    "Belirlenmedi",
              ),
              // Malzemeler bölümü
              if (detail.job.materials != null &&
                  detail.job.materials!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _MaterialsSection(materials: detail.job.materials!),
              ],
              const SizedBox(height: 24),
              _ActionButtons(
                jobId: jobId,
                status: detail.job.status,
                readOnly: detail.job.readOnly,
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ActionButtons extends HookConsumerWidget {
  const _ActionButtons({
    required this.jobId,
    required this.status,
    required this.readOnly,
  });

  final String jobId;
  final String status;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(personnelRepositoryProvider);
    final sending = useState(false);

    Future<void> handleStart() async {
      try {
        sending.value = true;
        await repository.startJob(jobId);
        await ref.read(personnelJobDetailProvider(jobId).notifier).refresh();
        ref.invalidate(personnelJobsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("İşe başlama bildirildi")),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      } finally {
        sending.value = false;
      }
    }

    Future<void> handleDeliver() async {
      if (readOnly) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bu iş artık düzenlenemez")),
        );
        return;
      }
      final result = await showModalBottomSheet<DeliveryPayload>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _DeliverySheet(),
      );
      if (result == null) return;
      try {
        sending.value = true;
        await repository.deliverJob(jobId, result);
        await ref.read(personnelJobDetailProvider(jobId).notifier).refresh();
        ref.invalidate(personnelJobsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("İş teslim edildi")));
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      } finally {
        sending.value = false;
      }
    }

    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: status == "PENDING" && !sending.value ? handleStart : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text("İşe Başla"),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: status != "DELIVERED" && !sending.value
              ? handleDeliver
              : null,
          icon: const Icon(Icons.task_alt),
          label: Text(readOnly ? "Teslim - Sadece Görüntüle" : "İşi Teslim Et"),
        ),
      ],
    );
  }
}

class _DeliverySheet extends HookConsumerWidget {
  const _DeliverySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountController = useTextEditingController();
    final noteController = useTextEditingController();
    final interval = useState<int?>(null);
    final selectedPhotos = useState<List<XFile>>([]);
    final selectedMaterials = useState<Map<String, int>>({});
    final imagePicker = ImagePicker();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Teslim Bilgileri",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Alınan Ücret (₺)"),
          ),
          const SizedBox(height: 12),
          DropdownMenu<int>(
            initialSelection: interval.value,
            label: const Text("Bakım süresi"),
            dropdownMenuEntries: List.generate(
              12,
              (index) => DropdownMenuEntry(
                value: index + 1,
                label: "${index + 1} ay sonrası bakım",
              ),
            ),
            onSelected: (value) => interval.value = value,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: "Not"),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final source = await showDialog<ImageSource>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Fotoğraf Kaynağı"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text("Kamera"),
                              onTap: () =>
                                  Navigator.of(context).pop(ImageSource.camera),
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text("Galeri"),
                              onTap: () => Navigator.of(
                                context,
                              ).pop(ImageSource.gallery),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (source != null) {
                      final image = await imagePicker.pickImage(source: source);
                      if (image != null) {
                        selectedPhotos.value = [...selectedPhotos.value, image];
                      }
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text("Fotoğraf Ekle"),
                ),
              ),
            ],
          ),
          if (selectedPhotos.value.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: selectedPhotos.value.length,
                itemBuilder: (context, index) {
                  final photo = selectedPhotos.value[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(File(photo.path)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(24, 24),
                            ),
                            onPressed: () {
                              selectedPhotos.value = selectedPhotos.value
                                  .where((p) => p.path != photo.path)
                                  .toList();
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                _showMaterialSelectionSheet(context, ref, selectedMaterials),
            icon: const Icon(Icons.inventory_2),
            label: Text(
              selectedMaterials.value.isEmpty
                  ? "Malzeme Seç (Opsiyonel)"
                  : "${selectedMaterials.value.length} malzeme seçildi",
            ),
          ),
          if (selectedMaterials.value.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...selectedMaterials.value.entries.map((entry) {
              final inventoryState = ref.watch(inventoryListProvider);
              final item = inventoryState.value?.firstWhere(
                (item) => item.id == entry.key,
                orElse: () => InventoryItem(
                  id: entry.key,
                  name: "Bilinmiyor",
                  category: "",
                  stockQty: 0,
                  criticalThreshold: 0,
                  unitPrice: 0,
                  isActive: true,
                ),
              );
              return ListTile(
                title: Text(item?.name ?? "Bilinmiyor"),
                subtitle: Text("Adet: ${entry.value}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        final current = selectedMaterials.value[entry.key] ?? 0;
                        if (current > 1) {
                          selectedMaterials.value = {
                            ...selectedMaterials.value,
                            entry.key: current - 1,
                          };
                        } else {
                          final newMap = Map<String, int>.from(
                            selectedMaterials.value,
                          );
                          newMap.remove(entry.key);
                          selectedMaterials.value = newMap;
                        }
                      },
                    ),
                    Text("${entry.value}"),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final current = selectedMaterials.value[entry.key] ?? 0;
                        if (item != null && current < item.stockQty) {
                          selectedMaterials.value = {
                            ...selectedMaterials.value,
                            entry.key: current + 1,
                          };
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Upload photos to S3
                    final photoUrls = <String>[];
                    if (selectedPhotos.value.isNotEmpty) {
                      try {
                        for (final photo in selectedPhotos.value) {
                          final file = File(photo.path);
                          final bytes = await file.readAsBytes();
                          final contentType =
                              photo.path.endsWith(".jpg") ||
                                  photo.path.endsWith(".jpeg")
                              ? "image/jpeg"
                              : "image/png";

                          // Get presigned URL from backend
                          final client = ref.read(apiClientProvider);
                          final presignedResponse = await client.post(
                            "/media/sign",
                            data: {
                              "contentType": contentType,
                              "prefix": "job-deliveries",
                            },
                          );
                          final uploadUrl =
                              presignedResponse.data["data"]["uploadUrl"]
                                  as String;

                          // Upload to S3 using presigned URL
                          final uploadClient = Dio();
                          await uploadClient.put(
                            uploadUrl,
                            data: Stream.fromIterable([bytes]),
                            options: Options(
                              headers: {"Content-Type": contentType},
                              contentType: contentType,
                            ),
                          );

                          // Use presigned URL as the photo URL (it's valid for 5 minutes, enough for upload)
                          // In production, you'd want to get the public URL after upload
                          photoUrls.add(uploadUrl);
                        }
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Fotoğraf yükleme hatası: $error"),
                          ),
                        );
                        return;
                      }
                    }

                    final payload = DeliveryPayload(
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                      collectedAmount: amountController.text.trim().isEmpty
                          ? null
                          : double.tryParse(amountController.text.trim()),
                      maintenanceIntervalMonths: interval.value,
                      photoUrls: photoUrls,
                      usedMaterials: selectedMaterials.value.entries
                          .map(
                            (e) => DeliveryMaterial(
                              inventoryItemId: e.key,
                              quantity: e.value,
                            ),
                          )
                          .toList(),
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pop(payload);
                  },
                  child: const Text("Gönder"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showMaterialSelectionSheet(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<Map<String, int>> selectedMaterials,
  ) async {
    final inventoryState = ref.watch(inventoryListProvider);
    final inventory = inventoryState.value ?? [];
    if (inventory.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Malzeme bulunamadı")));
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      "Malzeme Seç",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: inventory.length,
                      itemBuilder: (context, index) {
                        final item = inventory[index];
                        final isSelected = selectedMaterials.value.containsKey(
                          item.id,
                        );
                        final quantity = selectedMaterials.value[item.id] ?? 0;
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            "Stok: ${item.stockQty} ${item.unit ?? "adet"}",
                          ),
                          trailing: isSelected
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () {
                                        setModalState(() {
                                          if (quantity > 1) {
                                            selectedMaterials.value = {
                                              ...selectedMaterials.value,
                                              item.id: quantity - 1,
                                            };
                                          } else {
                                            final newMap =
                                                Map<String, int>.from(
                                                  selectedMaterials.value,
                                                );
                                            newMap.remove(item.id);
                                            selectedMaterials.value = newMap;
                                          }
                                        });
                                      },
                                    ),
                                    Text("$quantity"),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        setModalState(() {
                                          if (quantity < item.stockQty) {
                                            selectedMaterials.value = {
                                              ...selectedMaterials.value,
                                              item.id: quantity + 1,
                                            };
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                )
                              : IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    setModalState(() {
                                      selectedMaterials.value = {
                                        ...selectedMaterials.value,
                                        item.id: 1,
                                      };
                                    });
                                  },
                                ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Tamam"),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _JobMapSection extends StatefulWidget {
  const _JobMapSection({required this.customer});

  final PersonnelJobCustomer customer;

  @override
  State<_JobMapSection> createState() => _JobMapSectionState();
}

class _JobMapSectionState extends State<_JobMapSection> {
  LatLng? _customerLocation;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    // Önce müşterinin location bilgisini kontrol et
    if (widget.customer.location != null) {
      final location = widget.customer.location!;
      final lat = location["latitude"] as num?;
      final lng = location["longitude"] as num?;
      if (lat != null && lng != null) {
        setState(() {
          _customerLocation = LatLng(lat.toDouble(), lng.toDouble());
        });
        return;
      }
    }

    // Location yoksa adresten geocoding yap
    if (widget.customer.address.isEmpty) {
      setState(() {
        _error = "Adres bilgisi bulunamadı";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final locations = await locationFromAddress(widget.customer.address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          _customerLocation = LatLng(location.latitude, location.longitude);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Adres için konum bulunamadı";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Konum yüklenemedi: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.map, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  "Müşteri Konumu",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_error != null || _isLoading)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _loadLocation,
                    tooltip: "Yeniden Yükle",
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 250,
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _loadLocation,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Tekrar Dene"),
                          ),
                        ],
                      ),
                    ),
                  )
                : _customerLocation != null
                ? FlutterMap(
                    options: MapOptions(
                      initialCenter: _customerLocation!,
                      initialZoom: 15.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: "com.suaritma.app",
                        maxZoom: 19,
                        minZoom: 3,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _customerLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFF2563EB),
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const Center(child: Text("Konum bilgisi bulunamadı")),
          ),
          if (_customerLocation != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Google Maps'te adresi aç
                      final encodedAddress = Uri.encodeComponent(
                        widget.customer.address,
                      );
                      final googleMapsUrl =
                          "https://www.google.com/maps/search/?api=1&query=$encodedAddress";
                      final uri = Uri.parse(googleMapsUrl);
                      // ignore: unawaited_futures
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.place, size: 18),
                    label: const Text("Google Maps ile Aç"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MaterialsSection extends StatelessWidget {
  const _MaterialsSection({required this.materials});

  final List<PersonnelJobMaterial> materials;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  "Kullanılacak Malzemeler",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...materials.map(
              (material) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory,
                      size: 20,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        material.inventoryItem.name,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Adet: ${material.quantity}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
