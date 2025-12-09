import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
// import "package:pretty_dio_logger/pretty_dio_logger.dart"; // Devre dışı

import "../../features/auth/domain/auth_role.dart";
import "../constants/app_config.dart";
import "../session/session_provider.dart";

final apiClientProvider = Provider<Dio>((ref) {
  final session = ref.watch(authSessionProvider);

  // API URL'ini logla (debug mode'da)
  if (kDebugMode) {
    debugPrint("🌐 API Base URL: ${AppConfig.apiBaseUrl}");
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 60), // Railway cold start için artırıldı
      receiveTimeout: const Duration(seconds: 60), // Yavaş network için artırıldı
      sendTimeout: const Duration(seconds: 60),
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
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          final options = error.requestOptions;
          
          if (kDebugMode) {
            debugPrint(
              "⏱️ Timeout hatası: ${error.type} - URL: ${options.uri} - Retry: ${options.extra['retryCount'] ?? 0}",
            );
          }
          
          // Maksimum 2 retry (toplam 3 deneme)
          final retryCount = options.extra['retryCount'] as int? ?? 0;
          if (retryCount < 2) {
            options.extra['retryCount'] = retryCount + 1;
            
            if (kDebugMode) {
              debugPrint("🔄 Retry ${retryCount + 1}/2 - ${retryCount + 1} saniye bekleniyor...");
            }
            
            // Exponential backoff: 1s, 2s
            await Future.delayed(Duration(seconds: retryCount + 1));
            
            try {
              final response = await dio.fetch(options);
              if (kDebugMode) {
                debugPrint("✅ Retry başarılı!");
              }
              return handler.resolve(response);
            } catch (e) {
              if (kDebugMode) {
                debugPrint("❌ Retry başarısız: $e");
              }
              // Retry başarısız, orijinal hatayı döndür
              return handler.reject(error);
            }
          } else {
            if (kDebugMode) {
              debugPrint("❌ Maksimum retry sayısına ulaşıldı. API URL kontrol edin: ${AppConfig.apiBaseUrl}");
            }
          }
        } else if (error.type == DioExceptionType.connectionError) {
          if (kDebugMode) {
            debugPrint(
              "🔌 Bağlantı hatası: ${error.message} - URL: ${error.requestOptions.uri}",
            );
            debugPrint("💡 API Base URL: ${AppConfig.apiBaseUrl}");
            debugPrint("💡 Backend'in çalıştığından ve URL'in doğru olduğundan emin olun.");
          }
        }
        return handler.next(error);
      },
    ),
  );

  // Logger devre dışı (kullanıcı isteği üzerine kapatıldı)
  // if (kDebugMode) {
  //   dio.interceptors.add(
  //     PrettyDioLogger(
  //       requestHeader: false,
  //       requestBody: true,
  //       responseHeader: false,
  //       responseBody: true,
  //       compact: true,
  //     ),
  //   );
  // }

  return dio;
});
