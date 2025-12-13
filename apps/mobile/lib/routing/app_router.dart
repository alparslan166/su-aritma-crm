import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../core/session/session_provider.dart";
import "../core/subscription/subscription_lock_provider.dart";
import "../features/admin/data/models/customer.dart";
import "../features/admin/data/models/inventory_item.dart";
import "../features/admin/data/models/job.dart";
import "../features/admin/data/models/personnel.dart";
import "../features/admin/presentation/views/customer_detail_page.dart";
import "../features/admin/presentation/views/inventory_detail_page.dart";
import "../features/admin/presentation/views/job_detail_page.dart";
import "../features/admin/presentation/views/personnel_detail_page.dart";
import "../features/auth/domain/auth_role.dart";
import "../features/auth/presentation/email_verification_page.dart";
import "../features/auth/presentation/forgot_password_page.dart";
import "../features/auth/presentation/login_page.dart";
import "../features/auth/presentation/register_page.dart";
import "../features/dashboard/presentation/admin_dashboard_page.dart";
import "../features/dashboard/presentation/personnel_dashboard_page.dart";
import "../features/personnel/presentation/views/job_detail_page.dart";
import "../features/subscription/presentation/subscription_lock_page.dart";

final appRouterProvider = Provider<GoRouter>((ref) {
  // Session state'ini dinle - bu router'ı yeniden oluşturur
  ref.watch(authSessionProvider);
  // Subscription lock state'ini dinle - redirect için
  ref.watch(subscriptionLockRequiredProvider);

  return GoRouter(
    redirect: (context, state) {
      final currentSession = ref.read(authSessionProvider);
      final lockRequired = ref.read(subscriptionLockRequiredProvider);
      final isLogin = state.matchedLocation == "/";
      final isRegister = state.matchedLocation == "/register";
      final isEmailVerification = state.matchedLocation.startsWith(
        "/email-verification",
      );
      final isForgotPassword = state.matchedLocation == "/forgot-password";
      final isSubscriptionLock = state.matchedLocation == "/subscription/lock";

      // Public routes that don't require authentication
      if (currentSession == null &&
          !isLogin &&
          !isRegister &&
          !isEmailVerification &&
          !isForgotPassword) {
        return "/";
      }

      // If subscription lock is required for admin, redirect everything to lock page
      if (currentSession != null &&
          currentSession.role == AuthRole.admin &&
          lockRequired == true &&
          !isSubscriptionLock) {
        return "/subscription/lock";
      }

      if (currentSession != null && (isLogin || isRegister)) {
        return currentSession.role == AuthRole.admin
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
        path: "/register",
        name: RegisterPage.routeName,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: "/email-verification",
        name: EmailVerificationPage.routeName,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          return EmailVerificationPage(
            email: extra?["email"] ?? "",
            name: extra?["name"] ?? "",
            password: extra?["password"] ?? "",
          );
        },
      ),
      GoRoute(
        path: "/forgot-password",
        name: ForgotPasswordPage.routeName,
        builder: (context, state) => const ForgotPasswordPage(),
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
        path: "/subscription/lock",
        name: "subscription-lock",
        builder: (context, state) => const SubscriptionLockPage(),
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
