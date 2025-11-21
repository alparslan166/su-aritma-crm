import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:latlong2/latlong.dart";
import "package:mobile/widgets/admin_app_bar.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../application/job_list_notifier.dart";
import "../../application/personnel_list_notifier.dart";
import "../../data/models/job.dart";
import "../../data/models/personnel.dart";

enum MapFilter { all, personnelOnly, jobsOnly }

class JobMapView extends ConsumerStatefulWidget {
  const JobMapView({
    super.key,
    this.initialPersonnelLocation,
  });

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
        (job) => _jobMarker(context, job, () => _openJobDetail(job)),
      ),
      ...visiblePersonnelPoints.map(
        (person) => _personnelMarker(
          context,
          person,
          () => _openPersonnelDetail(person),
        ),
      ),
    ];

    // Always show map with default center (Istanbul) if no data
    // Eğer initialPersonnelLocation varsa onu kullan
    final center = widget.initialPersonnelLocation ?? 
        _initialCenter(jobPoints, personnelPoints);

    return Scaffold(
      appBar: const AdminAppBar(title: "Harita"),
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
                          _mapController.move(widget.initialPersonnelLocation!, 15.0);
                        });
                      } else if (markers.isNotEmpty) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          final target = _initialCenter(jobPoints, personnelPoints);
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
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
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
                      final target = _initialCenter(jobPoints, personnelPoints);
                      final zoom = markers.isEmpty ? 10.0 : _mapController.camera.zoom;
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
                          trailing: Text(job.status),
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

Marker _jobMarker(BuildContext context, Job job, VoidCallback onTap) {
  final location = job.location!;
  return Marker(
    point: LatLng(location.latitude, location.longitude),
    width: 40,
    height: 40,
    child: GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: "${job.title}\n${location.address ?? ""}",
        child: Icon(
          Icons.place,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
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
    width: 36,
    height: 36,
    child: GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: "${person.name}\n${location.timestamp ?? ""}",
        child: Icon(
          Icons.person_pin_circle,
          size: 30,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    ),
  );
}
