SELECT  
  [Counter_Name] = RTRIM(counter_name), 
   [Value] = cntr_value, 
   [Unit] = CASE  
       WHEN counter_name LIKE '%Ratio%' THEN '%' 
       WHEN counter_name LIKE '%Expectancy%' THEN 'Seconds' 
       ELSE 'Count' 
   END, 
   [Description] = CASE  
       WHEN counter_name = 'Buffer cache hit ratio' THEN 'Procent stron odczytanych z RAM bez sięgania do dysku (Cel: >99%)' 
       WHEN counter_name = 'Page life expectancy' THEN 'Czas przebywania strony w pamięci. Im wyższy, tym lepiej.' 
       WHEN counter_name = 'Checkpoint pages/sec' THEN 'Liczba stron zapisywanych na dysk podczas punktu kontrolnego.' 
       WHEN counter_name = 'Lazy writes/sec' THEN 'Jeśli > 0, system ma problem z ilością wolnej pamięci RAM!' 
       ELSE '' 
   END 
FROM sys.dm_os_performance_counters 
WHERE (object_name LIKE '%Buffer Manager%' OR object_name LIKE '%Memory Manager%') 
 AND counter_name IN ( 
   'Buffer cache hit ratio',  
   'Buffer cache hit ratio base',  
   'Page life expectancy',  
   'Lazy writes/sec',  
   'Checkpoint pages/sec', 
   'Memory Grants Pending' 
 ); 
 

 