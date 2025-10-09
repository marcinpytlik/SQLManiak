@{
  PublisherA     = 'ServerA'           # stary Publisher (i Dystrybutor na czas cutoveru)
  NewPublisherC  = 'ServerC'           # nowy Publisher
  SubscriberB    = 'ServerB'           # subskrybent
  PublisherDb    = 'TwojaBaza'         # nazwa bazy po stronie Publishera
  SubscriberDb   = 'TwojaBazaB'        # docelowa nazwa bazy po stronie subskrybenta
  Publication    = 'PubName'           # nazwa publikacji
  BackupShareA   = r'\\ServerA\Backups' # gdzie na A lądują backupy
  BackupShareC   = r'\\ServerC\Backups' # gdzie na C przywracasz (może to być ten sam UNC)
  SnapshotDirC   = r'D:\ReplShare'     # working_directory dystrybutora na C
  UseSqlAuth     = $false              # $false = Windows Auth; $true = SQL Auth
  SqlUser        = ''                  # jeśli UseSqlAuth = $true
  SqlPassword    = ''                  # jeśli UseSqlAuth = $true (rozważ bezpieczne przechowywanie w SecretStore)
  DistributionDb = 'distribution'
}
