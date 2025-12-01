import "package:flutter/foundation.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:socket_io_client/socket_io_client.dart" as sio;

import "../constants/app_config.dart";
import "../session/session_provider.dart";

typedef SocketEventHandler = void Function(dynamic data);

final socketClientProvider = Provider<sio.Socket?>((ref) {
  final session = ref.watch(authSessionProvider);
  if (session == null) {
    debugPrint("🔌 Socket: No session, returning null");
    return null;
  }

  final uri = AppConfig.socketBaseUrl;
  debugPrint("🔌 Socket: Connecting to $uri");
  debugPrint(
    "🔌 Socket: Role: ${session.role.name}, Identifier: ${session.identifier}",
  );

  // Ensure query parameters are valid strings
  final roleStr = session.role.name;
  final userIdStr = session.identifier;
  
  if (roleStr.isEmpty || userIdStr.isEmpty) {
    debugPrint("⚠️ Socket: Invalid session data - role: $roleStr, userId: $userIdStr");
    return null;
  }

  final socket = sio.io(
    uri,
    sio.OptionBuilder()
        .setTransports(["websocket"])
        .setQuery({
          "role": roleStr,
          "userId": userIdStr,
        })
        .disableAutoConnect()
        .build(),
  );

  socket.onConnect((_) {
    debugPrint("✅ Socket: Connected successfully");
  });

  socket.onDisconnect((_) {
    debugPrint("❌ Socket: Disconnected");
  });

  socket.onError((error) {
    debugPrint("❌ Socket: Error: $error");
  });

  socket.onConnectError((error) {
    debugPrint("❌ Socket: Connection error: $error");
  });

  socket.connect();

  ref.onDispose(() {
    debugPrint("🔌 Socket: Disposing socket");
    socket.dispose();
  });

  return socket;
});
