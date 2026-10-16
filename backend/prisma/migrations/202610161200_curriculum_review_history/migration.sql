ALTER TABLE `curriculum_versions` ADD COLUMN `publishedAt` DATETIME(3) NULL;

CREATE TABLE `curriculum_reviews` (
  `id` VARCHAR(30) NOT NULL,
  `versionId` VARCHAR(30) NOT NULL,
  `actorId` VARCHAR(30) NOT NULL,
  `action` VARCHAR(20) NOT NULL,
  `fromStatus` ENUM('DRAFT','IN_REVIEW','APPROVED','PUBLISHED') NOT NULL,
  `toStatus` ENUM('DRAFT','IN_REVIEW','APPROVED','PUBLISHED') NOT NULL,
  `comment` TEXT NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  INDEX `curriculum_reviews_versionId_createdAt_idx` (`versionId`, `createdAt`),
  CONSTRAINT `curriculum_reviews_versionId_fkey` FOREIGN KEY (`versionId`)
    REFERENCES `curriculum_versions` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
