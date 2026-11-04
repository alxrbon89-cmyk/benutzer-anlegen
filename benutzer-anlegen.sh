#!/bin/bash
#
# benutzer-anlegen.sh – legt Benutzer aus einer Liste an.
#
# Jeder Benutzer bekommt:
#   - ein Heimatverzeichnis (/home/NAME) und die Shell /bin/bash
#   - das gemeinsame Startpasswort, gespeichert als Hash
#   - die Pflicht, das Passwort bei der ersten Anmeldung zu ändern
#
# Aufruf:  sudo ./benutzer-anlegen.sh LISTE
# LISTE:   ein Benutzername pro Zeile; Leerzeilen und Zeilen mit # werden übersprungen

# Nur root darf Benutzer anlegen
if [ "$(id -u)" -ne 0 ]; then
    echo "Bitte mit sudo starten." >&2
    exit 1
fi

# Genau ein Argument, und das muss eine Datei sein
if [ $# -ne 1 ] || [ ! -f "$1" ]; then
    echo "Aufruf: sudo $0 LISTE" >&2
    exit 1
fi
liste="$1"

# pwhash.sh liegt im selben Ordner wie dieses Skript
ordner=$(dirname "$0")

# Passwort verdeckt abfragen - so steht es nicht in der Shell-Historie
read -r -s -p "Startpasswort: " passwort
echo
if [ -z "$passwort" ]; then
    echo "Kein Passwort eingegeben - Abbruch." >&2
    exit 1
fi

angelegt=0
fehler=0

# "|| [ -n "$name" ]" liest auch die letzte Zeile, wenn danach kein Zeilenumbruch kommt
while read -r name || [ -n "$name" ]; do
    # Leerzeilen und Kommentare überspringen
    if [ -z "$name" ] || [ "${name:0:1}" = "#" ]; then
        continue
    fi

    # Gibt es den Benutzer schon? Dann nichts an ihm ändern.
    if id "$name" >/dev/null 2>&1; then
        echo "übersprungen: $name (gibt es schon)"
        continue
    fi

    # Für jeden Benutzer ein eigener Hash mit eigenem Salt
    hash=$("$ordner/pwhash.sh" "$passwort")

    if useradd -m -s /bin/bash -p "$hash" "$name"; then
        chage -d 0 "$name"      # Passwort bei der ersten Anmeldung ändern
        echo "angelegt:     $name"
        angelegt=$((angelegt + 1))
    else
        echo "FEHLER:       $name wurde nicht angelegt" >&2
        fehler=$((fehler + 1))
    fi
done < "$liste"

echo "Fertig: $angelegt angelegt, $fehler Fehler."

# Exit-Code 1, wenn etwas schiefging - damit andere Skripte es merken
if [ "$fehler" -gt 0 ]; then
    exit 1
fi
