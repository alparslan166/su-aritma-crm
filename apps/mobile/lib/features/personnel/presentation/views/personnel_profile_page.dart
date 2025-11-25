import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";

import "../../data/personnel_repository.dart";

class PersonnelProfilePage extends ConsumerStatefulWidget {
  const PersonnelProfilePage({super.key});

  @override
  ConsumerState<PersonnelProfilePage> createState() =>
      _PersonnelProfilePageState();
}

class _PersonnelProfilePageState extends ConsumerState<PersonnelProfilePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final profile = await ref.read(personnelRepositoryProvider).fetchMyProfile();
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text("Hata: $_error"),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadProfile,
                        child: const Text("Yeniden Dene"),
                      ),
                    ],
                  ),
                )
              : _profile == null
                  ? const Center(child: Text("Profil bulunamadı"))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Header
                          Center(
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 50,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              _profile!["name"] as String? ?? "-",
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Profile Information
                          _InfoCard(
                            title: "İsim",
                            value: _profile!["name"] as String? ?? "-",
                            icon: Icons.person,
                          ),
                          const SizedBox(height: 16),
                          _InfoCard(
                            title: "Telefon",
                            value: _profile!["phone"] as String? ?? "-",
                            icon: Icons.phone,
                          ),
                          const SizedBox(height: 16),
                          _InfoCard(
                            title: "Eklenme Tarihi",
                            value: _profile!["hireDate"] != null
                                ? DateFormat("dd MMM yyyy", "tr_TR").format(
                                    DateTime.parse(_profile!["hireDate"] as String).toLocal(),
                                  )
                                : "-",
                            icon: Icons.calendar_today,
                          ),
                          const SizedBox(height: 16),
                          _InfoCard(
                            title: "Personel ID",
                            value: _profile!["personnelId"] as String? ?? "-",
                            icon: Icons.badge,
                          ),
                          const SizedBox(height: 16),
                          _InfoCard(
                            title: "Şifre",
                            value: _profile!["loginCode"] as String? ?? "-",
                            icon: Icons.lock,
                            isPassword: true,
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    this.isPassword = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool isPassword;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isPassword)
              Icon(
                Icons.visibility_off,
                size: 18,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }
}

