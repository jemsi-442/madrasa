CREATE TABLE `curriculum_lessons` (
  `id` VARCHAR(30) NOT NULL PRIMARY KEY,
  `versionId` VARCHAR(30) NOT NULL,
  `title` VARCHAR(150) NOT NULL,
  `position` INTEGER NOT NULL,
  `durationMinutes` INTEGER NOT NULL,
  `activities` TEXT NOT NULL,
  INDEX `curriculum_lessons_versionId_position_idx` (`versionId`, `position`),
  FOREIGN KEY (`versionId`) REFERENCES `curriculum_versions` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE `curriculum_lesson_objectives` (
  `lessonId` VARCHAR(30) NOT NULL,
  `objectiveId` VARCHAR(30) NOT NULL,
  PRIMARY KEY (`lessonId`, `objectiveId`),
  FOREIGN KEY (`lessonId`) REFERENCES `curriculum_lessons` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (`objectiveId`) REFERENCES `curriculum_objectives` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
