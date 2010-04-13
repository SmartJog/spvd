ALTER TABLE spv.checks ADD COLUMN repeat_on_error integer;
UPDATE spv.checks SET repeat_on_error=repeat;
ALTER TABLE spv.checks ALTER COLUMN repeat_on_error SET NOT NULL;
ALTER TABLE spv.checks
	DROP CONSTRAINT strictly_positive_time,
	ADD CONSTRAINT strictly_positive_time CHECK (repeat > 0 AND repeat_on_error > 0);
