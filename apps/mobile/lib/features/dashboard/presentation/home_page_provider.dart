import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../admin/application/inventory_list_notifier.dart";
import "../../admin/data/admin_repository.dart";
import "../../admin/data/models/customer.dart";
import "../../admin/data/models/inventory_item.dart";
import "../../admin/data/models/job.dart";
import "../../admin/data/models/maintenance_reminder.dart";
import "../../admin/data/models/personnel.dart";
import "../../admin/presentation/views/admin_profile_page.dart";

class DashboardStats {
  DashboardStats({
    required this.totalCustomers,
    required this.activeJobs,
    required this.totalPersonnel,
    required this.lowStockItems,
    required this.overduePayments,
    required this.upcomingMaintenance,
  });

  final int totalCustomers;
  final int activeJobs;
  final int totalPersonnel;
  final int lowStockItems;
  final int overduePayments;
  final int upcomingMaintenance;
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final repository = ref.watch(adminRepositoryProvider);

  // Stok listesi değiştiğinde otomatik güncellenmesi için dinle
  ref.watch(inventoryListProvider);

  // Admin profilini al (customerCount için)
  final profile = await ref.watch(adminProfileProvider.future);
  final customerCount = (profile["customerCount"] as int?) ?? 0;

  // Tüm verileri paralel olarak çek (customers hariç - artık count'u profile'dan alıyoruz)
  final results = await Future.wait([
    repository.fetchCustomers(hasOverduePayment: true), // Sadece ödemesi gelenler
    repository.fetchJobs(),
    repository.fetchPersonnel(),
    repository.fetchInventory(),
    repository.fetchMaintenanceReminders(),
  ]);

  final overdueCustomers = results[0] as List<Customer>;
  final jobs = results[1] as List<Job>;
  final personnel = results[2] as List<Personnel>;
  final inventory = results[3] as List<InventoryItem>;
  final maintenanceReminders = results[4] as List<MaintenanceReminder>;

  // İstatistikleri hesapla
  final totalCustomers = customerCount;
  final activeJobs = jobs
      .where((job) => job.status == "PENDING" || job.status == "IN_PROGRESS")
      .length;
  final totalPersonnel = personnel.length;
  // 6 adetten az kalan stokları say (stok durumu sayfasındaki mantıkla aynı)
  final lowStockItems = inventory.where((item) => item.stockQty < 6).length;

  // Ödemesi gelen müşteriler (zaten hasOverduePayment=true ile çekildi)
  final overduePayments = overdueCustomers.length;

  // Yaklaşan bakım (7 gün içinde)
  final now = DateTime.now();
  final sevenDaysLater = now.add(const Duration(days: 7));
  final upcomingMaintenance = maintenanceReminders.where((reminder) {
    return reminder.dueAt.isAfter(now) &&
        reminder.dueAt.isBefore(sevenDaysLater);
  }).length;

  return DashboardStats(
    totalCustomers: totalCustomers,
    activeJobs: activeJobs,
    totalPersonnel: totalPersonnel,
    lowStockItems: lowStockItems,
    overduePayments: overduePayments,
    upcomingMaintenance: upcomingMaintenance,
  );
});

// Ödemesi gelen müşteriler
final overduePaymentsCustomersProvider = FutureProvider<List<Customer>>((
  ref,
) async {
  final repository = ref.watch(adminRepositoryProvider);
  final customers = await repository.fetchCustomers();

  // Remove duplicates by ID and name+phone combination
  final seenIds = <String>{};
  final seenNamePhone = <String>{};
  final uniqueCustomers = customers.where((c) {
    if (seenIds.contains(c.id)) return false;
    final namePhoneKey =
        '${c.name.toLowerCase().trim()}_${c.phone.replaceAll(RegExp(r'\s+'), '')}';
    if (seenNamePhone.contains(namePhoneKey)) return false;
    seenIds.add(c.id);
    seenNamePhone.add(namePhoneKey);
    return true;
  }).toList();

  return uniqueCustomers
      .where((customer) => customer.hasOverduePayment == true)
      .toList();
});

// Yaklaşan bakım hatırlatmaları
final upcomingMaintenanceProvider = FutureProvider<List<MaintenanceReminder>>((
  ref,
) async {
  final repository = ref.watch(adminRepositoryProvider);
  final reminders = await repository.fetchMaintenanceReminders();
  final now = DateTime.now();
  final sevenDaysLater = now.add(const Duration(days: 7));
  return reminders.where((reminder) {
    return reminder.dueAt.isAfter(now) &&
        reminder.dueAt.isBefore(sevenDaysLater);
  }).toList();
});

// Donut chart için müşteri kategorileri
class CustomerCategoryData {
  CustomerCategoryData({
    required this.overduePayments,
    required this.upcomingMaintenance,
    required this.maintenanceApproaching,
    required this.completedLastWeek,
    required this.activeCustomers,
    required this.inactiveCustomers,
  });

  final int overduePayments; // Ödemesi Gelenler
  final int upcomingMaintenance; // Bakımı Gelenler (30 gün içinde)
  final int maintenanceApproaching; // Bakımı Yaklaşanlar (7 gün içinde)
  final int completedLastWeek; // Son 1 Haftada Tamamlanan İşler
  final int activeCustomers; // Aktif Müşteriler
  final int inactiveCustomers; // Pasif Müşteriler
}

final customerCategoryDataProvider = FutureProvider<CustomerCategoryData>((
  ref,
) async {
  int overduePayments = 0;
  int upcomingMaintenance = 0;
  int maintenanceApproaching = 0;
  int completedLastWeek = 0;
  int activeCustomers = 0;
  int inactiveCustomers = 0;

  try {
    final repository = ref.watch(adminRepositoryProvider);
    final customers = await repository.fetchCustomers();
    final jobs = await repository.fetchJobs();

    // Remove duplicates by ID and name+phone combination
    final seenIds = <String>{};
    final seenNamePhone = <String>{};
    final uniqueCustomers = customers.where((c) {
      if (seenIds.contains(c.id)) return false;
      final namePhoneKey =
          '${c.name.toLowerCase().trim()}_${c.phone.replaceAll(RegExp(r'\s+'), '')}';
      if (seenNamePhone.contains(namePhoneKey)) return false;
      seenIds.add(c.id);
      seenNamePhone.add(namePhoneKey);
      return true;
    }).toList();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekAgoStart = todayStart.subtract(const Duration(days: 7));

    // Ödemesi gelen müşteriler, aktif ve pasif müşteriler
    for (final customer in uniqueCustomers) {
      try {
        if (customer.hasOverduePayment) {
          overduePayments++;
        }
        // Aktif müşteriler (status == "ACTIVE")
        if (customer.status == "ACTIVE") {
          activeCustomers++;
        }
        // Pasif müşteriler (status == "INACTIVE")
        if (customer.status == "INACTIVE") {
          inactiveCustomers++;
        }
      } catch (e) {
        // Müşteri verisi hatası, atla
        continue;
      }
    }

    // Bakımı gelen müşteriler (30 gün içinde - hasUpcomingMaintenance kullan)
    final Set<String> upcomingMaintenanceCustomerIds = {};
    final Set<String> maintenanceApproachingCustomerIds = {};

    for (final customer in uniqueCustomers) {
      try {
        if (customer.hasUpcomingMaintenance) {
          // Bakımı gelen sayfasında gösterilen müşteriler (30 gün içinde)
          upcomingMaintenanceCustomerIds.add(customer.id);
        }

        // Bakımı yaklaşanlar (7 gün içinde)
        if (customer.jobs != null) {
          for (final job in customer.jobs!) {
            if (job.maintenanceDueAt != null) {
              final dueDate = job.maintenanceDueAt!;
              final daysUntilDue = dueDate.difference(now).inDays;

              // 7 gün içinde (gelecek, geçmiş değil)
              if (daysUntilDue >= 0 && daysUntilDue <= 7) {
                maintenanceApproachingCustomerIds.add(customer.id);
                break; // Bir müşteri sadece bir kez sayılmalı
              }
            }
          }
        }
      } catch (e) {
        // Müşteri verisi hatası, atla
        continue;
      }
    }

    upcomingMaintenance = upcomingMaintenanceCustomerIds.length;
    maintenanceApproaching = maintenanceApproachingCustomerIds.length;

    // Son 1 haftada tamamlanan işler
    for (final job in jobs) {
      try {
        final status = job.status;
        if (status == "COMPLETED" || status == "DELIVERED") {
          final deliveredAt = job.deliveredAt;
          if (deliveredAt != null) {
            try {
              final deliveredDate = deliveredAt;
              // Son 1 hafta içinde mi kontrol et
              if (deliveredDate.isAfter(weekAgoStart) &&
                  deliveredDate.isBefore(now)) {
                completedLastWeek++;
              }
            } catch (e) {
              // Tarih parse hatası, atla
              continue;
            }
          }
        }
      } catch (e) {
        // İş verisi hatası, atla
        continue;
      }
    }

    return CustomerCategoryData(
      overduePayments: overduePayments,
      upcomingMaintenance: upcomingMaintenance,
      maintenanceApproaching: maintenanceApproaching,
      completedLastWeek: completedLastWeek,
      activeCustomers: activeCustomers,
      inactiveCustomers: inactiveCustomers,
    );
  } catch (e) {
    // Hata durumunda varsayılan değerler döndür
    return CustomerCategoryData(
      overduePayments: 0,
      upcomingMaintenance: 0,
      maintenanceApproaching: 0,
      completedLastWeek: 0,
      activeCustomers: 0,
      inactiveCustomers: 0,
    );
  }
});
