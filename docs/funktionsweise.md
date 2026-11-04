# Funktionsweise

Die Skripte Schritt für Schritt erklärt.

## pwhash.sh

```bash
if [ $# -ne 1 ]; then
```

`$#` ist die Anzahl der Argumente. Ist es nicht genau eines, gibt das Skript eine Gebrauchsanweisung aus und endet mit Exit-Code 1. `>&2` schickt die Meldung auf die Fehlerausgabe, damit sie nicht für einen Hash gehalten wird.

```bash
openssl passwd -6 "$1"
```

| Teil | Bedeutung |
|---|---|
| `openssl passwd` | berechnet Passwort-Hashes im Format von `/etc/shadow` |
| `-6` | Verfahren SHA-512, im Ergebnis zu erkennen an `$6$` |
| `"$1"` | das übergebene Passwort, in Anführungszeichen, damit Leer- und Sonderzeichen erhalten bleiben |

Das Ergebnis hat drei Teile, getrennt durch `$`: das Verfahren (`6`), das Salt und den Hash. Das Salt würfelt `openssl` bei jedem Aufruf neu. Deshalb ergibt dasselbe Passwort jedes Mal einen anderen Hash.

## benutzer-anlegen.sh

### 1. Voraussetzungen prüfen

```bash
if [ "$(id -u)" -ne 0 ]; then
```

`id -u` gibt die Benutzernummer (UID) aus, root hat die 0. Ohne root dürfte `useradd` nichts anlegen. Das Skript bricht deshalb früh und mit einer klaren Meldung ab.

```bash
if [ $# -ne 1 ] || [ ! -f "$1" ]; then
```

Genau ein Argument, und das muss eine vorhandene Datei sein (`-f`). `||` heißt „oder“: Trifft eine der beiden Bedingungen zu, kommt die Gebrauchsanweisung.

```bash
ordner=$(dirname "$0")
```

`$0` ist der Pfad, unter dem das Skript aufgerufen wurde, `dirname` schneidet den Dateinamen ab. So findet das Skript `pwhash.sh` im selben Ordner, auch wenn es aus einem anderen Verzeichnis gestartet wird.

### 2. Passwort abfragen

```bash
read -r -s -p "Startpasswort: " passwort
echo
```

| Option | Bedeutung |
|---|---|
| `-r` | Backslashes bleiben Backslashes |
| `-s` | die Eingabe wird nicht angezeigt |
| `-p` | zeigt vorher den Text „Startpasswort:“ |

Weil das Passwort abgefragt und nicht auf der Befehlszeile übergeben wird, steht es nicht in der Shell-Historie (`~/.bash_history`). Das `echo` danach setzt nur den Zeilenumbruch, den man bei verdeckter Eingabe nicht sieht. Ist das Passwort leer (`-z`), bricht das Skript ab.

### 3. Die Liste Zeile für Zeile lesen

```bash
while read -r name || [ -n "$name" ]; do
    ...
done < "$liste"
```

`< "$liste"` leitet die Datei in die Schleife, `read` holt pro Durchlauf eine Zeile in die Variable `name`. Leerzeichen am Anfang und Ende entfernt `read` dabei selbst.

Der Zusatz `|| [ -n "$name" ]` fängt einen bekannten Stolperstein ab: Endet die Datei ohne Zeilenumbruch, meldet `read` bei der letzten Zeile „Dateiende“, obwohl es den Namen schon gelesen hat. Ohne den Zusatz würde der letzte Benutzer still übergangen.

```bash
if [ -z "$name" ] || [ "${name:0:1}" = "#" ]; then
    continue
fi
```

Leere Zeilen und Kommentare überspringen. `${name:0:1}` ist das erste Zeichen der Zeile. `continue` springt zum nächsten Durchlauf.

### 4. Vorhandene Benutzer nicht anfassen

```bash
if id "$name" >/dev/null 2>&1; then
```

`id NAME` gelingt nur, wenn es den Benutzer gibt. Die Ausgabe interessiert hier nicht, deshalb `>/dev/null 2>&1`. Wer schon existiert, wird übersprungen. So kann man das Skript gefahrlos zweimal laufen lassen, und kein vorhandenes Passwort wird überschrieben.

### 5. Benutzer anlegen

```bash
hash=$("$ordner/pwhash.sh" "$passwort")
```

Für jeden Benutzer ein eigener Hash mit eigenem Salt.

```bash
useradd -m -s /bin/bash -p "$hash" "$name"
```

| Option | Bedeutung |
|---|---|
| `-m` | Heimatverzeichnis `/home/NAME` anlegen und mit den Dateien aus `/etc/skel` füllen |
| `-s /bin/bash` | Anmelde-Shell |
| `-p "$hash"` | Passwortfeld in `/etc/shadow`. Es muss schon ein Hash sein, `useradd` verschlüsselt nichts. |

Der Hash enthält `$`-Zeichen. In doppelten Anführungszeichen ist das sicher: Die Shell ersetzt nur Variablen, die im Befehl stehen, nicht den Inhalt von `$hash`.

```bash
chage -d 0 "$name"
```

`-d` setzt das Datum der letzten Passwortänderung. `0` bedeutet 1. Januar 1970. Das Passwort gilt damit als veraltet, und Linux verlangt bei der ersten Anmeldung ein neues.

### 6. Zählen und Exit-Code

```bash
angelegt=$((angelegt + 1))
```

`$(( ))` rechnet mit ganzen Zahlen. Am Ende steht eine Zusammenfassung. Gab es Fehler, endet das Skript mit Exit-Code 1. So merkt es auch ein anderes Skript oder ein Automatisierungswerkzeug, das `benutzer-anlegen.sh` aufruft.

## benutzer-entfernen.sh

Aufbau wie beim Anlegen, mit drei Unterschieden:

1. **Rückfrage:** Nur die Antwort `ja` löscht. Alles andere bricht ab, ohne etwas zu ändern.
2. **Schutz der Systemkonten:**

   ```bash
   if [ "$(id -u "$name")" -lt 1000 ]; then
   ```

   Konten wie `root`, `daemon` oder `www-data` haben eine UID unter 1000. Steht so ein Name versehentlich in der Liste, bleibt er unangetastet.
3. **Löschen:** `userdel -r` entfernt das Konto, sein Heimatverzeichnis und sein Postfach.

## Prüfen von Hand

```bash
sudo getent shadow nutzer01
```

Das zweite Feld muss mit `$6$` beginnen, das dritte muss `0` sein (Passwortwechsel erzwungen). Mit `su - nutzer01` lässt sich die Anmeldung testen. Danach fragt das System sofort nach einem neuen Passwort.
