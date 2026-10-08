ALTER TABLE `organizations`
  MODIFY `status` ENUM('ACTIVE', 'SUSPENDED', 'TRIAL', 'PENDING_ACTIVATION') NOT NULL DEFAULT 'ACTIVE';

ALTER TABLE `tenant_applications`
  ADD COLUMN `organization_id` BIGINT NULL,
  ADD COLUMN `provisioned_at` DATETIME(3) NULL,
  ADD UNIQUE INDEX `tenant_applications_organization_id_key` (`organization_id`),
  ADD CONSTRAINT `tenant_applications_organization_id_fkey`
    FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE;
