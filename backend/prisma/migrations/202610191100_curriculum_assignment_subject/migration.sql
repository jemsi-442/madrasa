ALTER TABLE `curriculum_assignments`
  ADD COLUMN `subjectId` BIGINT NULL,
  ADD INDEX `curriculum_assignments_organizationId_subjectId_idx` (`organizationId`, `subjectId`);

UPDATE `curriculum_assignments` AS assignment
JOIN (
  SELECT `orgId`, `assignmentId`, MIN(`subjectId`) AS `subjectId`
  FROM `class_curricula`
  GROUP BY `orgId`, `assignmentId`
  HAVING COUNT(DISTINCT `subjectId`) = 1
) AS adoption ON adoption.`orgId` = assignment.`organizationId`
  AND adoption.`assignmentId` = assignment.`id`
SET assignment.`subjectId` = adoption.`subjectId`;

ALTER TABLE `curriculum_assignments`
  ADD CONSTRAINT `curriculum_assignments_organizationId_subjectId_fkey`
  FOREIGN KEY (`organizationId`, `subjectId`) REFERENCES `subjects` (`org_id`, `id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;
