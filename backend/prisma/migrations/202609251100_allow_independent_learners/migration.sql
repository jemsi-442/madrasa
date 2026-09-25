-- Adult course learners can register without a guardian or a supplied gender.
ALTER TABLE `students`
  MODIFY `gender` VARCHAR(20) NULL,
  MODIFY `primary_guardian_id` BIGINT NULL;
