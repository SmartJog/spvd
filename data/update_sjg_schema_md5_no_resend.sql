-- upu_private_id contains the stream id use by rbc
ALTER TABLE sjg_uplink_use ADD COLUMN upu_private_id integer;
-- Each stream id is unique
ALTER TABLE sjg_uplink_use ADD CONSTRAINT UPU_PRIVATE_UNIQ UNIQUE (upu_private_id);

-- det_transfert_status is the status for metadata setting :
--      - Waiting : delivery ready for metadata setting
--      - Complete : metadata are setted
--      - Processing : file not found on target server, the delivery has to be restarted
ALTER TABLE sjg_delivery_transfer ADD COLUMN det_transfer_status varchar(16);

ALTER TABLE sjg_delivery_transfer ALTER COLUMN det_transfer_status SET DEFAULT 'Processing';

-- Index define to increase the time average for select file on Waiting status
CREATE INDEX sjg_delivery_det_transfer_status_idx ON sjg_delivery_transfer (det_transfer_status);
