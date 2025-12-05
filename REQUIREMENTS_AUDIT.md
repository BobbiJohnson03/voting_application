# Audyt Wymagań - Praca Inżynierska

## 📋 Temat Pracy
**Opracowanie aplikacji do przeprowadzania głosowań**

---

## ✅ Wymagania Funkcjonalne

### 1. Dostęp lokalny przez hotspot telefonu lub dedykowany router WiFi
| Status | Implementacja |
|--------|---------------|
| ✅ **Zaimplementowane** | `lib/core/services/server_service.dart` |

**Opis:** Serwer Shelf hostowany na telefonie Android, dostępny przez WiFi (hotspot lub router).
- Automatyczne wykrywanie IP: `_getLocalIpAddress()`
- Serwer nasłuchuje na `0.0.0.0:8080` (wszystkie interfejsy)
- Klienci łączą się przez przeglądarkę

---

### 2. Konfiguracja klientów za pomocą kodu QR
| Status | Implementacja |
|--------|---------------|
| ✅ **Zaimplementowane** | `lib/features/admin/pages/admin_dashboard_page.dart` |

**Opis:** Admin generuje QR kod zawierający URL serwera + kod dołączenia.
- Generowanie QR: `qr_flutter` package
- Skanowanie QR: `mobile_scanner` package (`qr_scanner_page.dart`)
- Alternatywnie: ręczne wpisanie kodu

---

### 3. Czasowe ograniczenia dostępu do głosowań
| Status | Implementacja |
|--------|---------------|
| ✅ **Zaimplementowane** | `lib/data/models/voting.dart`, `lib/local_server/auto_close_manager.dart` |

**Opis:** Każde głosowanie ma ustawiony czas trwania.
```dart
// voting.dart
@HiveField(7)
DateTime? endsAt;

@HiveField(12)
int durationMinutes; // Domyślnie 15 minut

bool get canVote => status == VotingStatus.open && 
    (endsAt == null || DateTime.now().isBefore(endsAt!));
```
- `AutoCloseManager` automatycznie zamyka głosowanie po upływie czasu

---

### 4. Konfigurowanie różnych rodzajów głosowań (tajne/jawne, wiele pytań)
| Status | Implementacja |
|--------|---------------|
| ✅ **Zaimplementowane** | `lib/data/models/enums.dart`, `lib/data/models/voting.dart` |

**Typy głosowania:**
```dart
enum VotingType {
  nonsecret,  // Jawne
  secret,     // Tajne
}

enum AnswersSchema {
  yesNo,          // Tak/Nie
  yesNoAbstain,   // Tak/Nie/Wstrzymuję się
  custom,         // Niestandardowe opcje
}
```

**Wiele pytań:** `List<String> questionIds` w modelu `Voting`

---

### 5. Zamykanie głosowania w dowolnej chwili lub automatycznie
| Status | Implementacja |
|--------|---------------|
| ✅ **Zaimplementowane** | `lib/local_server/logic_admin.dart`, `lib/local_server/auto_close_manager.dart` |

**Ręczne zamykanie:**
- Endpoint: `POST /admin/close`
- UI: `sessions_list_page.dart` - przycisk "Close"

**Automatyczne zamykanie:**
- `AutoCloseManager` sprawdza co 30 sekund czy `endsAt` minęło
- Automatycznie zmienia status na `closed`

---

### 6. Wyświetlanie wyników
| Status | Implementacja |
|--------|---------------|
| ✅ **Zaimplementowane** | `lib/features/admin/pages/session_results_page.dart` |

**Opis:** Po zamknięciu głosowania admin może zobaczyć wyniki.
- Endpoint: `GET /admin/results?sessionId=...`
- Wizualizacja: paski postępu, procenty, liczba głosów

---

### 7. Drukowanie i eksport wyników do archiwum
| Status | Implementacja |
|--------|---------------|
| ⚠️ **Częściowo** | `lib/core/services/export_service.dart`, `lib/core/services/print_service.dart` |

| Funkcja | Status |
|---------|--------|
| Eksport CSV | ✅ Działa |
| Eksport PDF | ✅ Działa |
| Drukowanie | ⚠️ Wyłączone (konflikt SDK) |
| Archiwizacja | ✅ Status `archived` |

**Uwaga:** Drukowanie wymaga pakietu `printing` który ma konflikt z Android SDK 35. Alternatywa: eksport do PDF i drukowanie z zewnętrznej aplikacji.

---

### 8. Administrowanie użytkownikami
| Status | Implementacja |
|--------|---------------|
| ✅ **Zaimplementowane** | `lib/features/admin/pages/user_management_page.dart` |

**Opis:** Strona zarządzania użytkownikami z rolami.
```dart
enum UserRole {
  participant,  // Uczestnik
  moderator,    // Moderator
  admin,        // Administrator
}
```

---

## ✅ Wymagania Niefunkcjonalne

### 1. Zapewnienie bezpieczeństwa głosowań
| Status | Implementacja |
|--------|---------------|
| ✅ **Zaimplementowane** | Wiele plików |

| Mechanizm | Plik | Opis |
|-----------|------|------|
| Device Fingerprint | `device_fingerprint.dart` | SHA-256 hash urządzenia |
| Ticket System | `ticket.dart`, `logic_join_ticket.dart` | Bilet powiązany z urządzeniem |
| Rate Limiting | `rate_limiter.dart` | Ochrona przed atakami |
| Input Validation | `logic_join_ticket.dart` | Sanityzacja danych wejściowych |
| Meeting Pass | `meeting_pass.dart` | Jedno urządzenie = jedna przepustka |

---

### 2. Zabezpieczenie integralności wyników
| Status | Implementacja |
|--------|---------------|
| ✅ **Zaimplementowane** | `lib/data/models/secure_vote.dart`, `lib/data/services/voting_ledger.dart` |

| Mechanizm | Opis |
|-----------|------|
| **Hash Chain** | Każdy głos zawiera hash poprzedniego |
| **HMAC Signatures** | Podpis HMAC-SHA256 dla każdego głosu |
| **Audit Logging** | Dziennik wszystkich akcji z hash chain |
| **Duplicate Prevention** | Indeks ticket+question zapobiega podwójnemu głosowaniu |
| **Verification Endpoint** | `GET /admin/verify-chain` - weryfikacja integralności |

```dart
// secure_vote.dart
class SecureVote {
  String voteHash;         // SHA256 tego głosu
  String previousVoteHash; // Hash poprzedniego (chain)
  String signature;        // HMAC-SHA256
}
```

---

### 3. Obsługa wielu platform sprzętowych (PWA)
| Status | Implementacja |
|--------|---------------|
| ✅ **Zaimplementowane** | `lib/local_server/static_assets_handler.dart` |

| Platforma | Rola | Status |
|-----------|------|--------|
| Android APK | Admin (serwer) | ✅ Działa |
| PWA (Chrome) | Klient (głosowanie) | ✅ Działa |
| iOS | Klient | ✅ Powinno działać |
| Desktop (Windows/Mac/Linux) | Dev/Testing | ✅ Działa |

---

## ✅ Stos Technologiczny

| Technologia | Wymagana | Używana | Status |
|-------------|----------|---------|--------|
| Flutter | ✅ | ✅ 3.38.3 | ✅ |
| Dart | ✅ | ✅ | ✅ |
| Backend lokalny | ✅ | Shelf (Dart) | ✅ |
| Baza danych | Hive | Hive | ✅ |
| Kody QR | qr_flutter | qr_flutter + mobile_scanner | ✅ |
| Autoryzacja | JWT | dart_jsonwebtoken | ✅ |

---

## 📊 Podsumowanie

| Kategoria | Zaimplementowane | Częściowe | Brakuje |
|-----------|------------------|-----------|---------|
| Wymagania funkcjonalne | 7/8 | 1/8 | 0/8 |
| Wymagania niefunkcjonalne | 3/3 | 0/3 | 0/3 |
| Stos technologiczny | 6/6 | 0/6 | 0/6 |

### ⚠️ Do naprawy/uzupełnienia:
1. **Drukowanie** - wymaga dodania pakietu `printing` z kompatybilną wersją SDK lub alternatywnego rozwiązania

---

## 🔐 Szczegóły Zabezpieczeń

### Przepływ bezpiecznego głosowania:
```
1. Klient dołącza → /join → Walidacja fingerprint → MeetingPass
2. Klient pobiera bilet → /ticket → Weryfikacja pass → Ticket
3. Klient głosuje → /vote → Walidacja: ticket, fingerprint, session
4. Głos zapisany → Hash chain → HMAC signature → Audit log
```

### Pliki bezpieczeństwa:
| Plik | Funkcja |
|------|---------|
| `device_fingerprint.dart` | Unikalna identyfikacja urządzenia |
| `ticket.dart` | Model biletu głosowania |
| `secure_vote.dart` | Głos z hash chain i podpisem |
| `audit_log.dart` | Dziennik audytu |
| `jwt_security.dart` | Tokeny sesji |
| `rate_limiter.dart` | Ochrona przed atakami |
| `logic_join_ticket.dart` | Walidacja dołączania |
| `logic_vote.dart` | Walidacja głosowania |

---

**Wersja:** 1.0.0  
**Data audytu:** 2025-12-05  
**Autor:** Luiza
