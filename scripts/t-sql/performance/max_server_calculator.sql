SET NOCOUNT ON; 
 
DECLARE @PhysicalMemoryMB INT; 
DECLARE @RecommendedMaxMemoryMB INT; 
DECLARE @CurrentMaxMemoryMB INT; 
 
-- 1. Pobranie całkowitej pamięci fizycznej serwera 
SELECT @PhysicalMemoryMB = cast(total_physical_memory_kb / 1024.0 as int) 
FROM sys.dm_os_sys_memory; 
 
-- 2. Pobranie obecnej konfiguracji 
SELECT @CurrentMaxMemoryMB = cast(value_in_use as int) 
FROM sys.configurations 
WHERE name = 'max server memory (MB)'; 
 
-- 3. Logika obliczeń (Best Practice): 
-- Rezerwujemy dla OS: 
-- 1 GB na każde 4 GB RAM (do 16 GB) 
-- 1 GB na każde 8 GB RAM (powyżej 16 GB) 
 
DECLARE @ReservedForOS INT; 
 
IF @PhysicalMemoryMB <= 16384 
   SET @ReservedForOS = (@PhysicalMemoryMB / 4); 
ELSE 
   SET @ReservedForOS = 4096 + ((@PhysicalMemoryMB - 16384) / 8); 
 
-- Upewniamy się, że rezerwacja dla OS to minimum 2GB i max 32GB (dla ekstremalnych maszyn) 
IF @ReservedForOS < 2048 SET @ReservedForOS = 2048; 
 
SET @RecommendedMaxMemoryMB = @PhysicalMemoryMB - @ReservedForOS; 
 
-- 4. Wyświetlenie wyników 
SELECT  
   @PhysicalMemoryMB AS [Total_Physical_RAM_MB], 
   @CurrentMaxMemoryMB AS [Current_Max_Server_Memory_MB], 
   @RecommendedMaxMemoryMB AS [Recommended_Max_Server_Memory_MB], 
   @ReservedForOS AS [RAM_Reserved_for_OS_and_Others_MB], 
   CASE  
       WHEN @CurrentMaxMemoryMB > @RecommendedMaxMemoryMB THEN 'UWAGA: Masz ustawione za dużo pamięci! Ryzyko niestabilności OS.' 
       WHEN @CurrentMaxMemoryMB = 2147483647 THEN 'UWAGA: Max Memory ustawione na domyślne (bez limitu)! Koniecznie ogranicz.' 
       ELSE 'Status: OK' 
   END AS [Diagnosis]; 
 
-- 5. Generowanie gotowego polecenia do wdrożenia 
PRINT '-- Aby zastosować rekomendację, wykonaj poniższy kod:'; 
PRINT '/*'; 
PRINT 'EXEC sys.sp_configure N''show advanced options'', N''1'';'; 
PRINT 'RECONFIGURE;'; 
PRINT 'EXEC sys.sp_configure N''max server memory (MB)'', N''' + CAST(@RecommendedMaxMemoryMB AS VARCHAR) + ''';'; 
PRINT 'RECONFIGURE;'; 
PRINT '*/'; 
 