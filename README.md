# Asso Asso

Un gioco di carte digitale multiplayer costruito con Flutter e PocketBase.

- [Asso Asso](#asso-asso)
  - [Panoramica](#panoramica)
  - [Caratteristiche](#caratteristiche)
  - [Regole del Gioco](#regole-del-gioco)
    - [Obiettivo](#obiettivo)
    - [Le Scale](#le-scale)
    - [I Jolly](#i-jolly)
    - [Struttura del Turno](#struttura-del-turno)
    - [Gestione della Mano](#gestione-della-mano)
  - [Tecnologie](#tecnologie)
  - [Struttura del Progetto](#struttura-del-progetto)
  - [Requisiti](#requisiti)
  - [Configurazione Backend](#configurazione-backend)
  - [Licenza](#licenza)


## Panoramica

Asso Asso è un gioco di carte per 2-4 giocatori, disponibile su dispositivi Android e iOS. I giocatori competono per completare per primi delle **sequenze complete (scale)** di 14 carte consecutive dello stesso seme, utilizzando carte tradizionali e jolly.

## Caratteristiche

- **Modalità multiplayer**: Gioca in tempo reale con altri giocatori
- **Supporto multiplayer**:
  - 1 vs 1 (duello)
  - 2 vs 2 (a squadre)
  - 3 o 4 giocatori singoli
- **Timer personalizzabile**: Ogni giocatore ha un timer configurabile per ogni mossa
- **Sincronizzazione in tempo reale**: Backend PocketBase per la gestione delle partite
- **Interfaccia responsive**: Ottimizzato per dispositivi mobili in orientamento orizzontale

## Regole del Gioco

### Obiettivo

Completare per primi il numero richiesto di **scale complete** (14 carte consecutive dello stesso seme).

### Le Scale

Una scala completa è formata da **14 carte consecutive dello stesso seme**, in ordine:
- **Crescente**: A, 2, 3, 4, 5, 6, 7, 8, 9, 10, J, Q, K, A
- **Decrescente**: A, K, Q, J, 10, 9, 8, 7, 6, 5, 4, 3, 2, A

### I Jolly

I jolly possono sostituire qualsiasi carta all'interno di una sequenza. Durante il proprio turno, un giocatore può:
- Attaccare uno o più jolly alle sequenze
- Sostituire qualsiasi jolly presente in qualsiasi sequenza (anche degli avversari)
- Recuperare i propri jolly se pescati le carte corrette

### Struttura del Turno

Durante il proprio turno, un giocatore può:
1. Attaccare carte alle sequenze (senza limiti)
2. Sostituire jolly
3. Pescare una carta dal mazzo coperto
4. Pescare la prima carta dal mazzo degli scarti

### Gestione della Mano

- Ogni giocatore deve terminare il turno con **6 carte in mano**
- Se attacca almeno una carta, deve pescare fino a **7 carte** e può continuare ad attaccare
- Se termina con 7 carte e non può/vuole attaccare, è obbligato a scartare

Per le regole complete, consulta il file `assets/attachments/rules.md`.

## Tecnologie

- **Frontend**: Flutter (Dart)
- **Backend**: PocketBase (database e sincronizzazione real-time)
- **Stato**: ValueNotifier per la gestione reattiva dello stato
- **Animazioni**: Flutter Animation framework

## Struttura del Progetto

```
lib/
├── controllers/          # Logica di gioco e gestione mazzo
│   ├── deck_controller.dart
│   └── game_controller.dart
├── core/                # Configurazioni globali
│   ├── app_globals.dart
│   ├── app_router.dart
│   └── formatters.dart
├── screens/             # Schermate dell'applicazione
│   ├── endgame_screen.dart
│   ├── game_screen.dart
│   ├── home_screen.dart
│   ├── lobby_screen.dart
│   ├── profile_screen.dart
│   ├── rules_screen.dart
│   ├── settings_screen.dart
│   └── splash_screen.dart
├── services/            # Servizi esterni
│   ├── game_session_service.dart
│   ├── pocketbase_service.dart
│   └── shared_preferences_service.dart
├── widgets/             # Componenti UI riutilizzabili
│   ├── page_transitions/
│   │   └── custom_page_transition.dart
│   ├── painters/
│   │   └── border_line_timer_painter.dart
│   ├── action_button.dart
│   ├── animated_card.dart
│   ├── bold_button.dart
│   ├── dialogs.dart
│   ├── settings_tile.dart
│   ├── tappable_card.dart
│   └── universal_safearea.dart
└── main.dart            # Entry point dell'applicazione
```

## Requisiti

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- PocketBase (per il backend locale o remoto)

## Configurazione Backend

L'app si connette a un'istanza PocketBase. Per configurarla, modifica il file `lib/services/pocketbase_service.dart` con l'URL del tuo server PocketBase.

## Licenza

Progetto privato - Tutti i diritti riservati
