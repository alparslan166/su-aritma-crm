import "package:flutter/foundation.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../core/session/session_provider.dart";
import "../features/admin/data/models/customer.dart";
import "../features/admin/data/models/inventory_item.dart";
import "../features/admin/data/models/job.dart";
import "../features/admin/data/models/personnel.dart";
import "../features/admin/presentation/views/customer_detail_page.dart";
import "../features/admin/presentation/views/inventory_detail_page.dart";
import "../features/admin/presentation/views/job_detail_page.dart";
import "../features/admin/presentation/views/personnel_detail_page.dart";
import "../features/auth/domain/auth_role.dart";
import "../features/auth/presentation/login_page.dart";
import "../features/dashboard/presentation/admin_dashboard_page.dart";
import "../features/dashboard/presentation/personnel_dashboard_page.dart";
import "../features/personnel/presentation/views/job_detail_page.dart";

final appRouterProvider = Provider<GoRouter>((ref) {
  // Session state'ini dinle - bu router'ı yeniden oluşturur
  final session = ref.watch(authSessionProvider);

  // Session değişikliklerini dinlemek için ValueNotifier kullan
  final sessionNotifier = ValueNotifier<AuthSession?>(session);

  // Session değiştiğinde ValueNotifier'ı güncelle
  // ref.watch zaten router'ı yeniden oluşturur, bu yeterli

  return GoRouter(
    refreshListenable: sessionNotifier,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final isLogin = state.matchedLocation == "/";

      if (session == null && !isLogin) return "/";

      if (session != null && isLogin) {
        return session.role == AuthRole.admin
            ? "/dashboard/admin"
            : "/dashboard/personnel";
      }

      return null;
    },
    routes: [
      GoRoute(
        path: "/",
        name: LoginPage.routeName,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: "/dashboard/admin",
        name: AdminDashboardPage.routeName,
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: "/dashboard/personnel",
        name: PersonnelDashboardPage.routeName,
        builder: (context, state) => const PersonnelDashboardPage(),
      ),
      GoRoute(
        path: "/personnel/jobs/:id",
        name: "personnel-job-detail",
        builder: (context, state) =>
            PersonnelJobDetailPage(jobId: state.pathParameters["id"] ?? ""),
      ),
      GoRoute(
        path: "/admin/inventory/:id",
        name: "admin-inventory-detail",
        builder: (context, state) {
          final extra = state.extra;
          return AdminInventoryDetailPage(
            inventoryId: state.pathParameters["id"] ?? "",
            initialItem: extra is InventoryItem ? extra : null,
          );
        },
      ),
      GoRoute(
        path: "/admin/jobs/:id",
        name: "admin-job-detail",
        builder: (context, state) {
          final extra = state.extra;
          return AdminJobDetailPage(
            jobId: state.pathParameters["id"] ?? "",
            initialJob: extra is Job ? extra : null,
          );
        },
      ),
      GoRoute(
        path: "/admin/customers/:id",
        name: "admin-customer-detail",
        builder: (context, state) {
          final extra = state.extra;
          return CustomerDetailPage(
            customerId: state.pathParameters["id"] ?? "",
            initialCustomer: extra is Customer ? extra : null,
          );
        },
      ),
      GoRoute(
        path: "/admin/personnel/:id",
        name: "admin-personnel-detail",
        builder: (context, state) {
          final extra = state.extra;
          return AdminPersonnelDetailPage(
            personnelId: state.pathParameters["id"] ?? "",
            initialPersonnel: extra is Personnel ? extra : null,
          );
        },
      ),
    ],
  );
});
