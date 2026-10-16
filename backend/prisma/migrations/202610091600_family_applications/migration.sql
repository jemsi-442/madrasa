ALTER TABLE `users` ADD COLUMN `auth_version` INTEGER NOT NULL DEFAULT 0;
CREATE TABLE `family_applications` (
  `id` VARCHAR(36) NOT NULL,
  `org_id` BIGINT NOT NULL,
  `branch_id` BIGINT NOT NULL,
  `full_name` VARCHAR(150) NOT NULL,
  `email` VARCHAR(150) NOT NULL,
  `phone` VARCHAR(30) NOT NULL,
  `child_reference` VARCHAR(500) NOT NULL,
  `receipt_hash` VARCHAR(64) NOT NULL,
  `password_hash` VARCHAR(255) NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  `user_id` BIGINT NULL,
  `reviewed_by` BIGINT NULL,
  `reviewed_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE INDEX `family_applications_org_id_email_key` (`org_id`, `email`),
  INDEX `family_applications_org_id_branch_id_status_idx` (`org_id`, `branch_id`, `status`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE `family_applications` ADD CONSTRAINT `family_applications_org_id_fkey` FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `family_applications` ADD CONSTRAINT `family_applications_branch_id_fkey` FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
