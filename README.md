# benutzer-anlegen

Bash-Skripte, die Linux-Benutzer aus einer Liste anlegen und wieder entfernen. Jeder Benutzer bekommt ein Startpasswort, gespeichert als SHA-512-Hash, und muss es bei der ersten Anmeldung ändern.

## Die Skripte

| Skript | Aufgabe |
|---|---|
| `benutzer-anlegen.sh` | legt jeden Namen aus der Liste an: Heimatverzeichnis, Shell `/bin/bash`, Startpasswort, Passwortwechsel bei der ersten Anmeldung. Vorhandene Konten bleiben unverändert. |
| `benutzer-entfernen.sh` | entfernt die Benutzer der Liste samt Heimatverzeichnis. Fragt vorher nach und lässt Systemkonten (UID unter 1000) in Ruhe. |
| `pwhash.sh` | gibt den SHA-512-Hash eines Passworts aus, also das Format, das `useradd -p` erwartet. |

## Voraussetzungen

- Linux mit `bash`, `useradd`, `userdel`, `chage` und `openssl`
- root-Rechte (`sudo`)

## Schnellstart

```bash
git clone https://github.com/alxrbon89-cmyk/benutzer-anlegen.git
cd benutzer-anlegen
sudo ./benutzer-anlegen.sh beispiel/benutzer.txt
```

Das Skript fragt nach dem Startpasswort. Die Eingabe bleibt unsichtbar und landet nicht in der Shell-Historie.

Wieder entfernen:

```bash
sudo ./benutzer-entfernen.sh beispiel/benutzer.txt
```

## Format der Liste

Ein Benutzername pro Zeile. Leerzeilen und Zeilen, die mit `#` beginnen, werden übersprungen. Leerzeichen am Anfang und Ende einer Zeile stören nicht.

```text
# Beispiel
nutzer01
nutzer02
nutzer03
```

## Warum ein Hash?

`useradd -p` schreibt den Wert unverändert in das Passwortfeld von `/etc/shadow`. Bei der Anmeldung berechnet Linux aus dem eingegebenen Passwort einen Hash und vergleicht ihn mit diesem Feld. Steht dort das Passwort im Klartext, passt der Vergleich nie, und die Anmeldung scheitert.

`pwhash.sh` erzeugt deshalb mit `openssl passwd -6` einen SHA-512-Hash im Format `$6$SALT$HASH`. Das Salt ist zufällig. Zwei Benutzer mit demselben Startpasswort haben deshalb verschiedene Einträge in `/etc/shadow`.

## Sicherheit und Grenzen

- **Gemeinsames Startpasswort:** Alle Benutzer einer Liste bekommen dasselbe Startpasswort. `chage -d 0` zwingt jeden, es bei der ersten Anmeldung zu ändern.
- **Prozessliste:** Während der Hash berechnet wird, steht das Passwort für einen Moment als Argument von `openssl` in der Prozessliste. Auf einem Mehrbenutzersystem könnte ein anderer Benutzer es dort sehen.
- **SHA-512 statt yescrypt:** Ubuntu 24.04 und Debian 12 verwenden für neue Passwörter yescrypt (`$y$`). `openssl` kann kein yescrypt. SHA-512 (`$6$`) wird von der Anmeldung (PAM) weiterhin angenommen. Ändert der Benutzer sein Passwort, speichert das System es wieder im Standardverfahren.
- **Benutzernamen:** Die Skripte prüfen die Namen nicht selbst. `useradd` lehnt ungültige Namen ab. Das Skript meldet sie und endet mit Exit-Code 1.

## Exit-Codes

| Code | Bedeutung |
|---|---|
| 0 | alles erledigt; übersprungene Konten zählen nicht als Fehler |
| 1 | falscher Aufruf, keine root-Rechte, kein Passwort oder mindestens ein Benutzer ließ sich nicht anlegen bzw. entfernen |

## Tests

```bash
sudo ./tests/test.sh
```

Der Test legt die Benutzer `testnutzer1` und `testnutzer2` an und löscht sie danach wieder. **Nur auf einer Übungs-VM oder in einem Wegwerf-Container ausführen.** Gibt es einen der beiden Namen schon, bricht er ab, ohne etwas zu ändern.

Geprüft werden:
- Heimatverzeichnis, Shell und Hash-Format
- ob das Passwort zum Hash passt
- der erzwungene Passwortwechsel und ein eigenes Salt je Benutzer
- dass ein zweiter Lauf nichts verändert
- dass ungültige Namen gemeldet werden und ein Lauf ohne Passwort abbricht
- dass das Entfernen funktioniert und Systemkonten stehen bleiben

## Aufbau

```text
benutzer-anlegen/
├── benutzer-anlegen.sh     Benutzer aus einer Liste anlegen
├── benutzer-entfernen.sh   Benutzer aus einer Liste entfernen
├── pwhash.sh               SHA-512-Hash eines Passworts ausgeben
├── beispiel/
│   └── benutzer.txt        Beispielliste
├── docs/
│   └── funktionsweise.md   Die Skripte Schritt für Schritt erklärt
└── tests/
    └── test.sh             Test auf einem echten Linux-System
```

Wie die Skripte im Einzelnen arbeiten, steht in [docs/funktionsweise.md](docs/funktionsweise.md).

## Lizenz

MIT, siehe [LICENSE](LICENSE).
