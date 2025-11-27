import "dart:typed_data";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../../../../core/constants/app_config.dart";
import "../../../../core/network/api_client.dart" show apiClientProvider;
import "../../../../widgets/admin_app_bar.dart";
import "../../data/admin_repository.dart";

final adminProfileProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final repository = ref.read(adminRepositoryProvider);
  return repository.getProfile();
});

class AdminProfilePage extends ConsumerStatefulWidget {
  const AdminProfilePage({super.key});

  @override
  ConsumerState<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends ConsumerState<AdminProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _taxOfficeController = TextEditingController();
  final _taxNumberController = TextEditingController();

  Uint8List? _selectedLogoBytes;
  String? _currentLogoUrl;
  String? _originalLogoUrl; // Başlangıçtaki logo URL'ini sakla
  bool _logoRemoved = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _taxOfficeController.dispose();
    _taxNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ref.read(adminRepositoryProvider).getProfile();
    setState(() {
      _nameController.text = profile["name"] as String? ?? "";
      _phoneController.text = profile["phone"] as String? ?? "";
      _emailController.text = profile["email"] as String? ?? "";
      _companyNameController.text = profile["companyName"] as String? ?? "";
      _companyAddressController.text =
          profile["companyAddress"] as String? ?? "";
      _companyPhoneController.text = profile["companyPhone"] as String? ?? "";
      _companyEmailController.text = profile["companyEmail"] as String? ?? "";
      _taxOfficeController.text = profile["taxOffice"] as String? ?? "";
      _taxNumberController.text = profile["taxNumber"] as String? ?? "";
      _currentLogoUrl = profile["logoUrl"] as String?;
      _originalLogoUrl = profile["logoUrl"] as String?;
      _logoRemoved = false;
    });
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedLogoBytes = bytes;
      });
    }
  }

  Future<String?> _uploadLogo() async {
    if (_selectedLogoBytes == null) return null;

    try {
      final client = ref.read(apiClientProvider);
      // Get presigned URL
      final presignedResponse = await client.post(
        "/media/presigned-url",
        data: {
          "fileName": "logo_${DateTime.now().millisecondsSinceEpoch}.jpg",
          "contentType": "image/jpeg",
        },
      );

      final uploadUrl = presignedResponse.data["data"]["uploadUrl"] as String;
      final key = presignedResponse.data["data"]["key"] as String;

      // Upload to S3
      await client.put(
        uploadUrl,
        data: _selectedLogoBytes,
        options: Options(
          headers: {"Content-Type": "image/jpeg"},
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      return key;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Logo yüklenemedi: $e")));
      }
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? logoUrl;
      if (_selectedLogoBytes != null) {
        // Yeni logo yüklendi
        logoUrl = await _uploadLogo();
        if (logoUrl == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } else if (_logoRemoved) {
        // Logo kaldırıldı
        logoUrl = "";
      } else if (_originalLogoUrl != null && _currentLogoUrl == null) {
        // Başlangıçta logo vardı ama şimdi yok (kaldırıldı)
        logoUrl = "";
      }
      // Eğer _selectedLogoBytes null ve _logoRemoved false ise, logoUrl undefined kalır (mevcut logo korunur)

      await ref
          .read(adminRepositoryProvider)
          .updateProfile(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            companyName: _companyNameController.text.trim().isEmpty
                ? null
                : _companyNameController.text.trim(),
            companyAddress: _companyAddressController.text.trim().isEmpty
                ? null
                : _companyAddressController.text.trim(),
            companyPhone: _companyPhoneController.text.trim().isEmpty
                ? null
                : _companyPhoneController.text.trim(),
            companyEmail: _companyEmailController.text.trim().isEmpty
                ? null
                : _companyEmailController.text.trim(),
            taxOffice: _taxOfficeController.text.trim().isEmpty
                ? null
                : _taxOfficeController.text.trim(),
            taxNumber: _taxNumberController.text.trim().isEmpty
                ? null
                : _taxNumberController.text.trim(),
            logoUrl: logoUrl,
          );

      // Refresh profile
      ref.invalidate(adminProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Profil güncellendi")));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Profil güncellenemedi: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(adminProfileProvider);

    return Scaffold(
      appBar: const AdminAppBar(title: Text("Profil")),
      body: profileAsync.when(
        data: (profile) {
          // Load data once
          if (_nameController.text.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadProfile();
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            "Logo",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _pickLogo,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2563EB,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: _selectedLogoBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        _selectedLogoBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : _currentLogoUrl != null &&
                                        _currentLogoUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        AppConfig.getMediaUrl(_currentLogoUrl!),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF2563EB,
                                                  ).withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.water_drop,
                                                  color: Color(0xFF2563EB),
                                                  size: 80,
                                                ),
                                              );
                                            },
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF2563EB,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.water_drop,
                                        color: Color(0xFF2563EB),
                                        size: 80,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: _pickLogo,
                                icon: const Icon(Icons.upload),
                                label: const Text("Logo Yükle"),
                              ),
                              if ((_currentLogoUrl != null &&
                                      _currentLogoUrl!.isNotEmpty) ||
                                  _selectedLogoBytes != null)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedLogoBytes = null;
                                      _currentLogoUrl = null;
                                      _logoRemoved = true;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    "Kaldır",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Personal Info Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Kişisel Bilgiler",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: "Ad Soyad",
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? "Ad soyad gerekli"
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: "Telefon",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) =>
                                value == null || value.trim().length < 6
                                ? "Geçerli telefon numarası girin"
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: "E-posta",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? "E-posta gerekli"
                                : value.contains("@")
                                ? null
                                : "Geçerli e-posta adresi girin",
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Company Info Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Firma Bilgileri",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _companyNameController,
                            decoration: const InputDecoration(
                              labelText: "Firma Adı",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.none,
                            enableSuggestions: true,
                            autocorrect: false,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _companyAddressController,
                            decoration: const InputDecoration(
                              labelText: "Firma Adresi",
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _companyPhoneController,
                            decoration: const InputDecoration(
                              labelText: "Firma Telefonu",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _companyEmailController,
                            decoration: const InputDecoration(
                              labelText: "Firma E-postası",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tax Info Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Vergi Bilgileri",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _taxOfficeController,
                            decoration: const InputDecoration(
                              labelText: "Vergi Dairesi",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _taxNumberController,
                            decoration: const InputDecoration(
                              labelText: "Vergi Numarası",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Kaydet"),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text("Hata: $error")),
      ),
    );
  }
}
