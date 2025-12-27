// Conditional export for web/non-web platforms
export 'web_stub.dart'
    if (dart.library.html) 'web_html.dart';
