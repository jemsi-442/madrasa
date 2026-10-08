CREATE TABLE `school_admin_invitations` (
  `id` VARCHAR(30) NOT NULL,
  `application_id` VARCHAR(30) NOT NULL,
  `issued_by_id` VARCHAR(30) NOT NULL,
  `email` VARCHAR(150) NOT NULL,
  `token_hash` CHAR(64) NOT NULL,
  `expires_at` DATETIME(3) NOT NULL,
  `accepted_at` DATETIME(3) NULL,
  `accepted_user_id` BIGINT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `school_admin_invitations_application_id_key` (`application_id`),
  UNIQUE INDEX `school_admin_invitations_token_hash_key` (`token_hash`),
  UNIQUE INDEX `school_admin_invitations_accepted_user_id_key` (`accepted_user_id`),
  CONSTRAINT `school_admin_invitations_application_id_fkey` FOREIGN KEY (`application_id`) REFERENCES `tenant_applications` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `school_admin_invitations_issued_by_id_fkey` FOREIGN KEY (`issued_by_id`) REFERENCES `platform_accounts` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `school_admin_invitations_accepted_user_id_fkey` FOREIGN KEY (`accepted_user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
