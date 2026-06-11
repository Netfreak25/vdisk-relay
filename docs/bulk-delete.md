# Bulk Delete for Data Workspace

## Ziel

Die `/data` Seite bietet jetzt eine Mehrfachauswahl und eine Warteschlangen-basierten Löschpfad, damit Video-Dateien auf einem Raspberry Pi Zero W nicht parallel und blockierend gelöscht werden.

- Die Karte selbst bleibt der Player-Loader (`click` auf die Karte = Vorschau laden).
- Die Auswahl erfolgt ausschließlich über das Auswahl-Control (Checkbox) links oben auf der Karte.
- Klicks auf das Auswahl-Control bleiben vom Player-Load getrennt.
- Bulk-Aktionen laufen über eine Warteschlange:
  - `Select page` wählt alle sichtbaren Karten der aktuellen Seite.
  - `Clear` leert die lokale Auswahl.
  - `Delete selected` öffnet eine Bestätigung.

## API und Verhalten

- Endpunkt: `POST /data/delete`
- Erwartet IDs als wiederholte Form-Felder `video_ids`.
- Pfade werden serverseitig aus der Datenbank/den bekannten Relativpfaden aufgelöst; Clients senden nur IDs.
- Bei bestätigter Aktion werden Einträge in die Lösch-Warteschlange geschrieben.

## Statusanzeigen

Für jedes Element kann ein Status angezeigt werden:

- `Queued for deletion`
- `Deleting`
- `Deleted`
- `Delete failed`
- `Ignored`

Die Statusklasse folgt dem bestehenden Farb-/Statusschema (warn/bad/ok/muted).

## Verarbeitung / Throttling

Der Worker verarbeitet die Queue seriell:

- maximal ein aktiver Löschvorgang gleichzeitig,
- Verzögerung zwischen Löschversuchen,
- Wiederholungslogik mit Backoff,
- minimale Dateialter- und Typprüfung (keine temporären/zu neuen Dateien),
- keine direkten Massenlöschungen in der HTTP-Anfrage.

## Konfiguration und Fehlerfälle

Sichtbare Status-Labels im UI:

- `selected`
- `page selected` (intern als `Select page`)
- `Clear`
- `Delete selected`
- `Queued for deletion`
- `Delete failed`
- Bestätigungsdialog vor Ausführung.

Wenn neue IDs nicht queue-fähig sind (zu neu, ungültig, temporär), werden sie als `skipped` gesetzt und nicht direkt gelöscht.

## UI-Zustände

- `active`: Die aktuell im Player geladene Karte ist visuell hervorgehoben.
- `selected`: Die Checkbox-Auswahl markiert Karten ohne den Player zu starten.
- Beide Zustände können nebeneinander sichtbar sein (aktuelle Wiedergabe + ausgewählte Clips).

## Hinweis

Dieses Verhalten ergänzt den bereits vorhandenen, persistenten Preview-/Delete-Queue-Mechanismus und ersetzt direkte direkte Löschaufrufe über die UI.
