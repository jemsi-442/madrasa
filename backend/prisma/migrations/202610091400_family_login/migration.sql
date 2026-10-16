ALTER TABLE `users` ADD COLUMN `family_login_id` VARCHAR(50) NULL;
CREATE UNIQUE INDEX `users_family_login_id_key` ON `users` (`family_login_id`);

CREATE TABLE `family_registration_counters` (
  `region_code` VARCHAR(8) NOT NULL,
  `year` INTEGER NOT NULL,
  `sequence` INTEGER NOT NULL,
  PRIMARY KEY (`region_code`, `year`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
