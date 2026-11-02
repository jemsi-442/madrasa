ALTER TABLE `platform_sessions` ADD COLUMN `ip_address` VARCHAR(64) NULL;
ALTER TABLE `refresh_tokens` ADD COLUMN `ip_address` VARCHAR(64) NULL;
