# SQL Server 2016 ➜ 2022 – Full Migration Pack

Ten pakiet obejmuje **komplet**: loginy/użytkownicy, credentials, proxies, linked servers, operators, Agent Jobs.
Przygotowane do uruchamiania w **VS Code**. Wymagane uprawnienia: `sysadmin` na obu serwerach.

## Kolejność działań (rekomendowana)

**Na SQL 2016 (źródło)**:
1. `scripts/Generate_Logins_2016.sql` – skopiuj wynik (CREATE LOGIN … WITH PASSWORD = 0x… HASHED, SID, itp.).
2. `scripts/Generate_Credentials_2016.sql` – skopiuj wynik.
3. `scripts/Generate_Proxies_2016.sql` – skopiuj wynik.
4. `scripts/Generate_LinkedServers_2016.sql` – skopiuj wynik.
5. `scripts/Generate_Operators_2016.sql` – jeśli używasz operatorów.
6. `scripts/Generate_AgentJobs_2016.sql` – skopiuj wynik.

**Na SQL 2022 (cel)**:
1. Wklej i uruchom wynik z `Generate_Logins_2016.sql` (utworzy loginy z SID/hashem).
2. Przywróć bazy danych.
3. Uruchom `scripts/Fix_Orphaned_Users_AllDB.sql` – naprawi mapowanie USERS ➜ LOGINS w każdej bazie.
4. Wklej i uruchom:
   - `CREATE CREDENTIAL …` (uzupełnij **SECRET**),
   - Proxies,
   - Linked Servers (uzupełnij hasła w `sp_addlinkedsrvlogin` gdzie `useself=FALSE`),
   - Operators (opcjonalnie),
   - Agent Jobs (rekomendacja: tworzyć **wyłączone**, przetestować, włączyć).
5. (Opcjonalnie) `scripts/Apply_Jobs_Safety_Note.sql` – checklista.

## Ważne uwagi
- **Hasła (SECRET) w Credentials oraz hasła do `sp_addlinkedsrvlogin` nie są eksportowalne** – uzupełnij ręcznie.
- Jeśli na 2022 masz inną kolację/ustawienia, sprawdź kroki jobów i bazę domyślną loginów.
- Database Mail / Operatorzy: upewnij się, że profil mailowy istnieje przed odtwarzaniem powiadomień jobów.
- Jeśli korzystasz z `EXECUTE AS LOGIN` lub podpisów certyfikatem, to osobna ścieżka – daj znać, dorzucę skrypty.

## Walidacja po migracji
- Liczba loginów (bez systemowych) powinna się zgadzać.
- `SELECT * FROM sys.servers WHERE is_linked=1` – porównaj listę linked servers.
- `SELECT COUNT(*) FROM msdb.dbo.sysjobs` – porównaj liczbę jobów; przetestuj kluczowe joby ręcznie.
- W każdej bazie: `SELECT dp.name, sp.name FROM sys.database_principals dp LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid WHERE dp.type IN ('S','U')` – brak osieroconych.
