ALTER TABLE attendance_records
  ADD COLUMN check_in_time VARCHAR(5) NULL,
  ADD COLUMN version INTEGER NOT NULL DEFAULT 1,
  ADD CONSTRAINT chk_attendance_version CHECK (version >= 1),
  ADD CONSTRAINT chk_attendance_check_in CHECK (
    check_in_time IS NULL OR (
      check_in_time REGEXP '^([01][0-9]|2[0-3]):[0-5][0-9]$'
      AND status IN ('PRESENT', 'LATE')
    )
  );
