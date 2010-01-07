-- TO RUN AS SJG

GRANT ALL ON spv TO sjg;
GRANT SELECT on groups TO sjg;
GRANT SELECT on objects TO sjg;
GRANT SELECT on objects_group TO sjg;
GRANT SELECT on checks_group TO sjg;
GRANT SELECT on checks TO sjg;
GRANT SELECT on status TO sjg;
GRANT SELECT on status_infos TO sjg;

CREATE OR REPLACE VIEW sjg.sjg_machine_spv AS SELECT check.sinfo_id as mspv_id, sjg_machine.mac_id, plugin || '-' || plugin_check as mspv_category, key as mspv_key, value as mspv_value, status_infos.modification_date AS sys_modif_date, status_infos.creation_date AS sys_creat_date FROM spv.checks JOIN spv.checks_group ON (checks.chk_id=checks_group.chk_id) JOIN spv.groups ON (checks_group.grp_id=groups.grp_id)  JOIN spv.objects_group ON (groups.grp_id=objects_group.grp_id) NATURAL JOIN spv.objects JOIN sjg.sjg_machine ON (objects.address=sjg.sjg_machine.mac_hostname) JOIN spv.status ON (status.og_id=objects_group.og_id AND status.cg_id=checks_group.cg_id) JOIN spv.status_infos ON (status_infos.status_id=status.status_id) WHERE groups.name='rxtxs';
