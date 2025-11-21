import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:socket_io_client/socket_io_client.dart" as sio;

import "../constants/app_config.dart";
import "../session/session_provider.dart";

typedef SocketEventHandler = void Function(dynamic data);

final socketClientProvider = Provider<sio.Socket?>((ref) {
  final session = ref.watch(authSessionProvider);
  if (session == null) {
    return null;
  }

  final uri = AppConfig.socketBaseUrl;
  final socket = sio.io(
    uri,
    sio.OptionBuilder()
        .setTransports(["websocket"])
        .setQuery({"role": session.role.name, "identifier": session.identifier})
        .disableAutoConnect()
        .build(),
  );

  socket.connect();

  ref.onDispose(() {
    socket.dispose();
  });

  return socket;
});
