enum AuthRole { admin, personnel }

extension AuthRoleX on AuthRole {
  String get label => switch (this) {
    AuthRole.admin => "Admin Girişi",
    AuthRole.personnel => "Personel Girişi",
  };

  String get identifierLabel => switch (this) {
    AuthRole.admin => "E-posta",
    AuthRole.personnel => "Personel ID",
  };

  String get passwordLabel => switch (this) {
    AuthRole.admin => "Şifre",
    AuthRole.personnel => "Personel Şifre",
  };
}
