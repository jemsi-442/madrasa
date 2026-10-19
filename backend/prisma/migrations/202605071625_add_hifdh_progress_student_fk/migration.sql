-- Keep the follow-up safe when the parent migration already added this key.
SET @hifdh_student_fk_exists = (
  SELECT COUNT(*)
  FROM information_schema.REFERENTIAL_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA = DATABASE()
    AND CONSTRAINT_NAME = 'hifdh_progress_student_id_fkey'
);

SET @hifdh_student_fk_sql = IF(
  @hifdh_student_fk_exists > 0,
  'SELECT 1',
  'ALTER TABLE `hifdh_progress` ADD CONSTRAINT `hifdh_progress_student_id_fkey` FOREIGN KEY (`student_id`) REFERENCES `students` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE'
);

PREPARE hifdh_student_fk_statement FROM @hifdh_student_fk_sql;
EXECUTE hifdh_student_fk_statement;
DEALLOCATE PREPARE hifdh_student_fk_statement;
