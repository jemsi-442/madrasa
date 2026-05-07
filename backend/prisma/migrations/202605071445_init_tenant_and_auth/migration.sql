CREATE TABLE `organizations` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(150) NOT NULL,
  `code` VARCHAR(50) NOT NULL,
  `status` ENUM('ACTIVE', 'SUSPENDED', 'TRIAL') NOT NULL DEFAULT 'ACTIVE',
  `plan` VARCHAR(50) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `organizations_code_key` (`code`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `branches` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `name` VARCHAR(150) NOT NULL,
  `location` VARCHAR(255) NULL,
  `phone` VARCHAR(30) NULL,
  `is_main` BOOLEAN NOT NULL DEFAULT false,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX `idx_branches_org_id` (`org_id`),
  UNIQUE INDEX `uniq_branches_org_name` (`org_id`, `name`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `users` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `branch_id` BIGINT NULL,
  `full_name` VARCHAR(150) NOT NULL,
  `email` VARCHAR(150) NULL,
  `phone` VARCHAR(30) NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `role` ENUM('ADMIN', 'ACCOUNTANT', 'TEACHER', 'PARENT') NOT NULL,
  `status` ENUM('ACTIVE', 'DISABLED') NOT NULL DEFAULT 'ACTIVE',
  `last_login_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX `idx_users_org_role` (`org_id`, `role`),
  UNIQUE INDEX `uniq_users_org_email` (`org_id`, `email`),
  UNIQUE INDEX `uniq_users_org_phone` (`org_id`, `phone`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `refresh_tokens` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `user_id` BIGINT NOT NULL,
  `token_hash` VARCHAR(255) NOT NULL,
  `expires_at` DATETIME(3) NOT NULL,
  `revoked_at` DATETIME(3) NULL,
  `replaced_by_id` BIGINT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX `idx_refresh_tokens_org_user_expires_at` (`org_id`, `user_id`, `expires_at`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `branches`
  ADD CONSTRAINT `branches_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `users`
  ADD CONSTRAINT `users_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `users`
  ADD CONSTRAINT `users_branch_id_fkey`
  FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `refresh_tokens`
  ADD CONSTRAINT `refresh_tokens_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `refresh_tokens`
  ADD CONSTRAINT `refresh_tokens_user_id_fkey`
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;
