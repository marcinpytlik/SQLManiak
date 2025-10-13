/*
  Raport latency (ostatnie 24h)
*/
USE msdb;
SELECT TOP 200
  log_time, publication, subscriber,
  overall_latency_ms,
  publisher_latency_ms, distributor_latency_ms, subscriber_latency_ms,
  status_desc
FROM dbo.ReplLatencyLog
WHERE log_time >= DATEADD(hour, -24, SYSDATETIME())
ORDER BY log_time DESC;
