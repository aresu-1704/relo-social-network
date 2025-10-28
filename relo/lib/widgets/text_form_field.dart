import 'package:flutter/material.dart';

class BuildTextFormField {
  // Widget helper để xây dựng các trường TextFormField cho gọn
  static Widget buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
    Function(String)? onChanged,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? toggleObscure,
    int? maxLength,
  }) {
    const Color mainColor = Color(0xFF7A2FC0);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      cursorColor: mainColor,
      onChanged: onChanged, // ✅ Gọi trực tiếp callback, Flutter tự truyền value
      maxLength: maxLength,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: mainColor),
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: mainColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: mainColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility : Icons.visibility_off,
                  color: mainColor,
                ),
                onPressed: toggleObscure,
              )
            : null,
      ),
    );
  }
}
