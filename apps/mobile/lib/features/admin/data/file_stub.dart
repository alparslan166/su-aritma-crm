// Stub file for Web platform
// This file is used when dart:io is not available (Web platform)
// It provides a minimal File-like interface that will never be called on Web

class File {
  File(String path) {
    throw UnsupportedError("File operations not supported on Web platform");
  }
  
  Future<void> writeAsBytes(List<int> bytes) async {
    throw UnsupportedError("File operations not supported on Web platform");
  }
}

