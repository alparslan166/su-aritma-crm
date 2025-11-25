import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:latlong2/latlong.dart";
import "package:mobile/core/constants/app_config.dart";
import "package:mobile/widgets/admin_app_bar.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../application/job_list_notifier.dart";
import "../../application/personnel_list_notifier.dart";
import "../../data/models/job.dart";
import "../../data/models/personnel.dart";

enum MapFilter { all, personnelOnly, jobsOnly }

class JobMapView extends ConsumerStatefulWidget {
  const JobMapView({super.key, this.initialPersonnelLocation});

  final LatLng? initialPersonnelLocation;

  @override
  ConsumerState<JobMapView> createState() => _JobMapViewState();
}

class _JobMapViewState extends ConsumerState<JobMapView> {
  MapFilter _filter = MapFilter.all;
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(jobListProvider);
    final personnelState = ref.watch(personnelListProvider);

    // Always show map, even if loading or error
    final jobs = jobState.value ?? [];
    final personnel = personnelState.value ?? [];
    final jobPoints = jobs.where((job) => job.location != null).toList();
    final personnelPoints = personnel
        .where((p) => p.canShareLocation && p.lastKnownLocation != null)
        .toList();

    final showJobs = _filter != MapFilter.personnelOnly;
    final showPersonnel = _filter != MapFilter.jobsOnly;

    final visibleJobPoints = showJobs ? jobPoints : <Job>[];
    final visiblePersonnelPoints = showPersonnel
        ? personnelPoints
        : <Personnel>[];

    final markers = <Marker>[
      ...visibleJobPoints.map(
        (job) =>
            _jobMarker(context, job, () => _showJobInfoSheet(context, job)),
      ),
      ...visiblePersonnelPoints.map(
        (person) => _personnelMarker(
          context,
          person,
          () => _showPersonnelInfoSheet(context, person),
        ),
      ),
    ];

    // Always show map with default center (Istanbul) if no data
    // Eğer initialPersonnelLocation varsa onu kullan
    final center =
        widget.initialPersonnelLocation ??
        _initialCenter(jobPoints, personnelPoints);

    return Scaffold(
      appBar: const AdminAppBar(title: Text("Harita")),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(jobListProvider.notifier).refresh(),
            ref.read(personnelListProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Stack(
                children: [
                  // Always show map
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: markers.isEmpty ? 10.0 : 11.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onMapReady: () {
                        // Center map on data when ready
                        if (widget.initialPersonnelLocation != null) {
                          Future.delayed(const Duration(milliseconds: 300), () {
                            _mapController.move(
                              widget.initialPersonnelLocation!,
                              15.0,
                            );
                          });
                        } else if (markers.isNotEmpty) {
                          Future.delayed(const Duration(milliseconds: 300), () {
                            final target = _initialCenter(
                              jobPoints,
                              personnelPoints,
                            );
                            _mapController.move(target, 11.0);
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: "com.suaritma.app",
                        maxZoom: 19,
                        minZoom: 3,
                      ),
                      if (markers.isNotEmpty) MarkerLayer(markers: markers),
                    ],
                  ),
                  // Loading indicator overlay
                  if (jobState.isLoading || personnelState.isLoading)
                    Container(
                      color: Colors.white.withValues(alpha: 0.7),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  // Error messages overlay
                  if (jobState.hasError || personnelState.hasError)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                jobState.hasError
                                    ? "İş konumları alınamadı"
                                    : "Personel konumları alınamadı",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Center button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: FloatingActionButton.small(
                      heroTag: "map-center-btn",
                      onPressed: () {
                        final target = _initialCenter(
                          jobPoints,
                          personnelPoints,
                        );
                        final zoom = markers.isEmpty
                            ? 10.0
                            : _mapController.camera.zoom;
                        _mapController.move(target, zoom);
                      },
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text("Sadece personeller"),
                    selected: _filter == MapFilter.personnelOnly,
                    onSelected: (_) {
                      setState(() {
                        _filter = _filter == MapFilter.personnelOnly
                            ? MapFilter.all
                            : MapFilter.personnelOnly;
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text("Sadece işler"),
                    selected: _filter == MapFilter.jobsOnly,
                    onSelected: (_) {
                      setState(() {
                        _filter = _filter == MapFilter.jobsOnly
                            ? MapFilter.all
                            : MapFilter.jobsOnly;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (visibleJobPoints.isEmpty && visiblePersonnelPoints.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: EmptyState(
                  icon: Icons.map_outlined,
                  title: "Henüz konum verisi yok",
                  subtitle:
                      "İş veya personel konumları geldiğinde harita güncellenecek.",
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showJobs) ...[
                      Text(
                        "İş Konumları",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (visibleJobPoints.isEmpty)
                        const Text("Görüntülenecek iş konumu yok.")
                      else
                        ...visibleJobPoints.map(
                          (job) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.location_on),
                            title: Text(job.title),
                            subtitle: Text(job.location?.address ?? "-"),
                            trailing: Text(_getJobStatusText(job.status)),
                            onTap: () => _openJobDetail(job),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                    if (showPersonnel) ...[
                      Text(
                        "Personel Konumları",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (visiblePersonnelPoints.isEmpty)
                        const Text("Görüntülenecek personel konumu yok.")
                      else
                        ...visiblePersonnelPoints.map((person) {
                          final ts = person.lastKnownLocation?.timestamp;
                          final subtitle = ts == null
                              ? "Son konum zamanı bilinmiyor"
                              : "Son konum: ${ts.toLocal()}";
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_pin_circle),
                            title: Text(person.name),
                            subtitle: Text(subtitle),
                            onTap: () => _openPersonnelDetail(person),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openJobDetail(Job job) {
    context.pushNamed(
      "admin-job-detail",
      pathParameters: {"id": job.id},
      extra: job,
    );
  }

  void _openPersonnelDetail(Personnel personnel) {
    context.pushNamed(
      "admin-personnel-detail",
      pathParameters: {"id": personnel.id},
      extra: personnel,
    );
  }

  void _showJobInfoSheet(BuildContext context, Job job) {
    final location = job.location!;
    final isActiveJob = job.status == "PENDING" || job.status == "IN_PROGRESS";
    final markerColor = isActiveJob
        ? Colors.red
        : Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place, size: 20, color: markerColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    job.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (location.address != null && location.address!.isNotEmpty) ...[
              Text(
                location.address!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: markerColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: markerColor),
                  ),
                  child: Text(
                    _getJobStatusText(job.status),
                    style: TextStyle(
                      color: markerColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openJobDetail(job);
                  },
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  label: const Text(
                    "Detay",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: markerColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonnelInfoSheet(BuildContext context, Personnel person) {
    final location = person.lastKnownLocation!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PersonnelAvatar(
                  photoUrl: person.photoUrl,
                  name: person.name,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    person.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (location.timestamp != null) ...[
              Text(
                "Son konum: ${DateFormat("dd MMM yyyy HH:mm").format(location.timestamp!.toLocal())}",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openPersonnelDetail(person);
                  },
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  label: const Text(
                    "Detay",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

LatLng _initialCenter(List<Job> jobs, List<Personnel> personnel) {
  // If we have jobs with locations, use first job
  if (jobs.isNotEmpty && jobs.first.location != null) {
    return LatLng(
      jobs.first.location!.latitude,
      jobs.first.location!.longitude,
    );
  }
  // If we have personnel with locations, use first personnel
  if (personnel.isNotEmpty && personnel.first.lastKnownLocation != null) {
    final loc = personnel.first.lastKnownLocation!;
    return LatLng(loc.lat, loc.lng);
  }
  // Default: Istanbul center - always show map even with no data
  return const LatLng(41.015137, 28.97953);
}

String _getJobStatusText(String status) {
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

Marker _jobMarker(BuildContext context, Job job, VoidCallback onTap) {
  final location = job.location!;
  // Mevcut işler (PENDING, IN_PROGRESS) kırmızı, geçmiş işler (DELIVERED, ARCHIVED) primary color
  final isActiveJob = job.status == "PENDING" || job.status == "IN_PROGRESS";
  final markerColor = isActiveJob
      ? Colors.red
      : Theme.of(context).colorScheme.primary;

  return Marker(
    point: LatLng(location.latitude, location.longitude),
    width: 40,
    height: 40,
    child: GestureDetector(
      onTap: onTap,
      child: Icon(Icons.place, size: 32, color: markerColor),
    ),
  );
}

Marker _personnelMarker(
  BuildContext context,
  Personnel person,
  VoidCallback onTap,
) {
  final location = person.lastKnownLocation!;
  return Marker(
    point: LatLng(location.lat, location.lng),
    width: 40,
    height: 40,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _PersonnelAvatar(
          photoUrl: person.photoUrl,
          name: person.name,
          size: 36,
        ),
      ),
    ),
  );
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
