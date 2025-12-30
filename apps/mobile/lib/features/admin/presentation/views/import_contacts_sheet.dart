import "package:flutter/material.dart";
import "package:flutter_contacts/flutter_contacts.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:permission_handler/permission_handler.dart";

import "../../data/admin_repository.dart";
import "../../application/customer_list_notifier.dart";

class ImportContactsSheet extends ConsumerStatefulWidget {
  const ImportContactsSheet({super.key});

  @override
  ConsumerState<ImportContactsSheet> createState() => _ImportContactsSheetState();
}

class _ImportContactsSheetState extends ConsumerState<ImportContactsSheet> {
  List<Contact> _contacts = [];
  final Set<String> _selectedContactIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check current permission status
      var status = await Permission.contacts.status;
      debugPrint("Current contacts permission status: $status");
      
      if (!status.isGranted) {
        // Request permission
        debugPrint("Requesting contacts permission...");
        status = await Permission.contacts.request();
        debugPrint("Permission request result: $status");
      }
      
      if (!status.isGranted) {
        setState(() {
          _error = status.isPermanentlyDenied 
              ? "Rehber izni kalıcı olarak reddedildi.\n\nLütfen ayarlardan 'Kişiler' iznini açın."
              : "Rehber izni verilmedi.\n\nLütfen izin verin.";
          _isLoading = false;
        });
        return;
      }

      // Load contacts with phone numbers
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      // Filter contacts that have at least one phone number
      final contactsWithPhone = contacts.where((c) => c.phones.isNotEmpty).toList();

      // Sort by name
      contactsWithPhone.sort((a, b) => a.displayName.compareTo(b.displayName));

      setState(() {
        _contacts = contactsWithPhone;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Rehber yüklenemedi: $e";
        _isLoading = false;
      });
    }
  }

  List<Contact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    return _contacts
        .where((c) =>
            c.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.phones.any((p) => p.number.contains(_searchQuery)))
        .toList();
  }

  void _toggleSelection(String contactId) {
    setState(() {
      if (_selectedContactIds.contains(contactId)) {
        _selectedContactIds.remove(contactId);
      } else {
        _selectedContactIds.add(contactId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedContactIds.length == _filteredContacts.length) {
        _selectedContactIds.clear();
      } else {
        _selectedContactIds.addAll(_filteredContacts.map((c) => c.id));
      }
    });
  }

  Future<void> _importSelectedContacts() async {
    if (_selectedContactIds.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(adminRepositoryProvider);
      int successCount = 0;
      int failCount = 0;

      for (final contactId in _selectedContactIds) {
        final contact = _contacts.firstWhere((c) => c.id == contactId);
        final phone = contact.phones.first.number.replaceAll(RegExp(r'[^\d+]'), '');
        
        debugPrint("Creating customer: name=${contact.displayName}, phone=$phone");
        
        try {
          await repository.createCustomer(
            name: contact.displayName,
            phone: phone,
            address: "Rehberden aktarıldı", // Default address
          );
          successCount++;
          debugPrint("SUCCESS: Created customer ${contact.displayName}");
        } catch (e) {
          failCount++;
          debugPrint("FAILED to create customer for ${contact.displayName}: $e");
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount > 0
                  ? "$successCount müşteri eklendi, $failCount başarısız oldu"
                  : "$successCount müşteri başarıyla eklendi",
            ),
          ),
        );
        // Refresh customers list
        ref.invalidate(customerListProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rehberden İçeri Aktar"),
        actions: [
          if (_contacts.isNotEmpty)
            TextButton.icon(
              onPressed: _selectAll,
              icon: Icon(
                _selectedContactIds.length == _filteredContacts.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              label: Text(
                _selectedContactIds.length == _filteredContacts.length
                    ? "Temizle"
                    : "Tümünü Seç",
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Kişi ara...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Selected count
          if (_selectedContactIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF2563EB).withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    "${_selectedContactIds.length} kişi seçildi",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _buildContent(),
          ),

          // Import button
          if (_selectedContactIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _importSelectedContacts,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(
                      _isSaving
                          ? "İçeri aktarılıyor..."
                          : "${_selectedContactIds.length} Kişiyi İçeri Aktar",
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Rehber yükleniyor..."),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  // Open app settings using permission_handler
                  await openAppSettings();
                },
                icon: const Icon(Icons.settings),
                label: const Text("Ayarlara Git"),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadContacts,
                icon: const Icon(Icons.refresh),
                label: const Text("Tekrar Dene"),
              ),
            ],
          ),
        ),
      );
    }

    if (_contacts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text("Rehberde telefon numarası olan kişi bulunamadı."),
          ],
        ),
      );
    }

    final filteredContacts = _filteredContacts;

    if (filteredContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text("\"$_searchQuery\" için sonuç bulunamadı."),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = filteredContacts[index];
        final isSelected = _selectedContactIds.contains(contact.id);
        final phone = contact.phones.first.number;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isSelected
                ? const Color(0xFF2563EB)
                : Colors.grey.shade300,
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white)
                : Text(
                    contact.displayName.isNotEmpty
                        ? contact.displayName[0].toUpperCase()
                        : "?",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          title: Text(
            contact.displayName,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(phone),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleSelection(contact.id),
            activeColor: const Color(0xFF2563EB),
          ),
          onTap: () => _toggleSelection(contact.id),
        );
      },
    );
  }
}
