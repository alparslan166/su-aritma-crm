import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:pretty_dio_logger/pretty_dio_logger.dart";

import "../../features/auth/domain/auth_role.dart";
import "../constants/app_config.dart";
import "../session/session_provider.dart";

final apiClientProvider = Provider<Dio>((ref) {
  final session = ref.watch(authSessionProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {"Content-Type": "application/json"},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (session != null) {
          if (session.role == AuthRole.admin) {
            options.headers["x-admin-id"] = session.identifier;
          } else if (session.role == AuthRole.personnel) {
            options.headers["x-personnel-id"] = session.identifier;
          }
        }
        handler.next(options);
      },
    ),
  );

  // Logger sadece debug mode'da aktif
  if (kDebugMode) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        compact: true,
      ),
    );
  }

  return dio;
});
