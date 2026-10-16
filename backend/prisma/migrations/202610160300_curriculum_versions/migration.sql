CREATE TABLE `curriculum_versions` (
  `id` VARCHAR(30) NOT NULL,
  `subject` VARCHAR(120) NOT NULL,
  `version` VARCHAR(30) NOT NULL,
  `description` VARCHAR(500) NOT NULL,
  `objectives` JSON NOT NULL,
  `status` ENUM('DRAFT','IN_REVIEW','APPROVED','PUBLISHED') NOT NULL DEFAULT 'DRAFT',
  `createdBy` VARCHAR(30) NOT NULL,
  `reviewedBy` VARCHAR(30) NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updatedAt` DATETIME(3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `curriculum_versions_subject_version_key` (`subject`, `version`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `curriculum_assignments` (
  `id` VARCHAR(30) NOT NULL,
  `versionId` VARCHAR(30) NOT NULL,
  `organizationId` BIGINT NOT NULL,
  `assignedBy` VARCHAR(30) NOT NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE INDEX `curriculum_assignments_versionId_organizationId_key` (`versionId`, `organizationId`),
  CONSTRAINT `curriculum_assignments_versionId_fkey` FOREIGN KEY (`versionId`) REFERENCES `curriculum_versions` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `curriculum_assignments_organizationId_fkey` FOREIGN KEY (`organizationId`) REFERENCES `organizations` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
