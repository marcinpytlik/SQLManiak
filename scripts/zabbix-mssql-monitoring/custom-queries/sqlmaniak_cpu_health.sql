SET NOCOUNT ON;

;WITH sched AS
(
    SELECT
        COUNT(*) AS active_schedulers,
        SUM(runnable_tasks_count) AS runnable_tasks_total,
        CAST(1.0 * SUM(runnable_tasks_count) / NULLIF(COUNT(*), 0) AS decimal(18,4)) AS runnable_tasks_per_active_scheduler,
        SUM(current_tasks_count) AS current_tasks_total,
        SUM(active_workers_count) AS active_workers_total,
        SUM(work_queue_count) AS work_queue_total
    FROM sys.dm_os_schedulers
    WHERE status = N'VISIBLE ONLINE'
      AND scheduler_id < 1048576
),
waits AS
(
    SELECT
        COALESCE(SUM(waiting_tasks_count), 0) AS sos_waiting_tasks_count,
        COALESCE(SUM(wait_time_ms), 0) AS sos_wait_time_ms,
        COALESCE(SUM(signal_wait_time_ms), 0) AS sos_signal_wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE wait_type = N'SOS_SCHEDULER_YIELD'
)
SELECT
    osi.cpu_count AS host_logical_cpu_count,
    osi.scheduler_count AS configured_scheduler_count,
    s.active_schedulers AS sql_visible_online_schedulers,
    s.active_schedulers,
    s.runnable_tasks_total,
    s.runnable_tasks_per_active_scheduler,
    s.current_tasks_total,
    s.active_workers_total,
    s.work_queue_total,
    w.sos_waiting_tasks_count,
    w.sos_wait_time_ms,
    w.sos_signal_wait_time_ms,
    COALESCE(rb.sql_process_cpu_pct_host, 0) AS sql_process_cpu_pct_host,
    COALESCE(rb.system_idle_pct, 0) AS system_idle_pct,
    COALESCE(rb.other_processes_cpu_pct, 0) AS other_processes_cpu_pct
FROM sys.dm_os_sys_info AS osi
CROSS JOIN sched AS s
CROSS JOIN waits AS w
OUTER APPLY
(
    SELECT TOP (1)
        x.record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS sql_process_cpu_pct_host,
        x.record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS system_idle_pct,
        100
          - x.record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int')
          - x.record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS other_processes_cpu_pct
    FROM sys.dm_os_ring_buffers AS r
    CROSS APPLY (SELECT TRY_CONVERT(xml, r.record) AS record) AS x
    WHERE r.ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
      AND r.record LIKE N'%<SystemHealth>%'
    ORDER BY r.[timestamp] DESC
) AS rb;
