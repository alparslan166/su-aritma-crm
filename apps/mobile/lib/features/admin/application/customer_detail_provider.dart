import "package:hooks_riverpod/hooks_riverpod.dart";
import "../data/admin_repository.dart";
import "../data/models/customer.dart";

final customerDetailProvider = FutureProvider.family<Customer, String>((
  ref,
  customerId,
) {
  final repository = ref.read(adminRepositoryProvider);
  return repository.fetchCustomerDetail(customerId);
});
