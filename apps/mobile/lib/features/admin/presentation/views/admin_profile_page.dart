import "dart:async";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:intl/intl.dart";

import "../../../../core/constants/app_config.dart";
import "../../../../core/network/api_client.dart" show apiClientProvider;
import "../../../../core/session/session_provider.dart";
import "../../../../routing/app_router.dart";
import "../../../auth/application/auth_service.dart";
import "../../data/admin_repository.dart";

final adminProfileProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final repository = ref.read(adminRepositoryProvider);
  return repository.getProfile();
});

final adminSubscriptionProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  try {
    final repository = ref.read(adminRepositoryProvider);
    final subscription = await repository.getSubscription();
    debugPrint("📦 Subscription provider result: $subscription");
    return subscription;
  } catch (e, stackTrace) {
    debugPrint("❌ Subscription provider error: $e");
    debugPrint("Stack trace: $stackTrace");
    // Return null instead of throwing to show empty state
    return null;
  }
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
  bool _isEditing = false;

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
      // Get presigned URL from /media/sign endpoint
      final presignedResponse = await client.post(
        "/media/sign",
        data: {
          "contentType": "image/jpeg",
          "prefix": "admin-logos",
        },
      );

      final uploadUrl = presignedResponse.data["data"]["uploadUrl"] as String;
      final key = presignedResponse.data["data"]["key"] as String;

      // Upload to S3 using a separate Dio instance (without interceptors)
      final uploadClient = Dio();
      await uploadClient.put(
        uploadUrl,
        data: _selectedLogoBytes,
        options: Options(
          headers: {"Content-Type": "image/jpeg"},
          contentType: "image/jpeg",
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      return key;
    } catch (e) {
      debugPrint("Logo upload error: $e");
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
        setState(() {
          _isEditing = false;
        });
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Profil"),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: "Düzenle",
            )
          else
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  // Reset to original values
                  _loadProfile();
                  _selectedLogoBytes = null;
                  _logoRemoved = false;
                });
              },
              child: const Text("İptal"),
            ),
        ],
      ),
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
                  // Admin ID Section (at the top)
                  Card(
                    color: profile["adminId"] != null
                        ? Colors.blue.shade50
                        : Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings,
                                color: profile["adminId"] != null
                                    ? Colors.blue.shade700
                                    : Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Admin ID",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: profile["adminId"] != null
                                      ? Colors.blue.shade900
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (profile["adminId"] != null &&
                              (profile["adminId"] as String).isNotEmpty) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    profile["adminId"] as String,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: "monospace",
                                      color: Colors.blue.shade900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.copy,
                                    color: Colors.blue.shade700,
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: profile["adminId"] as String,
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Admin ID kopyalandı"),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  tooltip: "Kopyala",
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Personeller giriş yaparken bu ID'yi kullanır",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Admin ID henüz oluşturulmamış. Lütfen yönetici ile iletişime geçin.",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                            onTap: _isEditing ? _pickLogo : null,
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
                          if (_isEditing)
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
                            enabled: _isEditing,
                            readOnly: !_isEditing,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) =>
                                _isEditing &&
                                    (value == null || value.trim().isEmpty)
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
                            enabled: _isEditing,
                            readOnly: !_isEditing,
                            validator: (value) =>
                                _isEditing &&
                                    (value == null || value.trim().length < 6)
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
                            keyboardType: TextInputType.text,
                            enabled: _isEditing,
                            readOnly: !_isEditing,
                            autocorrect: false,
                            enableSuggestions: false,
                            validator: (value) =>
                                _isEditing &&
                                    (value == null || value.trim().isEmpty)
                                ? "E-posta gerekli"
                                : _isEditing && !value!.contains("@")
                                ? "Geçerli e-posta adresi girin"
                                : null,
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
                            enabled: _isEditing,
                            readOnly: !_isEditing,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _companyAddressController,
                            decoration: const InputDecoration(
                              labelText: "Firma Adresi",
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            enabled: _isEditing,
                            readOnly: !_isEditing,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _companyPhoneController,
                            decoration: const InputDecoration(
                              labelText: "Firma Telefonu",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                            enabled: _isEditing,
                            readOnly: !_isEditing,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _companyEmailController,
                            decoration: const InputDecoration(
                              labelText: "Firma E-postası",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.text,
                            enabled: _isEditing,
                            readOnly: !_isEditing,
                            autocorrect: false,
                            enableSuggestions: false,
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
                            enabled: _isEditing,
                            readOnly: !_isEditing,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _taxNumberController,
                            decoration: const InputDecoration(
                              labelText: "Vergi Numarası",
                              border: OutlineInputBorder(),
                            ),
                            enabled: _isEditing,
                            readOnly: !_isEditing,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Subscription Section
                  Consumer(
                    builder: (context, ref, _) {
                      final subscriptionAsync = ref.watch(
                        adminSubscriptionProvider,
                      );
                      return subscriptionAsync.when(
                        data: (subscription) {
                          if (subscription == null) {
                            return Card(
                              color: Colors.orange.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.hourglass_empty,
                                          color: Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            "Abonelik bilgisi yükleniyor...",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          ref.invalidate(adminSubscriptionProvider);
                                        },
                                        icon: const Icon(Icons.refresh),
                                        label: const Text("Yenile"),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange.shade700,
                                          side: BorderSide(color: Colors.orange.shade300),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final status =
                              subscription["status"] as String? ?? "";
                          final planType =
                              subscription["planType"] as String? ?? "";
                          final startDate =
                              subscription["startDate"] as String?;
                          final endDate = subscription["endDate"] as String?;
                          final trialEnds =
                              subscription["trialEnds"] as String?;
                          final daysRemaining =
                              subscription["daysRemaining"] as int?;
                          final isExpired =
                              subscription["isExpired"] as bool? ?? false;

                          MaterialColor statusColor;
                          String statusText;
                          IconData statusIcon;

                          if (status == "trial") {
                            statusColor = Colors.orange;
                            statusText = "Deneme Süresi";
                            statusIcon = Icons.access_time;
                          } else if (status == "active") {
                            statusColor = Colors.green;
                            statusText = "Aktif Abonelik";
                            statusIcon = Icons.check_circle;
                          } else if (status == "expired" || isExpired) {
                            statusColor = Colors.red;
                            statusText = "Süresi Dolmuş";
                            statusIcon = Icons.error;
                          } else {
                            statusColor = Colors.grey;
                            statusText = "Bilinmiyor";
                            statusIcon = Icons.help;
                          }

                          String formatDate(String? dateStr) {
                            if (dateStr == null) return "Bilinmiyor";
                            try {
                              final date = DateTime.parse(dateStr);
                              return DateFormat(
                                "dd MMMM yyyy",
                                "tr_TR",
                              ).format(date);
                            } catch (e) {
                              return dateStr;
                            }
                          }

                          return Card(
                            color: statusColor.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        statusIcon,
                                        color: statusColor,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Abonelik Durumu",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: statusColor.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                statusText,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: statusColor.shade900,
                                                ),
                                              ),
                                              if (status == "trial" &&
                                                  daysRemaining != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  daysRemaining > 0
                                                      ? "$daysRemaining gün kaldı"
                                                      : "Süre doldu",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: statusColor.shade700,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            status == "trial"
                                                ? "DENEME"
                                                : status == "active"
                                                ? "AKTİF"
                                                : "SÜRESİ DOLMUŞ",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (status == "trial" &&
                                      trialEnds != null) ...[
                                    _buildInfoRow(
                                      "Deneme Bitiş Tarihi",
                                      formatDate(trialEnds),
                                      Icons.calendar_today,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (status == "active") ...[
                                    _buildInfoRow(
                                      "Plan Tipi",
                                      planType == "monthly"
                                          ? "Aylık"
                                          : "Yıllık",
                                      Icons.credit_card,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      "Başlangıç Tarihi",
                                      formatDate(startDate),
                                      Icons.play_arrow,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      "Bitiş Tarihi",
                                      formatDate(endDate),
                                      Icons.stop,
                                    ),
                                    if (daysRemaining != null) ...[
                                      const SizedBox(height: 12),
                                      _buildInfoRow(
                                        "Kalan Süre",
                                        "$daysRemaining gün",
                                        Icons.timer,
                                      ),
                                    ],
                                  ],
                                  if (isExpired) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning,
                                            color: Colors.red.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Aboneliğinizin süresi dolmuş. Lütfen aboneliğinizi yenileyin.",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.red.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  "Abonelik bilgileri yükleniyor...",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        error: (error, stackTrace) {
                          debugPrint("❌ Subscription provider error: $error");
                          debugPrint("Stack trace: $stackTrace");
                          return Card(
                            color: Colors.red.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Abonelik bilgileri yüklenirken hata oluştu: ${error.toString()}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (_isEditing) ...[
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
                  const SizedBox(height: 48),
                  // Delete Account Section
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Hesap Silme",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Hesabınızı sildiğinizde tüm verileriniz (personeller, müşteriler, işler, faturalar) kalıcı olarak silinecektir. Bu işlem geri alınamaz.",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _showDeleteAccountDialog(context),
                              icon: const Icon(Icons.delete_forever),
                              label: const Text("Hesabı Sil"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text("Hesabı Sil"),
          ],
        ),
        content: const Text(
          "Hesabınızı silmek istediğinize emin misiniz?\n\n"
          "Bu işlem geri alınamaz ve tüm verileriniz silinecektir:\n"
          "• Tüm personeller\n"
          "• Tüm müşteriler\n"
          "• Tüm işler ve faturalar\n"
          "• Tüm envanter kayıtları",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Önce doğrulama kodu iste, sonra doğrulama ekranını göster
              try {
                await ref.read(authServiceProvider).requestAccountDeletion();
                if (!mounted) return;
                _showVerificationCodeDialog();
              } on AuthException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Hesabı Sil"),
          ),
        ],
      ),
    );
  }


  void _showVerificationCodeDialog() {
    final codeController = TextEditingController();
    final isLoading = ValueNotifier(false);
    Timer? resendTimer;
    final resendCountdown = ValueNotifier(60);

    void startResendTimer() {
      resendCountdown.value = 60;
      resendTimer?.cancel();
      resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (resendCountdown.value > 0) {
          resendCountdown.value--;
        } else {
          timer.cancel();
        }
      });
    }

    startResendTimer();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.email, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text("Doğrulama Kodu"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("E-posta adresinize gönderilen 6 haneli kodu girin:"),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _emailController.text,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: "Doğrulama Kodu",
                  hintText: "6 haneli kod",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<int>(
                valueListenable: resendCountdown,
                builder: (context, countdown, _) {
                  if (countdown > 0) {
                    return Text(
                      "Tekrar gönder ($countdown s)",
                      style: TextStyle(color: Colors.grey.shade600),
                    );
                  }
                  return TextButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(authServiceProvider)
                            .requestAccountDeletion();
                        startResendTimer();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Kod tekrar gönderildi"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } on AuthException catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.message),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text("Kodu tekrar gönder"),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                resendTimer?.cancel();
                Navigator.of(context).pop();
              },
              child: const Text("İptal"),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isLoading,
              builder: (context, loading, _) => FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (codeController.text.length != 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Lütfen 6 haneli kodu girin"),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        isLoading.value = true;
                        try {
                          await ref
                              .read(authServiceProvider)
                              .confirmAccountDeletion(codeController.text);
                          resendTimer?.cancel();
                          if (!mounted) return;
                          Navigator.of(context).pop();

                          // Clear session and redirect to login
                          await ref
                              .read(authSessionProvider.notifier)
                              .clearSession();
                          if (!mounted) return;
                          ref.read(appRouterProvider).go("/");

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Hesabınız başarıyla silindi"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } on AuthException catch (e) {
                          isLoading.value = false;
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Hesabı Sil"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
