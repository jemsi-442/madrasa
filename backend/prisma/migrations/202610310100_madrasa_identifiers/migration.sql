CREATE TABLE `madrasa_code_sequence` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE `tenant_applications` ADD COLUMN `government_registration_number` VARCHAR(100) NULL;
ALTER TABLE `organizations` ADD COLUMN `government_registration_number` VARCHAR(100) NULL;
