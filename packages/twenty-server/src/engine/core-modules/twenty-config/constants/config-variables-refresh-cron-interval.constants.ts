// Each run reads every DB config variable in every server and worker process, which is costly egress on hosted Postgres
export const CONFIG_VARIABLES_REFRESH_CRON_INTERVAL = '0 */5 * * * *';
