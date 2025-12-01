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
      connectTimeout: const Duration(seconds: 30), // Railway cold start için artırıldı
      receiveTimeout: const Duration(seconds: 30), // Yavaş network için artırıldı
      sendTimeout: const Duration(seconds: 30),
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
      onError: (error, handler) async {
        // Connection timeout için retry mekanizması
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout) {
          final options = error.requestOptions;
          
          // Maksimum 2 retry (toplam 3 deneme)
          final retryCount = options.extra['retryCount'] as int? ?? 0;
          if (retryCount < 2) {
            options.extra['retryCount'] = retryCount + 1;
            
            // Exponential backoff: 1s, 2s
            await Future.delayed(Duration(seconds: retryCount + 1));
            
            try {
              final response = await dio.fetch(options);
              return handler.resolve(response);
            } catch (e) {
              // Retry başarısız, orijinal hatayı döndür
              return handler.reject(error);
            }
          }
        }
        return handler.next(error);
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
