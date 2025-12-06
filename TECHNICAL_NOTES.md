# 📘 Notatki Techniczne - Aplikacja do Głosowania

## Spis treści
1. [Architektura aplikacji](#architektura-aplikacji)
2. [Stos technologiczny](#stos-technologiczny)
3. [Bezpieczeństwo (Security)](#bezpieczeństwo-security)
4. [Flow działania aplikacji](#flow-działania-aplikacji)
5. [Struktura plików](#struktura-plików)
6. [Kluczowe algorytmy](#kluczowe-algorytmy)

---

## Architektura aplikacji

### Model klient-serwer w jednej aplikacji

```
┌─────────────────────────────────────────────────────────────┐
│                    APLIKACJA FLUTTER                         │
│                                                              │
│  ┌──────────────────┐         ┌──────────────────────────┐  │
│  │   TRYB ADMIN     │         │      TRYB KLIENT         │  │
│  │                  │         │                          │  │
│  │  • Uruchamia     │  HTTP   │  • Łączy się przez       │  │
│  │    lokalny       │◄───────►│    przeglądarkę (Web)    │  │
│  │    serwer Shelf  │         │    lub aplikację         │  │
│  │  • Zarządza      │         │  • Skanuje QR            │  │
│  │    głosowaniami  │         │  • Oddaje głosy          │  │
│  └──────────────────┘         └──────────────────────────┘  │
│           │                                                  │
│           ▼                                                  │
│  ┌──────────────────┐                                       │
│  │   HIVE DATABASE  │  ← Lokalna baza NoSQL                 │
│  │   (Local NoSQL)  │                                       │
│  └──────────────────┘                                       │
└─────────────────────────────────────────────────────────────┘
```

### Dlaczego taka architektura?
- **Offline-first** - nie wymaga połączenia z internetem
- **Prywatność** - dane zostają na urządzeniu admina
- **Prostota** - brak potrzeby zewnętrznego serwera
- **Mobilność** - admin może prowadzić głosowania gdziekolwiek

---

## Stos technologiczny

### Flutter (Dart)
- **Co to**: Framework do budowania aplikacji wieloplatformowych
- **Dlaczego**: Jeden kod → Android, iOS, Web, Desktop
- **Wersja**: Flutter 3.x, Dart 3.x

### Shelf (Serwer HTTP)
- **Co to**: Lekki serwer HTTP napisany w Dart
- **Plik**: `lib/local_server/admin_host_server.dart`
- **Dlaczego Shelf a nie Express/Flask**:
  - Natywny dla Dart - brak potrzeby oddzielnego backendu
  - Lekki (~50KB) - idealny do embedded server
  - Middleware support - rate limiting, CORS, logging
  
```dart
// Przykład routera Shelf
final router = Router()
  ..post('/join', logicJoinTicket.joinMeeting)
  ..post('/vote', logicVote.submitVote)
  ..get('/admin/results', logicAdmin.results);
```

### Hive (Baza danych)
- **Co to**: Lekka baza NoSQL dla Dart/Flutter
- **Plik**: `lib/data/_boxes.dart` (nazwy boxów)
- **Dlaczego Hive a nie SQLite**:
  - Szybsza dla prostych operacji
  - Natywna serializacja obiektów Dart
  - Brak potrzeby pisania SQL
  - Działa na wszystkich platformach (w tym Web)

```dart
// Modele z adapterami Hive
@HiveType(typeId: 5)
class Voting extends HiveObject {
  @HiveField(0)
  final String id;
  // ...
}
```

### Inne kluczowe pakiety
| Pakiet | Zastosowanie | Plik użycia |
|--------|--------------|-------------|
| `crypto` | SHA256, HMAC | `lib/data/models/audit_log.dart` |
| `qr_flutter` | Generowanie QR | `lib/features/admin/pages/admin_dashboard_page.dart` |
| `mobile_scanner` | Skanowanie QR | `lib/features/app/pages/qr_scanner_page.dart` |
| `pdf` | Eksport PDF | `lib/core/services/export_service.dart` |
| `csv` | Eksport CSV | `lib/core/services/export_service.dart` |
| `share_plus` | Udostępnianie plików | `lib/core/services/export_service.dart` |

---

## Bezpieczeństwo (Security)

### 1. Device Fingerprint (Identyfikacja urządzenia)

**Plik**: `lib/core/services/device_fingerprint.dart`

**Co to**: Unikalny hash identyfikujący urządzenie uczestnika

**Jak działa**:
```dart
static Future<String> generate() async {
  // Zbiera dane o urządzeniu:
  // - User Agent (przeglądarka)
  // - Rozdzielczość ekranu
  // - Platforma
  // - Język systemu
  // - Strefa czasowa
  
  final data = '$userAgent|$screenRes|$platform|$language|$timezone';
  return sha256.convert(utf8.encode(data)).toString();
}
```

**Kiedy używany**:
- Przy dołączaniu do meetingu (`/join`)
- Przy głosowaniu (`/vote`)
- Zapobiega wielokrotnemu głosowaniu z tego samego urządzenia

---

### 2. Hash Chain (Łańcuch hashów - Audit Log)

**Plik**: `lib/data/models/audit_log.dart`

**Co to**: Każdy log audytu zawiera hash poprzedniego logu, tworząc łańcuch

**Struktura**:
```dart
class AuditLog {
  final String id;
  final AuditAction action;      // np. voteSubmitted, sessionCreated
  final String sessionId;
  final DateTime timestamp;
  final String userHash;         // Fingerprint głosującego
  String previousHash;           // Hash poprzedniego logu
  String hash;                   // Hash tego logu
  final String details;
  String meetingId;
}
```

**Obliczanie hasha**:
```dart
String computeHash() {
  final data = '$id${action.name}$sessionId${timestamp.millisecondsSinceEpoch}'
               '$userHash$previousHash$meetingId$details';
  return sha256.convert(utf8.encode(data)).toString();
}
```

**Kiedy tworzony**:
| Akcja | Plik | Metoda |
|-------|------|--------|
| Utworzenie sesji | `logic_vote.dart` | `_logSessionCreated()` |
| Dołączenie do meetingu | `logic_join_ticket.dart` | `_logMeetingJoined()` |
| Wydanie biletu | `logic_join_ticket.dart` | `_logTicketIssued()` |
| Oddanie głosu | `logic_vote.dart` | `_logVoteSubmitted()` |
| Zamknięcie głosowania | `logic_admin.dart` | `_logVotingClosed()` |

**Weryfikacja integralności**:
```dart
bool get isChainValid {
  final computed = computeHash();
  return computed == hash;  // Porównanie obliczonego z zapisanym
}
```

**Wizualizacja**: `lib/features/admin/pages/security_panel_page.dart`

---

### 3. HMAC Signature (Podpis głosu)

**Plik**: `lib/data/models/secure_vote.dart`

**Co to**: Każdy głos jest podpisany kluczem HMAC-SHA256

**Struktura głosu**:
```dart
class SecureVote {
  final String id;
  final String ticketId;
  final String sessionId;
  final String questionId;
  final List<String> selectedOptionIds;
  final DateTime timestamp;
  final String deviceFingerprint;
  String signature;              // HMAC podpis
}
```

**Generowanie podpisu**:
```dart
String computeSignature(String secretKey) {
  final data = '$ticketId$sessionId$questionId'
               '${selectedOptionIds.join(",")}$deviceFingerprint';
  final hmac = Hmac(sha256, utf8.encode(secretKey));
  return hmac.convert(utf8.encode(data)).toString();
}
```

**Klucz podpisu**:
- **Plik**: `lib/data/repositories/signing_key_repository.dart`
- Generowany automatycznie per sesja głosowania
- Przechowywany lokalnie w Hive

---

### 4. Rate Limiting (Ograniczanie żądań)

**Plik**: `lib/local_server/rate_limiter.dart`

**Co to**: Ochrona przed atakami DDoS i nadmiernym obciążeniem

**Konfiguracja**:
```dart
final config = RateLimitConfig(
  maxRequests: 200,           // Max żądań w oknie
  windowDuration: Duration(minutes: 1),
  cleanupInterval: Duration(minutes: 5),
);
```

**Identyfikacja klienta**: 
- User-Agent + Accept-Language + fingerprint z ciasteczka
- Fallback: generowany UUID dla nowych klientów

---

### 5. Ticket System (Bilety głosowania)

**Plik**: `lib/data/models/ticket.dart`

**Co to**: Jednorazowy bilet uprawniający do głosowania

**Flow**:
```
1. Klient dołącza → otrzymuje MeetingPass
2. Klient wybiera sesję → żąda Ticket
3. Ticket jest jednorazowy per sesja
4. Po głosowaniu ticket.isUsed = true
```

**Walidacja przy głosowaniu** (`logic_vote.dart`):
```dart
// Sprawdzenia przed akceptacją głosu:
if (ticket == null) return error('Invalid ticket');
if (ticket.isUsed) return error('Ticket already used');
if (ticket.sessionId != sessionId) return error('Wrong session');
if (!voting.canVote) return error('Voting closed');
```

---

### 6. Diagram bezpieczeństwa - pełny flow

```
KLIENT                           SERWER                         BAZA DANYCH
  │                                │                                │
  │─── 1. /join ──────────────────►│                                │
  │    {meetingCode, fingerprint}  │                                │
  │                                │─── Sprawdź meeting ───────────►│
  │                                │◄── Meeting exists ─────────────│
  │                                │─── Utwórz MeetingPass ────────►│
  │                                │─── LOG: meetingJoined ────────►│
  │◄── {passId, meetingId} ────────│                                │
  │                                │                                │
  │─── 2. /ticket ────────────────►│                                │
  │    {passId, sessionId}         │                                │
  │                                │─── Waliduj pass ──────────────►│
  │                                │─── Sprawdź czy nie ma biletu ─►│
  │                                │─── Utwórz Ticket ─────────────►│
  │                                │─── LOG: ticketIssued ─────────►│
  │◄── {ticketId} ─────────────────│                                │
  │                                │                                │
  │─── 3. /vote ──────────────────►│                                │
  │    {ticketId, questionId,      │                                │
  │     selectedOptions,           │                                │
  │     fingerprint}               │                                │
  │                                │─── Waliduj ticket ────────────►│
  │                                │─── Sprawdź fingerprint ───────►│
  │                                │─── Sprawdź czy voting open ───►│
  │                                │─── Utwórz SecureVote + HMAC ──►│
  │                                │─── Oznacz ticket jako użyty ──►│
  │                                │─── LOG: voteSubmitted ────────►│
  │◄── {success: true} ────────────│       (z hash chain)           │
```

---

## Flow działania aplikacji

### A. Flow Admina

```
1. Uruchomienie aplikacji
   └── LandingPage sprawdza czy jest zapisana sesja
   
2. Wybór trybu Admin
   └── AdminDashboardPage
       └── _startServer() → ServerService.start()
           └── Uruchamia Shelf server na porcie 8080
           └── Uruchamia AutoCloseManager (timer głosowań)
   
3. Tworzenie meetingu
   └── _createMeeting() → MeetingRepository.put()
   └── Generuje joinCode (6 znaków)
   
4. Tworzenie sesji głosowania
   └── CreateSessionPage
       └── Dodaje pytania i opcje
       └── Ustawia typ (secret/nonsecret)
       └── Ustawia czas trwania
       └── VotingRepository.put()
   
5. Udostępnianie QR
   └── QR zawiera: http://{localIP}:8080?code={joinCode}
   
6. Monitoring
   └── LiveStatsPanel - statystyki real-time
   └── SecurityPanel - wizualizacja hash chain
   
7. Zamknięcie głosowania
   └── Ręczne LUB automatyczne (AutoCloseManager)
   └── voting.close() → status = closed
   
8. Przeglądanie wyników
   └── ResultsPage → /admin/results
   └── Eksport CSV/PDF
```

### B. Flow Klienta (Web)

```
1. Skanowanie QR lub wpisanie kodu
   └── URL: http://{ip}:8080?code={joinCode}
   
2. Dołączenie do meetingu
   └── /join → MeetingPass
   └── Zapisanie sesji w localStorage
   
3. Lista dostępnych głosowań
   └── SessionSelectionPage
   └── /sessions?meetingId={id}
   
4. Wybór głosowania
   └── /ticket → Ticket
   └── /manifest?sessionId={id} → pytania i opcje
   
5. Głosowanie
   └── VotingPage
   └── Radio (single) lub Checkbox (multi)
   └── /vote → zapisanie głosu
   
6. Potwierdzenie
   └── Dialog "Vote submitted"
   └── Powrót do listy sesji
```

---

## Struktura plików

```
lib/
├── main.dart                      # Entry point
│
├── core/                          # Warstwa rdzeniowa
│   ├── network/
│   │   └── api_network.dart       # Klient HTTP do komunikacji z serwerem
│   └── services/
│       ├── server_service.dart    # Zarządzanie serwerem Shelf
│       ├── device_fingerprint.dart # Generowanie fingerprint
│       ├── export_service.dart    # Eksport CSV/PDF
│       └── print_service.dart     # [DISABLED] Drukowanie
│
├── data/                          # Warstwa danych
│   ├── models/                    # Modele danych (Hive)
│   │   ├── meeting.dart           # Spotkanie
│   │   ├── voting.dart            # Sesja głosowania
│   │   ├── question.dart          # Pytanie + opcje
│   │   ├── ticket.dart            # Bilet głosowania
│   │   ├── meeting_pass.dart      # Przepustka do meetingu
│   │   ├── secure_vote.dart       # Głos z podpisem HMAC
│   │   ├── audit_log.dart         # Log audytu (hash chain)
│   │   └── enums.dart             # VotingType, VotingStatus, etc.
│   │
│   └── repositories/              # Repozytoria (CRUD)
│       ├── meeting_repository.dart
│       ├── voting_repository.dart
│       ├── question_repository.dart
│       ├── ticket_repository.dart
│       ├── vote_repository.dart
│       ├── audit_log_repository.dart
│       └── signing_key_repository.dart
│
├── local_server/                  # Serwer Shelf
│   ├── admin_host_server.dart     # Główny serwer + router
│   ├── logic_join_ticket.dart     # /join, /ticket, /sessions
│   ├── logic_vote.dart            # /vote
│   ├── logic_admin.dart           # /admin/results, /admin/close
│   ├── logic_manifest.dart        # /manifest
│   ├── rate_limiter.dart          # Middleware rate limiting
│   ├── broadcast_manager.dart     # WebSocket broadcast
│   └── auto_close_manager.dart    # Timer automatycznego zamykania
│
└── features/                      # UI (strony)
    ├── app/pages/
    │   ├── landing_page.dart      # Strona główna
    │   └── qr_scanner_page.dart   # Skanowanie QR
    │
    ├── admin/pages/
    │   ├── admin_dashboard_page.dart  # Panel admina
    │   ├── sessions_list_page.dart    # Lista sesji
    │   ├── create_session_page.dart   # Tworzenie sesji
    │   ├── session_results_page.dart  # Wyniki głosowania
    │   ├── security_panel_page.dart   # Panel bezpieczeństwa
    │   └── archive_page.dart          # Archiwum
    │
    └── voting/
        ├── session_selection_page.dart # Lista głosowań (klient)
        └── voting_page.dart            # Strona głosowania
```

---

## Kluczowe algorytmy

### 1. Automatyczne zamykanie głosowania

**Plik**: `lib/local_server/auto_close_manager.dart`

```dart
void _checkAndCloseExpired() async {
  final allMeetings = await meetings.getAll();
  
  for (final meeting in allMeetings) {
    final votings = await this.votings.forMeeting(meeting.id);
    
    for (final voting in votings) {
      // Sprawdź czy głosowanie wygasło
      if (voting.canVote &&                           // Jest otwarte
          voting.endsAt != null &&                    // Ma ustawiony czas końca
          DateTime.now().isAfter(voting.endsAt!)) {   // Czas minął
        
        voting.close();  // Zamknij głosowanie
        
        // Powiadom klientów przez WebSocket
        broadcast.send(meeting.id, {
          'type': 'voting_closed',
          'sessionId': voting.id,
        });
      }
    }
  }
}
```

### 2. Weryfikacja integralności łańcucha

**Plik**: `lib/features/admin/pages/security_panel_page.dart`

```dart
Future<void> _loadAndVerify() async {
  final logs = await auditLogs.getAll();
  logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  
  int validLogs = 0;
  List<String> errors = [];
  
  for (var i = 0; i < logs.length; i++) {
    final log = logs[i];
    
    // 1. Sprawdź hash samego logu
    if (log.isChainValid) {
      validLogs++;
    } else {
      errors.add('Log ${i + 1}: Hash integrity failed');
    }
    
    // 2. Sprawdź połączenie z poprzednim logiem
    if (i > 0 && log.previousHash != logs[i - 1].hash) {
      errors.add('Log ${i + 1}: Chain link broken');
    }
  }
  
  _chainVerified = errors.isEmpty && validLogs == logs.length;
}
```

### 3. Obliczanie wyników głosowania

**Plik**: `lib/local_server/logic_admin.dart`

```dart
Future<Map<String, dynamic>> _calculateResults(List<SecureVote> votes) async {
  // Struktura: { questionId: { optionId: count } }
  final Map<String, Map<String, int>> tallies = {};
  
  for (final vote in votes) {
    final questionTallies = tallies.putIfAbsent(
      vote.questionId,
      () => <String, int>{},
    );
    
    // Obsługa wielokrotnego wyboru
    for (final optionId in vote.selectedOptionIds) {
      questionTallies[optionId] = (questionTallies[optionId] ?? 0) + 1;
    }
  }
  
  return tallies;
}
```

---

## Potencjalne pytania promotora i odpowiedzi

### Q: Dlaczego Shelf a nie Firebase/Express/Django?
**A**: Shelf pozwala na embedded server w aplikacji Flutter, co daje:
- Działanie offline (brak zależności od internetu)
- Prywatność danych (wszystko lokalnie)
- Prostotę deploymentu (jedna aplikacja)

### Q: Jak zapewniasz anonimowość głosowania?
**A**: W trybie `secret`:
- Głos przechowuje tylko `ticketId`, nie dane użytkownika
- `deviceFingerprint` służy tylko do weryfikacji unikalności
- Hash chain nie zawiera danych personalnych

### Q: Co jeśli admin zmodyfikuje bazę danych?
**A**: Hash chain to wykryje:
- Każdy log ma hash poprzedniego
- Modyfikacja jednego logu psuje cały łańcuch
- Security Panel wizualizuje integralność

### Q: Jak chronisz przed wielokrotnym głosowaniem?
**A**: Trzy warstwy:
1. **Ticket** - jednorazowy, oznaczany jako `isUsed`
2. **Device Fingerprint** - jeden głos per urządzenie per sesja
3. **MeetingPass** - jeden pass per device per meeting

### Q: Czy aplikacja jest skalowalna?
**A**: Obecna architektura jest dla ~35-50 osób (sala wykładowa). Dla większej skali potrzebna byłaby migracja na:
- Centralny serwer (np. AWS/GCP)
- Baza PostgreSQL zamiast Hive
- Load balancing

---

*Ostatnia aktualizacja: 5 grudnia 2025*
