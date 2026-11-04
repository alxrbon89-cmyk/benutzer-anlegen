#!/bin/bash
#
# benutzer-entfernen.sh – entfernt die Benutzer einer Liste samt Heimatverzeichnis.
#
# Gegenstück zu benutzer-anlegen.sh, zum Beispiel um eine Übungs-VM aufzuräumen.
# Systemkonten (UID unter 1000) fasst das Skript nicht an.
#
# Aufruf:  sudo ./benutzer-entfernen.sh LISTE

# Nur root darf Benutzer löschen
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

# Löschen lässt sich nicht rückgängig machen - deshalb nachfragen
read -r -p "Benutzer aus $liste samt Heimatverzeichnis löschen? (ja/nein) " antwort
if [ "$antwort" != "ja" ]; then
    echo "Abgebrochen, nichts gelöscht."
    exit 0
fi

entfernt=0
fehler=0

while read -r name || [ -n "$name" ]; do
    # Leerzeilen und Kommentare überspringen
    if [ -z "$name" ] || [ "${name:0:1}" = "#" ]; then
        continue
    fi

    if ! id "$name" >/dev/null 2>&1; then
        echo "übersprungen: $name (gibt es nicht)"
        continue
    fi

    # Schutz: Systemkonten wie root, daemon oder www-data nie löschen
    if [ "$(id -u "$name")" -lt 1000 ]; then
        echo "übersprungen: $name (Systemkonto, UID unter 1000)"
        continue
    fi

    if userdel -r "$name"; then
        echo "entfernt:     $name"
        entfernt=$((entfernt + 1))
    else
        echo "FEHLER:       $name wurde nicht entfernt" >&2
        fehler=$((fehler + 1))
    fi
done < "$liste"

echo "Fertig: $entfernt entfernt, $fehler Fehler."

if [ "$fehler" -gt 0 ]; then
    exit 1
fi
