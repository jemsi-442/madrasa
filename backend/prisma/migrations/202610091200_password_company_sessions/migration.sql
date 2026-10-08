-- Password-only sessions must not claim MFA verification.
ALTER TABLE `platform_sessions` MODIFY `mfa_verified_at` DATETIME(3) NULL;
