-- Protect monetary and event invariants even for non-HTTP database writes.
ALTER TABLE fundraising_campaigns ADD CONSTRAINT chk_campaign_goal CHECK (goal_amount > 0 AND currency = 'TZS');
ALTER TABLE donation_pledges ADD CONSTRAINT chk_pledge_amount CHECK (amount > 0 AND currency = 'TZS');
ALTER TABLE donations ADD CONSTRAINT chk_donation_amount CHECK (amount > 0 AND currency = 'TZS');
ALTER TABLE donations ADD CONSTRAINT chk_donation_void CHECK (
  (status = 'RECEIVED' AND voided_at IS NULL AND void_reason IS NULL)
  OR (status = 'VOIDED' AND voided_at IS NOT NULL AND void_reason IS NOT NULL)
);
ALTER TABLE foundation_events ADD CONSTRAINT chk_event_dates CHECK (ends_at > starts_at);
