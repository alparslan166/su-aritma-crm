import "package:hooks_riverpod/hooks_riverpod.dart";

/// In-memory lock flag for subscription gating.
/// Router redirect uses this synchronously.
final subscriptionLockRequiredProvider = StateProvider<bool>((ref) => false);


