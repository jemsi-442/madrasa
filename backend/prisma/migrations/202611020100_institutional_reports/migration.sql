CREATE TABLE `institutional_reports` (
  `id` VARCHAR(30) NOT NULL,
  `createdById` VARCHAR(30) NOT NULL,
  `requestId` VARCHAR(36) NOT NULL,
  `month` CHAR(7) NOT NULL,
  `snapshot` JSON NOT NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `institutional_reports_createdById_requestId_key` (`createdById`, `requestId`),
  INDEX `institutional_reports_createdAt_idx` (`createdAt`),
  PRIMARY KEY (`id`),
  CONSTRAINT `institutional_reports_createdById_fkey` FOREIGN KEY (`createdById`) REFERENCES `platform_accounts` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
