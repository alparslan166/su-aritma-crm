import "dart:async";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:intl/intl.dart";
import "package:mobile/widgets/admin_app_bar.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../../../core/constants/app_config.dart";
import "../../../../core/error/error_handler.dart";
import "../../../../core/network/api_client.dart" show apiClientProvider;
import "../../application/personnel_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/personnel.dart";

class PersonnelView extends HookConsumerWidget {
  const PersonnelView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(personnelListProvider.notifier);
    final searchController = useTextEditingController();
    final phoneSearchController = useTextEditingController();
    final searchQuery = useState<String>("");
    final phoneSearchQuery = useState<String>("");
    final showFilters = useState<bool>(false);
    final dateFrom = useState<DateTime?>(null);
    final dateTo = useState<DateTime?>(null);

    // Helper function to apply filters
    void applyFilters({
      String? search,
      String? phoneSearch,
      DateTime? createdAtFrom,
      DateTime? createdAtTo,
    }) {
      notifier.filter(
        search: search?.isEmpty ?? true ? null : search,
        phoneSearch: phoneSearch?.isEmpty ?? true ? null : phoneSearch,
        createdAtFrom: createdAtFrom,
        createdAtTo: createdAtTo,
      );
    }

    // Apply filter on initial load
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        applyFilters(
          search: searchQuery.value,
          phoneSearch: phoneSearchQuery.value,
          createdAtFrom: dateFrom.value,
          createdAtTo: dateTo.value,
        );
      });
      return null;
    }, []);

    final state = ref.watch(personnelListProvider);
    final padding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: const AdminAppBar(title: Text("Personeller")),
      body: Stack(
        children: [
          Column(
            children: [
              // Arama kutusu
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        autofocus: false,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: "Personel ara...",
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.value.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                    searchQuery.value = "";
                                    applyFilters(
                                      search: "",
                                      phoneSearch: phoneSearchQuery.value,
                                      createdAtFrom: dateFrom.value,
                                      createdAtTo: dateTo.value,
                                    );
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (value) {
                          searchQuery.value = value;
                          applyFilters(
                            search: value,
                            phoneSearch: phoneSearchQuery.value,
                            createdAtFrom: dateFrom.value,
                            createdAtTo: dateTo.value,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        showFilters.value
                            ? Icons.filter_alt
                            : Icons.filter_alt_outlined,
                      ),
                      onPressed: () {
                        showFilters.value = !showFilters.value;
                      },
                      tooltip: "Filtreler",
                    ),
                  ],
                ),
              ),
              // Filtreler bölümü
              if (showFilters.value)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Filtreler",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  phoneSearchController.clear();
                                  phoneSearchQuery.value = "";
                                  dateFrom.value = null;
                                  dateTo.value = null;
                                  applyFilters(
                                    search: searchQuery.value,
                                    phoneSearch: "",
                                    createdAtFrom: null,
                                    createdAtTo: null,
                                  );
                                },
                                child: const Text("Temizle"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Telefon numarası araması
                          TextField(
                            controller: phoneSearchController,
                            decoration: const InputDecoration(
                              labelText: "Telefon Numarası",
                              hintText: "Örn: 2324",
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                            onChanged: (value) {
                              phoneSearchQuery.value = value;
                              applyFilters(
                                search: searchQuery.value,
                                phoneSearch: value,
                                createdAtFrom: dateFrom.value,
                                createdAtTo: dateTo.value,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          // Tarih filtreleme
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          dateFrom.value ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      dateFrom.value = picked;
                                      applyFilters(
                                        search: searchQuery.value,
                                        phoneSearch: phoneSearchQuery.value,
                                        createdAtFrom: picked,
                                        createdAtTo: dateTo.value,
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                  ),
                                  label: Text(
                                    dateFrom.value != null
                                        ? DateFormat(
                                            "dd MMM yyyy",
                                          ).format(dateFrom.value!)
                                        : "Başlangıç Tarihi",
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          dateTo.value ?? DateTime.now(),
                                      firstDate:
                                          dateFrom.value ?? DateTime(2000),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      dateTo.value = picked;
                                      applyFilters(
                                        search: searchQuery.value,
                                        phoneSearch: phoneSearchQuery.value,
                                        createdAtFrom: dateFrom.value,
                                        createdAtTo: picked,
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                  ),
                                  label: Text(
                                    dateTo.value != null
                                        ? DateFormat(
                                            "dd MMM yyyy",
                                          ).format(dateTo.value!)
                                        : "Bitiş Tarihi",
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Liste içeriği
              Expanded(
                child: state.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: notifier.refresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            vertical: 48,
                            horizontal: 24,
                          ),
                          children: const [
                            SizedBox(height: 120),
                            EmptyState(
                              icon: Icons.group_outlined,
                              title: "Hiç personel bulunmuyor",
                              subtitle:
                                  "Yeni personel ekleyerek ekibinizi oluşturabilirsiniz.",
                            ),
                          ],
                        ),
                      );
                    }
                    return _buildPersonnelList(context, items, notifier);
                  },
                  error: (error, _) => _ErrorState(
                    message: ErrorHandler.getUserFriendlyMessage(error),
                    onRetry: () =>
                        ref.read(personnelListProvider.notifier).refresh(),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16 + padding,
            child: FloatingActionButton.extended(
              onPressed: () => _openAddPersonnelSheet(context, ref),
              icon: const Icon(Icons.person_add),
              label: const Text("Personel Ekle"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonnelList(
    BuildContext context,
    List<Personnel> items,
    PersonnelListNotifier notifier,
  ) {
    final scrollController = useScrollController();
    final scrollOffset = useState<double>(0.0);
    final previousScrollOffset = useRef<double>(0.0);
    final scrollVelocity = useState<double>(0.0);
    final lastUpdateTime = useRef<DateTime>(DateTime.now());
    final velocityDecayTimer = useRef<Timer?>(null);

    useEffect(() {
      void listener() {
        final now = DateTime.now();
        final timeDelta = now.difference(lastUpdateTime.value).inMilliseconds;
        final offsetDelta =
            scrollController.offset - previousScrollOffset.value;

        if (timeDelta > 0 && timeDelta < 100) {
          // Scroll hızını hesapla (pixels per second)
          final velocity = (offsetDelta / timeDelta) * 1000;
          scrollVelocity.value = velocity.abs();

          // Scroll durduğunda hızı yavaşça azalt
          velocityDecayTimer.value?.cancel();
          velocityDecayTimer.value = Timer(
            const Duration(milliseconds: 100),
            () {
              scrollVelocity.value = scrollVelocity.value * 0.7;
              if (scrollVelocity.value < 10) {
                scrollVelocity.value = 0;
              }
            },
          );
        }

        scrollOffset.value = scrollController.offset;
        previousScrollOffset.value = scrollController.offset;
        lastUpdateTime.value = now;
      }

      scrollController.addListener(listener);
      return () {
        scrollController.removeListener(listener);
        velocityDecayTimer.value?.cancel();
      };
    }, [scrollController]);

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        cacheExtent: 500,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (context, index) {
          final item = items[index];
          return RepaintBoundary(
            child: _AnimatedPersonnelTile(
              personnel: item,
              scrollOffset: scrollOffset.value,
              scrollVelocity: scrollVelocity.value,
              index: index,
            ),
          );
        },
      ),
    );
  }

  void _openAddPersonnelSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const _PersonnelFormSheet(),
      ),
    );
  }
}

class _AnimatedPersonnelTile extends StatelessWidget {
  const _AnimatedPersonnelTile({
    required this.personnel,
    required this.scrollOffset,
    required this.scrollVelocity,
    required this.index,
  });

  final Personnel personnel;
  final double scrollOffset;
  final double scrollVelocity;
  final int index;

  @override
  Widget build(BuildContext context) {
    // iOS bildirim animasyonu: scroll sırasında kartlar birbirine yaklaşır
    // Kart yüksekliği + separator = yaklaşık 180px
    final cardHeight = 180.0;
    final cardPosition = index * cardHeight;

    // Viewport içindeki kartlar için animasyon uygula
    final viewportHeight = MediaQuery.of(context).size.height;
    final cardTop = cardPosition - scrollOffset;
    final cardBottom = cardTop + cardHeight;
    final cardCenter = cardTop + cardHeight / 2;
    final viewportCenter = viewportHeight / 2;

    // Viewport dışındaki kartlar için animasyon uygulama
    if (cardBottom < -50 || cardTop > viewportHeight + 50) {
      return GestureDetector(
        onTap: () => context.pushNamed(
          "admin-personnel-detail",
          pathParameters: {"id": personnel.id},
          extra: personnel,
        ),
        child: _PersonnelTile(item: personnel),
      );
    }

    // Scroll hızına göre scale hesapla (birbirine yaklaşma efekti)
    // Maksimum scroll hızı: 2000 pixels/second
    final maxVelocity = 2000.0;
    final normalizedVelocity = (scrollVelocity / maxVelocity).clamp(0.0, 1.0);

    // Scroll hızına göre scale: hızlı scroll'da kartlar küçülür (birbirine yaklaşır)
    // Minimum scale: 0.98 (kartlar %2 küçülür)
    final scale = 1.0 - (normalizedVelocity * 0.02);

    // Viewport merkezine göre hafif bir offset hesapla
    final distanceFromCenter = (cardCenter - viewportCenter).abs();
    final maxDistance = viewportHeight / 2;
    final normalizedDistance = (distanceFromCenter / maxDistance).clamp(
      0.0,
      1.0,
    );

    // Merkeze yakın kartlar daha az, uzak kartlar daha fazla hareket eder
    final offset =
        (1.0 - normalizedDistance) *
        1.5 *
        (cardCenter < viewportCenter ? -1 : 1);

    return GestureDetector(
      onTap: () => context.pushNamed(
        "admin-personnel-detail",
        pathParameters: {"id": personnel.id},
        extra: personnel,
      ),
      child: Transform(
        transform: Matrix4.identity()
          ..translate(0.0, offset)
          ..scale(scale),
        alignment: Alignment.center,
        child: _PersonnelTile(item: personnel),
      ),
    );
  }
}

class _PersonnelTile extends StatelessWidget {
  const _PersonnelTile({required this.item});

  final Personnel item;

  String _getPersonnelStatusText(String status) {
    switch (status) {
      case "ACTIVE":
        return "Aktif";
      case "SUSPENDED":
        return "Askıda";
      case "INACTIVE":
        return "Pasif";
      default:
        return status;
    }
  }

  Color _statusColor() {
    // İzinli personeller mavi renkte
    if (item.isOnLeave) {
      return const Color(0xFF2563EB);
    }
    switch (item.status) {
      case "ACTIVE":
        return const Color(0xFF10B981);
      case "SUSPENDED":
        return const Color(0xFFF59E0B);
      case "INACTIVE":
        return Colors.grey.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PersonnelAvatar(
                  photoUrl: item.photoUrl,
                  name: item.name,
                  size: 48,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: item.isOnLeave
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF1F2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.isOnLeave) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.beach_access,
                              size: 16,
                              color: const Color(0xFF2563EB),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              item.phone,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _statusColor().withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _statusColor(),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.isOnLeave
                                ? "İZİNLİ"
                                : _getPersonnelStatusText(item.status),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _statusColor(),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (item.email != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.email, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.email!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: item.canShareLocation
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      item.canShareLocation
                          ? Icons.location_on
                          : Icons.location_off,
                      size: 16,
                      color: item.canShareLocation
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.canShareLocation
                          ? "Konum paylaşımı açık"
                          : "Konum kapalı",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.loginCode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonnelFormSheet extends ConsumerStatefulWidget {
  const _PersonnelFormSheet();

  @override
  ConsumerState<_PersonnelFormSheet> createState() =>
      _PersonnelFormSheetState();
}

class _PersonnelFormSheetState extends ConsumerState<_PersonnelFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _loginCodeController = TextEditingController();
  final _imagePicker = ImagePicker();
  DateTime _hireDate = DateTime.now();
  bool _canShareLocation = true;
  bool _submitting = false;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _loginCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _hireDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
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
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Galeri"),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      final image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _selectedImageBytes = bytes;
        });
      }
    }
  }

  Future<String?> _uploadImage(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final contentType =
          image.path.endsWith(".jpg") || image.path.endsWith(".jpeg")
          ? "image/jpeg"
          : "image/png";

      // Get presigned URL from backend
      final client = ref.read(apiClientProvider);
      final presignedResponse = await client.post(
        "/media/sign",
        data: {"contentType": contentType, "prefix": "personnel-photos"},
      );
      final uploadUrl = presignedResponse.data["data"]["uploadUrl"] as String;
      final photoKey = presignedResponse.data["data"]["key"] as String;

      // Upload to S3 using presigned URL
      // Create a new Dio instance without interceptors to avoid conflicts
      final uploadClient = Dio();
      try {
        await uploadClient.put(
          uploadUrl,
          data: bytes,
          options: Options(
            headers: {"Content-Type": contentType},
            contentType: contentType,
            validateStatus: (status) => status != null && status < 600,
          ),
        );
      } catch (uploadError) {
        // Close the upload client to free resources
        uploadClient.close();
        rethrow;
      }
      uploadClient.close();

      // Return the photo key
      return photoKey;
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(
          context,
          "Fotoğraf yüklenemedi. ${ErrorHandler.getUserFriendlyMessage(e)}",
        );
      }
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
    });
    try {
      String? photoUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        photoUrl = await _uploadImage(_selectedImage!);
      }

      await ref
          .read(adminRepositoryProvider)
          .createPersonnel(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            hireDate: _hireDate,
            canShareLocation: _canShareLocation,
            photoUrl: photoUrl,
            loginCode: _loginCodeController.text.trim().isEmpty
                ? null
                : _loginCodeController.text.trim(),
          );
      await ref.read(personnelListProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Yeni personel eklendi")));
    } catch (error) {
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
    final dateText = DateFormat("dd MMM yyyy").format(_hireDate);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Personel Ekle",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // Fotoğraf seçimi
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        if (_selectedImageBytes != null)
                          ClipOval(
                            child: Image.memory(
                              _selectedImageBytes!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.1),
                                  const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.1),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, size: 50),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF2563EB),
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                              onPressed: _pickImage,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedImageBytes != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                            _selectedImageBytes = null;
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text("Kaldır"),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key("personnel-name-field"),
                controller: _nameController,
                decoration: const InputDecoration(labelText: "İsim"),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().length < 2
                    ? "İsim girin"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key("personnel-phone-field"),
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Telefon"),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.trim().length < 6
                    ? "Telefon girin"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key("personnel-email-field"),
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "E-posta (opsiyonel)",
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key("personnel-logincode-field"),
                controller: _loginCodeController,
                decoration: const InputDecoration(
                  labelText: "Giriş Kodu (opsiyonel - boş bırakılırsa otomatik oluşturulur)",
                  helperText: "Personel girişi için kullanılacak kod",
                ),
                maxLength: 20,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text("İşe giriş tarihi: $dateText")),
                  TextButton(
                    onPressed: _pickDate,
                    child: const Text("Tarih seç"),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _canShareLocation,
                title: const Text("Konum paylaşımı"),
                onChanged: (value) {
                  setState(() {
                    _canShareLocation = value;
                  });
                },
              ),
              const SizedBox(height: 12),
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
                      : const Text("Kaydet"),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonnelAvatar extends StatelessWidget {
  const _PersonnelAvatar({
    required this.photoUrl,
    required this.name,
    this.size = 48,
  });

  final String? photoUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Eğer photoUrl varsa ve boş değilse, fotoğrafı göster
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      // Default fotoğraflar için asset kullan
      if (photoUrl!.startsWith("default/")) {
        final gender = photoUrl!
            .replaceAll("default/", "")
            .replaceAll(".jpg", "");
        return ClipOval(
          child: Image.asset(
            "assets/images/$gender.jpg",
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildInitialsAvatar();
            },
          ),
        );
      }
      // S3 URL için network image kullan
      final imageUrl = AppConfig.getMediaUrl(photoUrl!);
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Hata durumunda baş harf göster
            return _buildInitialsAvatar();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildInitialsAvatar();
          },
        ),
      );
    }
    // Fotoğraf yoksa baş harf göster
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2563EB).withValues(alpha: 0.1),
            const Color(0xFF10B981).withValues(alpha: 0.1),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "P",
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2563EB),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Personel listesi alınamadı",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text("Tekrar dene"),
          ),
        ],
      ),
    );
  }
}
