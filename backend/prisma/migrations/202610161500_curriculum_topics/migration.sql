ALTER TABLE `curriculum_versions`
  ADD COLUMN `level` VARCHAR(80) NOT NULL DEFAULT '',
  DROP INDEX `curriculum_versions_subject_version_key`,
  ADD UNIQUE INDEX `curriculum_versions_subject_level_version_key` (`subject`, `level`, `version`);

CREATE TABLE `curriculum_topics` (
  `id` VARCHAR(30) NOT NULL PRIMARY KEY,
  `versionId` VARCHAR(30) NOT NULL,
  `title` VARCHAR(150) NOT NULL,
  `position` INTEGER NOT NULL,
  INDEX `curriculum_topics_versionId_position_idx` (`versionId`, `position`),
  FOREIGN KEY (`versionId`) REFERENCES `curriculum_versions` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `curriculum_objectives` (
  `id` VARCHAR(30) NOT NULL PRIMARY KEY,
  `topicId` VARCHAR(30) NOT NULL,
  `code` VARCHAR(40) NOT NULL,
  `description` VARCHAR(1000) NOT NULL,
  `assessmentMethod` VARCHAR(30) NOT NULL,
  `criteria` VARCHAR(1000) NOT NULL,
  UNIQUE INDEX `curriculum_objectives_topicId_code_key` (`topicId`, `code`),
  FOREIGN KEY (`topicId`) REFERENCES `curriculum_topics` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
