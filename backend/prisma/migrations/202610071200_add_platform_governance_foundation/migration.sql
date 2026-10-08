-- Additive platform governance foundation. Existing school roles remain unchanged.
CREATE TABLE `platform_accounts` (
    `id` VARCHAR(30) NOT NULL,
    `email` VARCHAR(150) NOT NULL,
    `full_name` VARCHAR(150) NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `role` ENUM('SUPER_ADMIN', 'IT_SECURITY') NOT NULL,
    `status` ENUM('ACTIVE', 'DISABLED') NOT NULL DEFAULT 'DISABLED',
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    UNIQUE INDEX `platform_accounts_email_key`(`email`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `tenant_applications` (
    `id` VARCHAR(30) NOT NULL,
    `school_name` VARCHAR(150) NOT NULL,
    `requested_code` VARCHAR(50) NOT NULL,
    `admin_email` VARCHAR(150) NOT NULL,
    `status` ENUM('REQUESTED', 'APPROVED', 'REJECTED') NOT NULL DEFAULT 'REQUESTED',
    `requested_by_id` VARCHAR(30) NOT NULL,
    `reviewed_by_id` VARCHAR(30) NULL,
    `decision_reason` VARCHAR(500) NULL,
    `reviewed_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    UNIQUE INDEX `tenant_applications_requested_code_key`(`requested_code`),
    INDEX `tenant_applications_status_created_at_idx`(`status`, `created_at`),
    INDEX `tenant_applications_requested_by_id_idx`(`requested_by_id`),
    INDEX `tenant_applications_reviewed_by_id_idx`(`reviewed_by_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `platform_audit_events` (
    `id` VARCHAR(30) NOT NULL,
    `actor_id` VARCHAR(30) NOT NULL,
    `actor_role` ENUM('SUPER_ADMIN', 'IT_SECURITY') NOT NULL,
    `action` VARCHAR(100) NOT NULL,
    `entity_type` VARCHAR(100) NOT NULL,
    `entity_id` VARCHAR(100) NOT NULL,
    `metadata` JSON NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    INDEX `platform_audit_events_created_at_id_idx`(`created_at`, `id`),
    INDEX `platform_audit_events_entity_type_entity_id_idx`(`entity_type`, `entity_id`),
    INDEX `platform_audit_events_actor_id_created_at_idx`(`actor_id`, `created_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `tenant_applications` ADD CONSTRAINT `tenant_applications_requested_by_id_fkey` FOREIGN KEY (`requested_by_id`) REFERENCES `platform_accounts`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `tenant_applications` ADD CONSTRAINT `tenant_applications_reviewed_by_id_fkey` FOREIGN KEY (`reviewed_by_id`) REFERENCES `platform_accounts`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `platform_audit_events` ADD CONSTRAINT `platform_audit_events_actor_id_fkey` FOREIGN KEY (`actor_id`) REFERENCES `platform_accounts`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
