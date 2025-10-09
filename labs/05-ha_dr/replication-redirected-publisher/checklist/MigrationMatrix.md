# Matrix wpływu migracji replikacji (Publisher A → C)

Poniższa tabela podsumowuje wpływ migracji na agenty i komponenty replikacji w zależności od modelu subskrypcji **PUSH**/**PULL**.

| Agent / komponent | Gdzie działa | Co robi | Wariant PUSH – wpływ | Wariant PULL – wpływ |
|---|---|---|---|---|
| **Log Reader Agent** | Publisher (A → C) | Zczytuje transakcje z loga i zapisuje je do `distribution` | **Zawsze** przenoszony z bazą. Po restore na C `KEEP_REPLICATION` zachowuje metadane; trzeba zapewnić agenta/loginy na C. | Identycznie – agent żyje przy Publisherze, więc po migracji zawsze jest na C. |
| **Distribution Agent** | Dystrybutor (A) **/ Subskrybent (B)** | Wysyła zmiany z `distribution` do B | Krytyczny: działa na A. Po przeniesieniu Publishera na C nadal działa (A jako zdalny dystrybutor). **Po migracji dystrybutora na C – rekreacja jobów** (`sp_addpushsubscription_agent`). | Działa na **B**, więc migracja Publishera/Dystrybutora ma minimalny wpływ; B sam ciągnie dane. |
| **Snapshot Agent** | Dystrybutor (A) | Tworzy snapshoty (schemat + dane początkowe) | Bez zmian, dopóki dystrybutor na A. Po przeniesieniu dystrybutora na C – **rekreacja joba** (`sp_addpublication_snapshot`). | Jak w PUSH, ale używany rzadko po inicjalizacji. |
| **Baza `distribution`** | Dystrybutor (A → C) | Metadane i pending commands | Po cutoverze Publishera zostaje na A i działa. **Po przeniesieniu na C – pełna rekonstrukcja** (`sp_adddistributor`, `sp_adddistributiondb`, `sp_adddistpublisher`). | Tak samo, ale mniejsze ryzyko (agenty dystrybucji po stronie B). |
| **Joby SQL Agenta (replikacyjne)** | Dystrybutor (A) | Harmonogramy agentów | Do odtworzenia na C (export ustawień → rekreacja). | Nie dotyczy (joby lokalne na B). |
| **Subskrypcje (`MSsubscriptions`)** | Dystrybutor (A) | Metadane subskrypcji | Po przeniesieniu Publishera na C pozostają aktywne, jeśli ustawiono `sp_redirect_publisher`. Po migracji dystrybutora na C – trzeba odtworzyć lub zaktualizować metadane (skrypty w repo). | Bez zmian – subskrybent utrzymuje metadane lokalnie. |
| **Loginy agentów (`repl_*`)** | Dystrybutor / Publisher | Autoryzacja agentów | Wymagane przeniesienie z SID (`16_compare_login_sids.sql`, `17_generate_login_script_from_A.sql`). | Dotyczy tylko dystrybutora; w PULL subskrybent używa własnego konta. |

---

## Jak sprawdzić typ subskrypcji i agenty

Uruchom na **dystrybutorze (A)**:

```sql
-- Typ subskrypcji (0=Push, 1=Pull, 2=Anon)
SELECT 
    s.subscription_type,
    CASE s.subscription_type 
        WHEN 0 THEN 'Push'
        WHEN 1 THEN 'Pull'
        WHEN 2 THEN 'Anonymous'
        ELSE 'Other' END AS subscription_model,
    p.publication, s.subscriber_db, s.subscriber_id
FROM distribution.dbo.MSsubscriptions s
JOIN distribution.dbo.MSpublications p ON s.publication_id = p.publication_id;
```

```sql
-- Agenty dystrybucji (push) i ich joby
SELECT a.name AS dist_agent_name, a.publisher_db, a.subscriber_name, a.subscriber_db, j.name AS job_name
FROM distribution.dbo.MSdistribution_agents a
LEFT JOIN msdb.dbo.sysjobs j ON j.job_id = a.job_id;
```

```sql
-- Log Reader (gdzie żyje)
EXEC sp_help_logreader_agent;
```

---

## Rekomendacje operacyjne

- **PUSH:** wykonaj migrację dwuetapowo: sobota – Publisher A→C (dystrybutor zostaje na A), niedziela – Dystrybutor A→C.  
- **PULL:** możesz zrobić pełny cutover w jednym oknie – po redirectcie B będzie sam pobierał z C.

Szczegóły wykonawcze, checklisty, skrypty T‑SQL i PowerShell znajdziesz w tym repo (`sql/`, `sql_dist_migration/`, `scripts/`).

> W razie rollbacku: `sp_redirect_publisher` wskazuje ponownie A, start agentów na A i ruch wraca do poprzedniego toru.
