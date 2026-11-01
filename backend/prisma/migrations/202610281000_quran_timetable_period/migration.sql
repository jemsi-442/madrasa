CREATE UNIQUE INDEX `uniq_timetable_org_id` ON `class_timetable_slots` (`org_id`, `id`);
ALTER TABLE `quran_sessions` ADD COLUMN `timetable_slot_id` BIGINT NULL;
CREATE INDEX `idx_quran_period` ON `quran_sessions` (`org_id`, `timetable_slot_id`, `learned_on`);
ALTER TABLE `quran_sessions` ADD CONSTRAINT `fk_quran_timetable_period`
  FOREIGN KEY (`org_id`, `timetable_slot_id`) REFERENCES `class_timetable_slots` (`org_id`, `id`)
  ON DELETE RESTRICT ON UPDATE RESTRICT;
