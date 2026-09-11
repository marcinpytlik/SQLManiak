# DBA_Operations v3 — model bez `db_owner` dla developerów

## Cel

`DBA_Operations v3` zastępuje bezpośrednie nadawanie developerom szerokich uprawnień (`db_owner`, `db_ddladmin`, `db_securityadmin`) kontrolowanym interfejsem opartym o:

- jedną grupę Active Directory: `SQLLAB\Developer`,
- standardowe prawa do danych: `db_datareader` i `db_datawriter`,
- własną rolę `db_executor` z `EXECUTE ON SCHEMA::dbo`,
- centralną bazę `DBA_Operations`,
- procedury-wrappery,
- module signing przy użyciu oddzielnych certyfikatów funkcjonalnych,
- whitelistę baz zarządzanych,
- pełny audyt operacji.

## Architektura

```text
Active Directory
└── SQLLAB\Developer
    ├── SQLLAB\heniek
    ├── SQLLAB\zenek
    └── ...

             │ Windows token
             ▼

SQL Server
├── baza1
│   ├── SQLLAB\Developer -> db_datareader
│   ├── SQLLAB\Developer -> db_datawriter
│   └── SQLLAB\Developer -> db_executor
├── baza2
│   ├── SQLLAB\Developer -> db_datareader
│   ├── SQLLAB\Developer -> db_datawriter
│   └── SQLLAB\Developer -> db_executor
│
└── DBA_Operations
    ├── DBA_DeveloperDdlOperator
    ├── DBA_DeveloperSecurityOperator
    ├── DBA_DeveloperBackupOperator (opcjonalnie)
    │
    └── ops.*
        ├── DDL wrappers
        ├── Database Security wrappers
        ├── Backup wrapper
        └── Audit
```

Developer **nie otrzymuje `db_owner`**.

## Zasada least privilege

Bezpośrednio w bazie aplikacyjnej grupa `SQLLAB\Developer` ma:

```text
db_datareader
db_datawriter
db_executor
```

`db_executor` jest własną rolą bazodanową tworzoną w każdej onboardowanej bazie:

```sql
CREATE ROLE [db_executor] AUTHORIZATION [dbo];

GRANT EXECUTE
ON SCHEMA::[dbo]
TO [db_executor];

ALTER ROLE [db_executor]
ADD MEMBER [SQLLAB\Developer];
```

Dzięki temu developer może wykonywać procedury/funkcje wykonywalne w schemacie `dbo`, również utworzone później, bez otrzymywania `db_owner`.

Nie ma:

```text
db_owner
db_ddladmin
db_securityadmin
db_accessadmin
sysadmin
securityadmin
dbcreator
```

W konsekwencji developer może normalnie wykonywać:

```sql
SELECT
INSERT
UPDATE
DELETE
EXEC dbo.usp_...
```

ale bezpośrednie:

```sql
CREATE TABLE
ALTER TABLE
DROP TABLE
CREATE USER
ALTER ROLE
```

powinno zakończyć się odmową.

Operacje te są wykonywane wyłącznie przez `DBA_Operations`.

---

## Dlaczego jedna grupa AD

SQL Server posiada tylko jeden login:

```text
SQLLAB\Developer
```

Nie trzeba tworzyć osobnego loginu SQL Server dla każdego developera.

### Nowy developer

Administrator AD dodaje użytkownika:

```text
SQLLAB\marcin
        ↓
SQLLAB\Developer
```

Po stronie SQL Server nie trzeba wykonywać żadnej zmiany.

### Developer odchodzi

Wystarczy usunąć go z:

```text
SQLLAB\Developer
```

Nie trzeba szukać jego użytkowników w kilkudziesięciu bazach.

Jednocześnie audyt `DBA_Operations` używa `ORIGINAL_LOGIN()`, więc operacje nadal są przypisywane do konkretnego konta Windows, np.:

```text
SQLLAB\heniek
SQLLAB\zenek
```

a nie wyłącznie do nazwy grupy.

---


## Rola `db_executor`

`db_executor` nie jest wbudowaną rolą SQL Server. Jest tworzona przez administratora osobno w każdej onboardowanej bazie.

```sql
CREATE ROLE [db_executor] AUTHORIZATION [dbo];

GRANT EXECUTE
ON SCHEMA::[dbo]
TO [db_executor];

ALTER ROLE [db_executor]
ADD MEMBER [SQLLAB\Developer];
```

Zakres:

```text
EXECUTE ON SCHEMA::dbo
```

oznacza, że członkowie roli mogą wykonywać wszystkie obiekty wykonywalne w schemacie `dbo`, do których stosuje się `EXECUTE`, w tym nowe procedury utworzone w przyszłości.

`db_executor` **nie jest** dodawany do `DBA_Operations.dbo.AllowedDatabaseRole`. Developer nie może więc sam przyznawać tej roli innym użytkownikom przez wrapper security. Członkostwo w `db_executor` pozostaje decyzją DBA podczas onboardingu bazy.

# Certyfikaty funkcjonalne

Wersja v3 nie używa jednego certyfikatu z `CONTROL SERVER`.

Zastosowane są trzy oddzielne certyfikaty.

## `DBAOps_DdlCert`

Służy wyłącznie do operacji DDL.

W zarządzanej bazie użytkownik utworzony z tego certyfikatu dostaje:

```sql
GRANT ALTER ON SCHEMA::dbo
GRANT CREATE TABLE
GRANT CREATE VIEW
GRANT CREATE PROCEDURE
```

Nie dostaje uprawnień security ani backup.

## `DBAOps_SecurityCert`

Służy do zarządzania użytkownikami bazodanowymi.

Otrzymuje:

```sql
GRANT ALTER ANY USER
GRANT ALTER ON ROLE::db_datareader
GRANT ALTER ON ROLE::db_datawriter
```

Nie otrzymuje:

```text
ALTER ANY ROLE
db_securityadmin
db_owner
```

Dlatego wrapper może dodawać użytkowników wyłącznie do zatwierdzonych ról.

## `DBAOps_BackupCert`

Jest opcjonalny.

Jeżeli DBA zdecyduje, że developerzy mogą wykonywać backup konkretnej bazy, certyfikatowy user jest dodawany do:

```text
db_backupoperator
```

Backup jest dodatkowo kontrolowany przez:

```text
ManagedDatabase.AllowBackup
```

oraz członkostwo grupy w:

```text
DBA_DeveloperBackupOperator
```

Domyślnie rekomendowane jest pozostawienie backupu wyłączonego dla developerów.

---

# ManagedDatabase

Centralną whitelistą jest:

```text
DBA_Operations.dbo.ManagedDatabase
```

Przykład:

| DatabaseName | AllowDdl | AllowSecurity | AllowBackup | IsEnabled |
|---|---:|---:|---:|---:|
| baza | 1 | 1 | 0 | 1 |
| baza2 | 1 | 0 | 0 | 1 |

Dzięki temu sama obecność użytkownika w `SQLLAB\Developer` nie wystarcza do wykonania operacji w dowolnej bazie.

Baza musi zostać świadomie onboardowana przez DBA.

---

# Dostępne operacje DDL

## CREATE TABLE

```sql
EXEC DBA_Operations.ops.usp_CreateTable
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @TableName=N'CustomerDemo',
    @ColumnsJson=N'
    [
      {"name":"Id","type":"int","nullable":false,"identity":true},
      {"name":"Name","type":"nvarchar","length":200,"nullable":false},
      {"name":"Email","type":"nvarchar","length":320,"nullable":true}
    ]';
```

Definicje kolumn są przekazywane jako JSON i walidowane.

Developer nie przekazuje całego polecenia `CREATE TABLE`.

## ADD COLUMN

```sql
EXEC DBA_Operations.ops.usp_AddColumn
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @TableName=N'CustomerDemo',
    @ColumnName=N'IsActive',
    @DataType=N'bit',
    @Nullable=1;
```

## DROP COLUMN

```sql
EXEC DBA_Operations.ops.usp_DropColumn
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @TableName=N'CustomerDemo',
    @ColumnName=N'IsActive';
```

## DROP TABLE

```sql
EXEC DBA_Operations.ops.usp_DropTable
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @TableName=N'CustomerDemo';
```

---

# Widoki

## CREATE OR ALTER VIEW

```sql
EXEC DBA_Operations.ops.usp_CreateOrAlterView
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @ViewName=N'vCustomerDemo',
    @SelectBody=N'
        SELECT Id, Name, Email
        FROM dbo.CustomerDemo
    ';
```

Wrapper akceptuje pojedynczą definicję `SELECT` / `WITH`.

Blokowane są m.in. tokeny pozwalające łatwo dołączyć kolejne polecenie.

## DROP VIEW

```sql
EXEC DBA_Operations.ops.usp_DropView
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @ViewName=N'vCustomerDemo';
```

---

# Procedury składowane

## CREATE OR ALTER PROCEDURE

Parametry są definiowane w JSON.

```sql
EXEC DBA_Operations.ops.usp_CreateOrAlterProcedure
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @ProcedureName=N'usp_CustomerDemo_Get',
    @ParametersJson=N'
    [
      {"name":"@Id","type":"int","output":false}
    ]',
    @Body=N'
        SELECT Id, Name, Email
        FROM dbo.CustomerDemo
        WHERE Id = @Id;
    ';
```

Wrapper sam tworzy nagłówek procedury.

Developer nie może ustawić:

```text
EXECUTE AS
```

w definicji wrappera.

Nowo utworzona procedura **nie jest podpisywana certyfikatem DBA_Operations**. Certyfikat służy wyłącznie do wykonania operacji `CREATE/ALTER PROCEDURE`.

To ważna granica bezpieczeństwa: utworzony moduł nie dziedziczy uprzywilejowania wrappera.

## DROP PROCEDURE

```sql
EXEC DBA_Operations.ops.usp_DropProcedure
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @ProcedureName=N'usp_CustomerDemo_Get';
```

---

# Zarządzanie użytkownikami

Developer nie tworzy loginów serwerowych.

Login musi już istnieć, np. jako konto lub grupa AD.

## CREATE USER

```sql
EXEC DBA_Operations.ops.usp_CreateDatabaseUser
    @DatabaseName=N'baza',
    @LoginName=N'SQLLAB\zenek',
    @UserName=N'SQLLAB\zenek';
```

Jeżeli login nie istnieje na poziomie instancji, wrapper odrzuci operację.

## Dodanie do `db_datareader`

```sql
EXEC DBA_Operations.ops.usp_AddUserToDatabaseRole
    @DatabaseName=N'baza',
    @UserName=N'SQLLAB\zenek',
    @RoleName=N'db_datareader';
```

## Dodanie do `db_datawriter`

```sql
EXEC DBA_Operations.ops.usp_AddUserToDatabaseRole
    @DatabaseName=N'baza',
    @UserName=N'SQLLAB\zenek',
    @RoleName=N'db_datawriter';
```

Lista ról pochodzi z:

```text
dbo.AllowedDatabaseRole
```

Domyślnie znajdują się tam tylko:

```text
db_datareader
db_datawriter
```

Próba:

```text
db_owner
db_securityadmin
db_ddladmin
```

zostanie odrzucona.

---

# Backup

Backup jest opcjonalny.

Wymaga jednocześnie:

1. `AllowBackup = 1` dla bazy,
2. członkostwa `SQLLAB\Developer` w `DBA_DeveloperBackupOperator`,
3. certyfikatu `DBAOps_BackupCert` w bazie,
4. użytkownika z certyfikatu w `db_backupoperator`.

Wywołanie:

```sql
EXEC DBA_Operations.ops.usp_BackupDatabase
    @DatabaseName=N'baza';
```

Backup jest wykonywany jako:

```text
COPY_ONLY
CHECKSUM
COMPRESSION
```

i trafia wyłącznie do skonfigurowanego `BackupRoot`.

---

# Restore

Restore **nie jest częścią developerskiego v3**.

To świadoma decyzja.

Restore może:

- nadpisać całą bazę,
- zerwać aktywne połączenia,
- przywrócić stare uprawnienia,
- zmienić zawartość i schemat całego systemu,
- wymaga specjalnych praw serwerowych.

Dlatego restore powinien pozostać operacją DBA lub być zrealizowany jako osobny, mocno ograniczony workflow.

---

# Audyt

Każdy wrapper zapisuje:

```text
czas
ORIGINAL_LOGIN()
login sesji
operację
bazę
obiekt
wynik
numer błędu
komunikat błędu
HOST_NAME()
APP_NAME()
```

Developer może zobaczyć swoje operacje:

```sql
EXEC DBA_Operations.ops.usp_MyOperationAudit
    @Top=100;
```

DBA może używać:

```sql
EXEC DBA_Operations.ops.usp_AllOperationAudit
    @Top=1000;
```

---

# Onboarding nowej bazy

Administrator wykonuje dla nowej bazy:

1. dodaje wpis do `DBA_Operations.dbo.ManagedDatabase`,
2. tworzy usera `SQLLAB\Developer`,
3. dodaje grupę do `db_datareader`,
4. dodaje grupę do `db_datawriter`,
5. tworzy `db_executor`,
6. nadaje `db_executor` `EXECUTE ON SCHEMA::dbo`,
7. dodaje `SQLLAB\Developer` do `db_executor`,
8. importuje publiczny `DBAOps_DdlCert`,
9. tworzy `DBAOps_DdlCertUser`,
10. nadaje minimalne prawa DDL,
11. opcjonalnie instaluje `DBAOps_SecurityCert`,
12. opcjonalnie instaluje `DBAOps_BackupCert`.

Po tym żadna konfiguracja poszczególnych developerów w SQL Server nie jest potrzebna.

---

# Onboarding developera

```text
Active Directory
```

Dodaj konto do:

```text
SQLLAB\Developer
```

Koniec konfiguracji.

---

# Offboarding developera

Usuń konto z:

```text
SQLLAB\Developer
```

Po odświeżeniu tokenu Kerberos / ponownym logowaniu użytkownik traci prawa wynikające z grupy.

---

# Zasady bezpieczeństwa

## Nie tworzyć ogólnego `usp_ExecuteSql`

Niedozwolony wzorzec:

```sql
EXEC ops.usp_ExecuteSql
    @Sql=N'dowolny kod';
```

Taki wrapper zniszczyłby granicę bezpieczeństwa.

Każda operacja musi mieć własny, kontrolowany interfejs.

## Nie używać `TRUSTWORTHY ON`

`DBA_Operations` działa z:

```text
TRUSTWORTHY OFF
```

Podwyższenie uprawnień realizuje module signing.

## Nie dawać developerowi certyfikatu prywatnego

W bazach aplikacyjnych znajduje się wyłącznie publiczna część certyfikatu.

Klucz prywatny pozostaje w `DBA_Operations`.

## Po `ALTER PROCEDURE` podpisać wrapper ponownie

Zmiana podpisanego modułu usuwa jego podpis.

Po zmianie wrappera trzeba ponownie wykonać:

```sql
ADD SIGNATURE TO OBJECT::ops.<procedure>
BY CERTIFICATE [odpowiedni_cert];
```

---

# Pliki rozwiązania

## 1. `DBA_Operations_v3_FULL_Deployment.sql`

Tworzy cały centralny mechanizm.

Uruchamiany przez DBA jako `sysadmin`.

## 2. `DBA_Operations_v3_Admin_Config_and_Developer_Usage.sql`

Pokazuje:

- konfigurację `SQLLAB\Developer`,
- onboarding bazy `baza`,
- konfigurację publicznych certyfikatów,
- minimalne granty,
- wszystkie przykłady operacji developera,
- testy negatywne.

## 3. `DBA_Operations_v3_Architecture.md`

Opisuje architekturę, bezpieczeństwo i model operacyjny.

---

# Docelowy rezultat

Przed:

```text
Developer -> db_owner -> praktycznie pełna kontrola nad bazą
```

Po:

```text
Developer
   │
   ├── db_datareader
   ├── db_datawriter
   ├── db_executor
   │      └── EXECUTE ON SCHEMA::dbo
   │
   └── DBA_Operations wrappers
          │
          ├── DDL certificate
          ├── Security certificate
          └── optional Backup certificate
```

Developer dostaje dokładnie te operacje, których potrzebuje, ale nie dostaje ogólnego prawa do administracji bazą.
