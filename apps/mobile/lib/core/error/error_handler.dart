import "package:dio/dio.dart";
import "package:flutter/material.dart";

/// Utility class to convert technical errors to user-friendly messages
class ErrorHandler {
  ErrorHandler._();

  /// Converts any error to a user-friendly message
  static String getUserFriendlyMessage(dynamic error) {
    if (error is DioException) {
      return _handleDioException(error);
    }

    if (error is String) {
      // Filter out all technical details
      if (_isTechnicalMessage(error)) {
        return _extractUserFriendlyMessage(error);
      }
      return error;
    }

    // If error is an Exception or Error object, convert to string and filter
    if (error is Exception || error is Error) {
      final errorString = error.toString();
      if (_isTechnicalMessage(errorString)) {
        return _extractUserFriendlyMessage(errorString);
      }
      return errorString;
    }

    // Default message for unknown errors
    return "Bir hata oluştu. Lütfen tekrar deneyin.";
  }

  /// Checks if a message contains technical details that should be filtered
  static bool _isTechnicalMessage(String message) {
    final technicalKeywords = [
      "Exception",
      "Error:",
      "status code",
      "DioException",
      "bad response",
      "RequestOptions",
      "validateStatus",
      "Client error",
      "Server error",
      "Stack trace",
      "at ",
      "TypeError",
      "FormatException",
      "NoSuchMethodError",
      "AssertionError",
      "RangeError",
      "StateError",
      "UnimplementedError",
      "UnsupportedError",
      "ArgumentError",
      "ConcurrentModificationError",
      "CyclicInitializationError",
      "FallThroughError",
      "NoSuchMethodError",
      "OutOfMemoryError",
      "StackOverflowError",
      "UnsupportedOperationError",
    ];

    return technicalKeywords.any((keyword) => 
      message.toLowerCase().contains(keyword.toLowerCase())
    );
  }

  /// Extracts user-friendly message from technical error
  static String _extractUserFriendlyMessage(String technicalMessage) {
    // Try to extract meaningful parts before technical details
    final lines = technicalMessage.split('\n');
    for (final line in lines) {
      if (!_isTechnicalMessage(line) && line.trim().isNotEmpty) {
        // Clean up the line
        String cleaned = line.trim();
        // Remove common prefixes
        cleaned = cleaned.replaceAll(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
        cleaned = cleaned.replaceAll(RegExp(r'^Error:\s*'), '');
        if (cleaned.isNotEmpty && !_isTechnicalMessage(cleaned)) {
          return cleaned;
        }
      }
    }

    // If we can't extract anything, return generic message
    return "Bir hata oluştu. Lütfen tekrar deneyin.";
  }

  /// Handles DioException and converts to user-friendly messages
  static String _handleDioException(DioException error) {
    // Try to get message from response
    if (error.response?.data != null) {
      final errorData = error.response!.data;

      // Check for message field
      if (errorData is Map<String, dynamic>) {
        // Check for issues array (Zod validation errors)
        if (errorData.containsKey("issues") && errorData["issues"] is List) {
          final issues = errorData["issues"] as List;
          if (issues.isNotEmpty) {
            final firstIssue = issues[0] as Map<String, dynamic>;
            return firstIssue["message"]?.toString() ??
                "Girdiğiniz bilgileri kontrol edin";
          }
        }

        // Check for direct message
        if (errorData.containsKey("message")) {
          final message = errorData["message"].toString();
          // Filter out technical details
          if (!_isTechnicalMessage(message)) {
            return message;
          }
        }

        // Check for error field
        if (errorData.containsKey("error")) {
          final errorMsg = errorData["error"].toString();
          if (!_isTechnicalMessage(errorMsg)) {
            return errorMsg;
          }
        }
      }
    }

    // Handle specific status codes
    switch (error.response?.statusCode) {
      case 400:
        return "Girdiğiniz bilgileri kontrol edin";
      case 401:
        return "Oturum süreniz dolmuş. Lütfen tekrar giriş yapın";
      case 403:
        return "Bu işlem için yetkiniz bulunmuyor";
      case 404:
        return "Aradığınız kayıt bulunamadı";
      case 409:
        return "Bu kayıt zaten mevcut";
      case 422:
        return "Girdiğiniz bilgiler geçersiz";
      case 500:
      case 502:
      case 503:
        return "Sunucu hatası. Lütfen daha sonra tekrar deneyin";
      default:
        // Handle connection errors
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          return "Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin";
        }
        if (error.type == DioExceptionType.connectionError) {
          return "İnternet bağlantınızı kontrol edin";
        }
        return "Bir hata oluştu. Lütfen tekrar deneyin";
    }
  }

  /// Shows a user-friendly error message in a SnackBar
  static void showError(BuildContext context, dynamic error) {
    final message = getUserFriendlyMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Shows a success message in a SnackBar
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows a warning message in a SnackBar
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

