ALTER TABLE `platform_accounts`
    ADD COLUMN `mfa_secret_encrypted` VARCHAR(255) NULL,
    ADD COLUMN `last_mfa_step` BIGINT NOT NULL DEFAULT -1;
