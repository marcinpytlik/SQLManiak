# 🧾 SQL Server 2022 – Konta serwisowe: Domenowe vs gMSA

## ✅ Kiedy użyć konta **domenowego**
- [ ] Środowisko **lab/test** – szybkość i prostota > bezpieczeństwo.  
- [ ] Potrzebujesz logowania interaktywnego (np. do diagnostyki).  
- [ ] Brak wsparcia AD dla gMSA (stara domena, brak Windows Server 2012+).  
- [ ] Usługi wymagają współdzielenia jednego konta między różne serwery (np. dev/test farmy).  
- [ ] Nie masz jeszcze wypracowanej polityki gMSA w organizacji.  

## ✅ Kiedy użyć **gMSA**
- [ ] Środowisko **produkcyjne**, gdzie liczy się bezpieczeństwo i ciągłość działania.  
- [ ] DBA nie chce się martwić o rotację haseł (gMSA zmienia automatycznie).  
- [ ] Audyt/bezpieczeństwo wymaga, by hasła nie były znane administratorom.  
- [ ] Chcesz ograniczyć użycie konta tylko do wybranych serwerów (PrincipalsAllowedToRetrieveManagedPassword).  
- [ ] Serwer działa w farmie/klastrze – gMSA obsługuje scenariusze wielu hostów.  

## ❌ Czego unikać
- Nie używaj **konta lokalnego** do SQL Server – brak integracji z AD, brak delegacji Kerberos.  
- Nie używaj **konta `sa`/sysadmina** jako loginu do usług – to droga na skróty.  

---

### 📌 Szybka reguła
- **DEV/LAB** → konto domenowe.  
- **PROD** → gMSA.  
