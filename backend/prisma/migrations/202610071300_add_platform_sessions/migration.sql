CREATE TABLE `platform_sessions` (
    `id` VARCHAR(36) NOT NULL,
    `account_id` VARCHAR(30) NOT NULL,
    `role` ENUM('SUPER_ADMIN', 'IT_SECURITY') NOT NULL,
    `mfa_verified_at` DATETIME(3) NOT NULL,
    `expires_at` DATETIME(3) NOT NULL,
    `revoked_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    INDEX `platform_sessions_account_id_revoked_at_expires_at_idx`(`account_id`, `revoked_at`, `expires_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `platform_sessions` ADD CONSTRAINT `platform_sessions_account_id_fkey` FOREIGN KEY (`account_id`) REFERENCES `platform_accounts`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
