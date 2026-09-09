// validators.dart placeholder
bool isValidEmail(String email) {
  return RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email);
}

bool isValidPassword(String password) {
  return password.length >= 6;
}
