# Code-Review-Anpassungen

## Spielzustand und Speichern

- `GameManager.travel_in_progress` unterscheidet einen bezahlten, noch nicht abgeschlossenen Flug von einer Landung. `get_resume_scene()` bestimmt die Einstiegsszene beim Fortsetzen.
- Der automatische Speicherpunkt bleibt der Abflug: Wird die App während Reise, Kampf oder Beuteauswahl beendet, startet der gespeicherte Flug erneut. Treibstoff, Reisetage und Tageskosten werden dabei nicht nochmals abgezogen. Einzelne Kampfzüge werden nicht gespeichert.
- `complete_travel_arrival()` beendet den Flug genau einmal und wendet die Ankunftsboni an. Das Öffnen des Planetenbildschirms gewährt keine zusätzlichen Boni.
- Abgeschlossene Ankunftsereignisse, Missionsstatus, Casinorunden und die Verkaufssperre für Ankunftsfracht werden gespeichert. Die Ankunftsereignisse laufen nacheinander; nach Abschluss der gesamten Sequenz wird gespeichert.
- `EconomyManager.save_state()` / `load_state()` speichern Basispreise und Marktsättigung gemeinsam. Alle Kaufpreise einschließlich Frachterrabatt kommen aus `get_buy_price_breakdown()`. Verkaufstooltips verwenden `uncapped_price` und `was_capped` aus `get_sell_price_breakdown()`.
- Beim Neustart werden Weltzustand, Fabriken und Begegnungsstatus vor der Questgenerierung zurückgesetzt.

Alte Spielstände bleiben lesbar. Fehlende Basispreise werden einmalig erzeugt; vorhandene Marktsättigung wird übernommen. Fehlen die Ankunfts- und Missionsmarkierungen, gilt eine gespeicherte Landung vorsorglich als bereits abgehandelt. Für alte Flugstände wird ein vom aktuellen Planeten abweichendes Reiseziel als laufender Flug interpretiert; nach früheren Fluchtmanövern ist diese Unterscheidung mangels alter Statusmarkierung nicht immer eindeutig.

## Komponenten

- `planet_arrival.gd`: Ereignisfolge und Erfassung neuer Ankunftsfracht; meldet Änderungen und Abschluss per Signal.
- `hub_overlay_stack.gd`: verwaltet konkrete Overlayinstanzen in Öffnungsreihenfolge und schließt mit Escape das zuletzt geöffnete Overlay.
- `hub_debug.gd`: Debugtasten und Debuganzeigen des Planetenbildschirms.
- `CardDisplay.set_count()`: kapselt die Mengenanzeige, damit der Deckviewer keine internen Node-Pfade kennen muss.
- Der Kampf verwendet eine Spieler-, Gegner- und Pausenphase sowie eine laufende Zugkennung. Verzögerte Zugabschlüsse gelten ausschließlich für den Zug, der sie angefordert hat.

Die ungenutzten Felder `damaged_upgrades`, `ShipRole` und `hull_color_primary` wurden einschließlich der betroffenen Schiffsdaten entfernt. Alte Savegame-Schlüssel werden beim Laden ignoriert.

## Prüfung

Unter Godot 4.7.1: Hauptmenüstart, Laden aller 83 Spielskripte und 173 gezielte Prüfungen bestanden. Die Laufzeitprüfungen nutzten getrennte temporäre Speicherdateien. Abgedeckt sind Reset-Reihenfolge, Marktpreise, JSON-Roundtrip, alte Spielstände, Reise-/Landungsstatus, der Fortsetzen-Button, Ankunftsereignisse, Overlayreihenfolge, Kartenmengen und konkurrierende Kampfaktionen.

Für die visuelle Prüfung im Editor:

1. Die letzte spielbare Kampfkarte verwenden und sofort manuell den Zug beenden. Der nächste Spielerzug muss erhalten bleiben; während der Gegneranimation dürfen Karten, Flucht und Entern nicht reagieren.
2. Einen Flug starten, die App schließen und fortsetzen. Der Flug beginnt am Abflug-Speicherpunkt; Treibstoff und verstrichene Tage bleiben gleich.
3. Frachter kaufen, Markt öffnen und angezeigten Kaufpreis mit der Abbuchung vergleichen. Bei hoher Reputation und Loyalität darf derselbe Markt keinen höheren Verkaufspreis anbieten.
4. Mit Ankunftsregeneration landen, speichern und neu laden. Keine zweite Regeneration; Missions- und Casinogrenzen bleiben erhalten.
5. Markt, Deck, Mission, Ereignisse und Hinweise auf Desktop und iPad öffnen. Layout, Eingabesicherheit und Schließen prüfen; Kartenstapel zeigen genau eine Mengenanzeige.
