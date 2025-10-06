# Fiszki — SPID < 50 (do nauki)

**SPID 2 — Lazy Writer**  
Rola: zwalnia pamięć w Buffer Pool (dirty → MDF).  
Gdzie patrzeć: DMV (command=LAZY WRITER), PerfMon Lazy Writes/sec.

**SPID 3 — Checkpoint**  
Rola: flush dirty pages, skraca recovery.  
Gdzie patrzeć: DMV (command=CHECKPOINT), XE checkpoint_*.

**SPID 4 — Resource Monitor**  
Rola: nadzór pamięci SQL/OS, sygnały presji.  
Gdzie patrzeć: DMV, XE resource_monitor (wersjo‑zależne).

**SPID 5 — Log Writer**  
Rola: flush log buffer → .ldf (WRITELOG).  
Gdzie patrzeć: DMV (command=LOG WRITER), PerfMon Log Flushes/sec.

**SPID 7 — Ghost Cleanup**  
Rola: usuwa ghost records z B‑Tree (po DELETE/UPDATE).  
Gdzie patrzeć: DMV (chwilowy), PerfMon Ghost Cleanup tasks/sec.

**DAC (11)**  
Rola: awaryjne połączenie admina.  
Gdzie patrzeć: aktywne tylko przy `ADMIN:servername`.
