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

  // S3 Media URL - adjust based on your S3/CDN setup
  // For public S3 buckets: https://{bucket}.s3.{region}.amazonaws.com/{key}
  // For CloudFront: https://{cloudfront-domain}/{key}
  static String getMediaUrl(String key) {
    // If key is already a full URL, return it
    if (key.startsWith("http://") || key.startsWith("https://")) {
      return key;
    }
    // If key starts with "default/", it's a default photo - return as is for now
    // You may want to serve default photos from assets or a CDN
    if (key.startsWith("default/")) {
      return key; // Will be handled by Image.asset
    }
    // Construct S3 URL - adjust this based on your setup
    // For now, assuming backend returns full URLs or we construct them here
    // You may need to add S3_BASE_URL to your environment
    const s3BaseUrl = String.fromEnvironment(
      "S3_BASE_URL",
      defaultValue: "", // Set this to your S3/CDN base URL
    );
    if (s3BaseUrl.isNotEmpty) {
      return "$s3BaseUrl/$key";
    }
    // Fallback: return key as-is (backend should return full URL)
    return key;
  }
}
