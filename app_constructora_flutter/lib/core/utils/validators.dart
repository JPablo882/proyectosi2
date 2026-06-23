class Validators {
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$',
  );

  static bool isValidEmail(String email) {
    return _emailRegExp.hasMatch(email);
  }
}
