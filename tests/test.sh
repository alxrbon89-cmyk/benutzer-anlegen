#!/bin/bash
#
# tests/test.sh – prüft beide Skripte auf einem echten Linux-System.
#
# ACHTUNG: legt die Testbenutzer testnutzer1 und testnutzer2 an und löscht sie wieder.
# Nur in einer Übungs-VM oder einem Wegwerf-Container ausführen.
#
# Aufruf:  sudo ./tests/test.sh

if [ "$(id -u)" -ne 0 ]; then
    echo "Bitte mit sudo starten." >&2
    exit 1
fi

ordner=$(cd "$(dirname "$0")/.." && pwd)
pw='Test-Passwort1?'
ok=0
fehl=0

# Vorbedingung: Die Testnamen dürfen noch nicht existieren - sonst würde der Test fremde Konten löschen
for n in testnutzer1 testnutzer2; do
    if id "$n" >/dev/null 2>&1; then
        echo "$n existiert schon - Abbruch, damit nichts Fremdes gelöscht wird." >&2
        exit 1
    fi
done

tmp=$(mktemp -d)

# Am Ende immer aufräumen, auch wenn der Test unterwegs abbricht
aufraeumen() {
    for n in testnutzer1 testnutzer2; do
        if id "$n" >/dev/null 2>&1; then
            userdel -r "$n" >/dev/null 2>&1
        fi
    done
    rm -rf "$tmp"
}
trap aufraeumen EXIT

# pruefe "Beschreibung" BEFEHL ... - zählt mit und gibt OK oder FEHL aus
pruefe() {
    local text="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "OK    $text"
        ok=$((ok + 1))
    else
        echo "FEHL  $text"
        fehl=$((fehl + 1))
    fi
}

gibt_es_nicht() {
    ! id "$1" >/dev/null 2>&1
}

# Testliste mit Kommentar, Leerzeile und einer letzten Zeile OHNE Zeilenumbruch
printf '# Testliste\n\ntestnutzer1\ntestnutzer2' > "$tmp/liste.txt"
printf 'mit leerzeichen\n' > "$tmp/fehler.txt"
printf 'daemon\n' > "$tmp/system.txt"

echo "== 1. Anlegen"
echo "$pw" | "$ordner/benutzer-anlegen.sh" "$tmp/liste.txt" > "$tmp/aus.txt" 2>&1
rc=$?
cat "$tmp/aus.txt"
pruefe "Exit-Code 0 (Kommentar und Leerzeile übersprungen)" [ "$rc" -eq 0 ]
for n in testnutzer1 testnutzer2; do
    feld=$(getent shadow "$n" | cut -d: -f2)
    salt=$(echo "$feld" | cut -d'$' -f3)
    pruefe "$n existiert" id "$n"
    pruefe "$n hat /home/$n und es gehört $n" [ "$(stat -c %U "/home/$n" 2>/dev/null)" = "$n" ]
    pruefe "$n hat die Shell /bin/bash" [ "$(getent passwd "$n" | cut -d: -f7)" = /bin/bash ]
    pruefe "$n: Hash ist SHA-512 (\$6\$)" [ "${feld:0:3}" = "\$6\$" ]
    pruefe "$n: Passwort passt zum Hash" [ "$(openssl passwd -6 -salt "$salt" "$pw")" = "$feld" ]
    pruefe "$n muss das Passwort beim ersten Anmelden ändern" [ "$(getent shadow "$n" | cut -d: -f3)" = 0 ]
done
pruefe "jeder Benutzer hat ein eigenes Salt" \
    [ "$(getent shadow testnutzer1 | cut -d'$' -f3)" != "$(getent shadow testnutzer2 | cut -d'$' -f3)" ]

echo "== 2. Zweiter Lauf ändert nichts"
vorher=$(getent shadow testnutzer1)
echo "$pw" | "$ordner/benutzer-anlegen.sh" "$tmp/liste.txt" > "$tmp/aus.txt" 2>&1
rc=$?
cat "$tmp/aus.txt"
pruefe "Exit-Code 0" [ "$rc" -eq 0 ]
pruefe "meldet 'übersprungen'" grep -q "übersprungen: testnutzer1" "$tmp/aus.txt"
pruefe "Passwort von testnutzer1 unverändert" [ "$(getent shadow testnutzer1)" = "$vorher" ]

echo "== 3. Ungültiger Name"
echo "$pw" | "$ordner/benutzer-anlegen.sh" "$tmp/fehler.txt" > "$tmp/aus.txt" 2>&1
rc=$?
cat "$tmp/aus.txt"
pruefe "Exit-Code 1" [ "$rc" -eq 1 ]
pruefe "meldet FEHLER" grep -q "FEHLER: *mit leerzeichen" "$tmp/aus.txt"

echo "== 4. Ohne Passwort"
echo "" | "$ordner/benutzer-anlegen.sh" "$tmp/liste.txt" > "$tmp/aus.txt" 2>&1
rc=$?
pruefe "Exit-Code 1 und Abbruch" [ "$rc" -eq 1 ]

echo "== 5. Entfernen"
echo ja | "$ordner/benutzer-entfernen.sh" "$tmp/system.txt" > "$tmp/aus.txt" 2>&1
cat "$tmp/aus.txt"
pruefe "Systemkonto daemon bleibt" id daemon
echo nein | "$ordner/benutzer-entfernen.sh" "$tmp/liste.txt" > "$tmp/aus.txt" 2>&1
pruefe "bei 'nein' wird nichts gelöscht" id testnutzer1
echo ja | "$ordner/benutzer-entfernen.sh" "$tmp/liste.txt" > "$tmp/aus.txt" 2>&1
rc=$?
cat "$tmp/aus.txt"
pruefe "Exit-Code 0" [ "$rc" -eq 0 ]
for n in testnutzer1 testnutzer2; do
    pruefe "$n ist weg" gibt_es_nicht "$n"
    pruefe "/home/$n ist weg" [ ! -e "/home/$n" ]
done

echo
echo "Ergebnis: $ok bestanden, $fehl fehlgeschlagen."
if [ "$fehl" -gt 0 ]; then
    exit 1
fi
