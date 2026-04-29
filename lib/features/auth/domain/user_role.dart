enum UserRole { admin, cashier }

extension UserRoleX on UserRole {
  String get asKey => name;
}

