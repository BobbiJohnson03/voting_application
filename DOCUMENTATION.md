# Secure Voting Application - Dokumentacja Techniczna

## 📋 Opis Projektu

Bezpieczny system głosowania offline dla organizacji (np. uczelni, spółdzielni). 
Administrator hostuje serwer na urządzeniu Android, a uczestnicy głosują przez przeglądarkę (PWA).

---

## 🏗️ Architektura Systemu

```
┌─────────────────────────────────────────────────────────────────┐
│                    TELEFON ADMINA (APK)                         │
│  ┌─────────────────┐    ┌─────────────────────────────────┐    │
│  │  Flutter App    │    │     Shelf HTTP Server           │    │
│  │  (Admin UI)     │───▶│     (port 8080)                 │    │
│  └─────────────────┘    │  ┌─────────────────────────┐    │    │
│                         │  │ REST API + WebSocket    │    │    │
│                         │  │ + Static PWA hosting    │    │    │
│                         │  └─────────────────────────┘    │    │
│                         └─────────────────────────────────┘    │
│                                       │                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Hive Database                         │   │
│  │  (meetings, votings, tickets, votes, audit_logs, ...)   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │ WiFi (LAN)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              TELEFONY UCZESTNIKÓW (PWA w przeglądarce)          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  Chrome     │  │  Chrome     │  │  Chrome     │   ...        │
│  │  PWA Client │  │  PWA Client │  │  PWA Client │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Struktura Folderów

```
lib/
├── main.dart                    # Punkt wejścia, inicjalizacja Hive
│
├── core/                        # Rdzeń aplikacji (współdzielony)
│   ├── network/
│   │   ├── api_network.dart     # Klient HTTP dla komunikacji z serwerem
│   │   └── ws_service.dart      # Klient WebSocket (live updates)
│   └── services/
│       ├── app_state_service.dart    # Globalny stan aplikacji
│       ├── device_fingerprint.dart   # 🔐 Identyfikacja urządzenia
│       ├── export_service.dart       # Eksport wyników (CSV, PDF)
│       └── server_service.dart       # Zarządzanie serwerem lokalnym
│
├── data/                        # Warstwa danych
│   ├── models/                  # Modele Hive (persystencja)
│   │   ├── meeting.dart         # Spotkanie/zebranie
│   │   ├── voting.dart          # Sesja głosowania
│   │   ├── question.dart        # Pytanie z opcjami
│   │   ├── option.dart          # Opcja odpowiedzi
│   │   ├── ticket.dart          # 🔐 Bilet uprawniający do głosowania
│   │   ├── secure_vote.dart     # 🔐 Głos z hash chain + HMAC
│   │   ├── signing_key.dart     # 🔐 Klucz podpisu sesji
│   │   ├── meeting_pass.dart    # 🔐 Przepustka do spotkania
│   │   ├── audit_log.dart       # 🔐 Log audytu z hash chain
│   │   ├── enums.dart           # Typy: VotingType, VotingStatus, etc.
│   │   └── user.dart            # Model użytkownika
│   ├── repositories/            # Dostęp do bazy Hive
│   │   ├── meeting_repository.dart
│   │   ├── voting_repository.dart
│   │   ├── vote_repository.dart      # 🔐 Walidacja duplikatów
│   │   ├── ticket_repository.dart    # 🔐 Zarządzanie biletami
│   │   └── ...
│   └── services/
│       ├── jwt_security.dart    # 🔐 Tokeny JWT
│       └── voting_ledger.dart   # 🔐 Weryfikacja hash chain
│
├── local_server/                # Serwer HTTP (Shelf) - TYLKO ADMIN
│   ├── admin_host_server.dart   # Główny serwer + routing
│   ├── logic_join_ticket.dart   # 🔐 Logika dołączania + wydawania biletów
│   ├── logic_vote.dart          # 🔐 Logika przyjmowania głosów
│   ├── logic_manifest.dart      # Pobieranie manifestu sesji
│   ├── logic_admin.dart         # Zamykanie sesji, wyniki
│   ├── broadcast_manager.dart   # WebSocket broadcast
│   ├── rate_limiter.dart        # 🔐 Ochrona przed atakami
│   └── auto_close_manager.dart  # Automatyczne zamykanie sesji
│
└── features/                    # Warstwy UI (strony)
    ├── app/pages/
    │   ├── landing_page.dart    # Ekran startowy
    │   └── qr_scanner_page.dart # Skanowanie QR / wpisywanie kodu
    ├── admin/pages/
    │   ├── admin_dashboard_page.dart  # Panel admina
    │   ├── create_session_page.dart   # Tworzenie sesji głosowania
    │   ├── sessions_list_page.dart    # Lista sesji
    │   └── session_results_page.dart  # Wyniki + eksport
    └── voting/
        ├── session_selection_page.dart # Wybór sesji (klient)
        └── voting_page.dart            # Ekran głosowania (klient)
```

---

## 🔐 Mechanizmy Bezpieczeństwa

### 1. Device Fingerprint (Identyfikacja Urządzenia)
**Plik:** `lib/core/services/device_fingerprint.dart`

```dart
// Generuje unikalny hash SHA-256 z informacji o urządzeniu
// Zapobiega udostępnianiu biletów między urządzeniami
fingerprint = SHA256(device_id + model + brand + timestamp)
```

**Gdzie używany:**
- `logic_join_ticket.dart` - przy dołączaniu do spotkania
- `logic_vote.dart` - przy oddawaniu głosu

---

### 2. Meeting Pass (Przepustka do Spotkania)
**Plik:** `lib/data/models/meeting_pass.dart`

- Jedno urządzenie = jedna przepustka na spotkanie
- Powiązana z device fingerprint
- Może być unieważniona (revoked)

---

### 3. Ticket System (System Biletów)
**Plik:** `lib/data/models/ticket.dart`

```dart
class Ticket {
  String id;
  String sessionId;
  String deviceFingerprint;  // 🔐 Powiązanie z urządzeniem
  bool isUsed;
  DateTime issuedAt;         // Ważność: 2 godziny
}
```

**Walidacja w** `logic_vote.dart`:
- ✅ Ticket istnieje i nie wygasł
- ✅ Ticket nie został użyty
- ✅ Device fingerprint zgadza się z biletem
- ✅ Ticket należy do właściwej sesji

---

### 4. Hash Chain (Łańcuch Głosów) - Blockchain-like
**Plik:** `lib/data/models/secure_vote.dart`

```dart
class SecureVote {
  String voteHash;           // SHA256 tego głosu
  String previousVoteHash;   // Hash poprzedniego głosu (chain)
  String signature;          // HMAC-SHA256 z kluczem sesji
  String nonce;              // Unikalny identyfikator
}

// Każdy głos zawiera hash poprzedniego - wykrywa manipulacje
vote1.hash ──▶ vote2.previousHash ──▶ vote3.previousHash ...
```

**Weryfikacja w** `logic_vote.dart` (linie 101-116):
```dart
// Przed zapisaniem nowego głosu:
if (!previousVote.isIntegrityValid) → ERROR
if (!previousVote.validateSignature(key)) → ERROR
```

---

### 5. HMAC Signatures (Podpisy Kryptograficzne)
**Plik:** `lib/data/models/secure_vote.dart`

```dart
// Każdy głos jest podpisany kluczem sesji
signature = HMAC-SHA256(sessionKey, voteHash)

// Weryfikacja przy zapisie
if (!vote.validateSignature(signingKey.secret)) → REJECT
```

---

### 6. Audit Logging (Dziennik Audytu)
**Plik:** `lib/data/models/audit_log.dart`

Każda akcja jest logowana z własnym hash chain:
- `meetingJoined` - dołączenie do spotkania
- `ticketIssued` - wydanie biletu
- `voteSubmitted` - oddanie głosu
- `votingClosed` - zamknięcie sesji
- `securityViolation` - próba naruszenia bezpieczeństwa

```dart
class AuditLog {
  AuditAction action;
  String userHash;       // Zanonimizowany fingerprint
  String previousHash;   // Chain integrity
  String hash;           // Self-verification
}
```

---

### 7. Rate Limiting (Ochrona przed Atakami)
**Plik:** `lib/local_server/rate_limiter.dart`

```dart
// Limity:
// - Ogólne: 30 requestów/minutę
// - Wrażliwe endpointy (/join, /ticket, /vote): 15 req/min
// - Po przekroczeniu: blokada IP na 5 minut
```

---

### 8. Input Sanitization (Walidacja Danych)
**Plik:** `lib/local_server/logic_join_ticket.dart`

```dart
// Walidacja formatu fingerprint (64 znaki hex = SHA-256)
bool _isValidFingerprint(String fp) {
  return fp.length == 64 && RegExp(r'^[a-f0-9]+$').hasMatch(fp);
}

// Sanityzacja wejścia (ochrona przed injection)
String _sanitizeInput(String input) {
  return input.replaceAll(RegExp(r'[<>"\x27;]'), '').trim();
}
```

---

## 🔄 Przepływ Głosowania

```
1. ADMIN tworzy Meeting + generuje Join Code (np. "ABC123")
              │
              ▼
2. KLIENT skanuje QR / wpisuje kod
              │
              ▼
3. /join ──▶ Walidacja fingerprint ──▶ Tworzenie MeetingPass
              │                              + Audit Log
              ▼
4. /ticket ──▶ Weryfikacja pass + fingerprint ──▶ Wydanie Ticket
              │                                      + Audit Log
              ▼
5. /vote ──▶ Walidacja: ticket, fingerprint, session, duplicate
              │
              ▼
6. Hash Chain: previousHash ──▶ computeHash ──▶ HMAC sign
              │
              ▼
7. Zapis głosu + Audit Log
              │
              ▼
8. WebSocket broadcast: "vote_received"
```

---

## 📊 Endpointy API

| Endpoint | Metoda | Opis | Zabezpieczenia |
|----------|--------|------|----------------|
| `/health` | GET | Status serwera | - |
| `/join` | POST | Dołączenie do spotkania | Fingerprint validation, Rate limit |
| `/ticket` | POST | Pobranie biletu | Pass + Fingerprint match |
| `/vote` | POST | Oddanie głosu | Ticket + Fingerprint + Hash chain |
| `/manifest` | GET | Pobierz pytania sesji | - |
| `/admin/results` | GET | Wyniki głosowania | - |
| `/admin/close` | POST | Zamknij sesję | - |
| `/admin/verify-chain` | GET | Weryfikuj integralność | - |
| `/admin/audit-logs` | GET | Pobierz logi audytu | - |
| `/ws` | WS | Live updates | - |

---

## 🛠️ Technologie

| Warstwa | Technologia |
|---------|-------------|
| Frontend | Flutter 3.38 (Dart) |
| Backend | Shelf (Dart HTTP server) |
| Database | Hive (NoSQL, lokalna) |
| Crypto | crypto (SHA-256, HMAC) |
| Auth | dart_jsonwebtoken (JWT) |
| QR | qr_flutter, mobile_scanner |
| Export | pdf, csv, share_plus |

---

## 🚀 Uruchomienie

```bash
# 1. Zbuduj PWA (dla klientów)
flutter build web --release

# 2. Skopiuj do assets
cp -r build/web/* assets/web/

# 3. Zbuduj APK (dla admina)
flutter build apk --release

# 4. Zainstaluj APK na telefonie admina
# 5. Klienci łączą się przez przeglądarkę: http://<IP_ADMINA>:8080
```

---

**Autor:** Luiza  
**Projekt:** Praca dyplomowa - Bezpieczny System Głosowania Offline
