class AppConfig {
  AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://localhost:4000/api",
  );

  static const defaultAdminId = String.fromEnvironment(
    "ADMIN_ID",
    defaultValue: "ALT-ADMIN-DEMO",
  );

  static String get socketBaseUrl {
    final uri = Uri.parse(apiBaseUrl);
    final scheme = uri.scheme == "https" ? "wss" : "ws";
    final origin = uri.replace(scheme: scheme, path: "", query: "");
    return origin.toString();
  }
}
