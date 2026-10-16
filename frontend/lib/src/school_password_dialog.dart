import 'package:flutter/material.dart';
import 'admin_forms.dart';

Future<bool> showSchoolPasswordDialog(
  BuildContext context,
  PageSubmitter submit,
) => showAdminForm(
  context,
  title: 'Change password',
  saveLabel: 'Change and sign out',
  note:
      'Choose a new password and keep it private. All devices will need to sign in again after this change.',
  fields: const [
    AdminField('currentPassword', 'Current password', kind: 'password'),
    AdminField('password', 'New password', kind: 'password'),
    AdminField('confirmPassword', 'Confirm new password', kind: 'password'),
  ],
  onSave: (body) async {
    if (body['password'] != body['confirmPassword']) {
      throw const FormatException('Passwords do not match');
    }
    await submit('/api/auth/change-password', body);
  },
  errorMessage: (error) => error is FormatException
      ? 'Passwords do not match.'
      : 'Password could not be changed. Check your current password and connection, then try again.',
);
