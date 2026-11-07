# Homio

Een slimme-huis-app voor iPhone, iPad, Mac en Apple Watch, gebouwd op Apple Woning (HomeKit en Matter), met de opbouw van Homey: zones, dashboards met widgets, flows en inzichten. Plus een HomeView-achtige weergavemodus voor een iPad aan de muur.

- **Platforms:** iOS en iPadOS 17+, macOS 14+ (Mac Catalyst), watchOS 10+ (eigen Watch-app, `nl.lrvdlinden.homio.watchkitapp`)
- **Bundle-ID:** `nl.lrvdlinden.homio`
- **Inloggen:** Sign in with Apple (lokaal, geen server)

## Openen en draaien

1. Open `Homio.xcodeproj` in Xcode 16 of nieuwer.
2. Kies bij **Signing & Capabilities** je team, voor beide targets (Homio en HomioWatch). HomeKit, Sign in with Apple, iCloud (CloudKit-container `iCloud.nl.lrvdlinden.homio`) en Push Notifications staan al in `Homio.entitlements`; de Mac gebruikt `Homio-mac.entitlements` (met sandbox).
   - Voor de Mac: kies als bestemming "My Mac (Mac Catalyst)".
   - De Watch-app wordt automatisch meegebouwd en in de iPhone-app gestopt.
3. Draai op een echte iPhone of iPad. Flows hebben een woninghub nodig (Apple TV of HomePod).

## Tabbladen

| Tab | Wat het doet |
|---|---|
| **Thuis** | Begroeting, status (binnen/buiten, lampen, sloten), zones: Favorieten · Alles · per kamer. Sferen bovenaan (maken, bewerken, verwijderen). Kamerkop met temperatuur, vocht en "Lampen uit". Camera's in een strook. |
| **Dashboards** | Meerdere dashboards (bijv. Woonkamer, Beveiliging). Widgets in drie formaten (klein, breed, groot): apparaat met snelle bediening, sfeer, kamer of hele huis, klok, weer, camera, grafiek, timers, agenda, flows, notitie. Bewerken: wiebelen, slepen, formaat kiezen, verwijderen. |
| **Flows** | Als / En / Dan. Als: apparaat, tijd (met weekdagen), zon (met verschuiving) of aankomen/vertrekken. En: tussen tijden, donker/licht, apparaat aan/uit. Dan: apparaten bedienen of sferen starten, met "daarna terug na x min". Draait als echte HomeKit-automatisering op de woninghub. Ook automatiseringen uit de Woning-app: aan/uit, nu uitvoeren, verwijderen. Snelstart-sjablonen. |
| **Inzichten** | Grafieken (temperatuur, vocht, verlichting, schakelaars) over 6 uur tot 7 dagen met laagste/gemiddelde/hoogste, en een tijdlijn van wat er in huis gebeurt. |
| **Meer** | Weergavemodus, meldingen, profielen, faces, scherm, fotolijst, woning (kamers beheren, huiscontrole), account, "Meer apps van de ontwikkelaar". |

**Extra op Thuis:** aandachtskaarten (deur open, slot open, lampen nog aan 's nachts, lege batterij, apparaat reageert niet, hoge luchtvochtigheid) met één-tik-oplossing; groepen over kamers heen (bijv. "Alle buitenlampen") met één knop en gezamenlijke helderheid; zoeken door apparaten, groepen, sferen en flows.

**Apparaat (lang drukken):** dimmen, kleurwiel en wit van warm tot koel (Kelvin), en via het tandwiel: naam, kamer, favoriet, fabrikant, model, firmware, batterij en verwijderen.

**Siri en Opdrachten:** "Bedien [apparaat] met Homio", "Alle lampen uit met Homio", "Start een scène in Homio".

**Weergavemodus (kiosk):** faces om doorheen te vegen (klok, woning, dashboard, camera's, foto's, weer, agenda, Flow-kunst), nabijheid, nachtdimmen, dock. Starten via de knop linksboven of automatisch bij het openen.

## Apple Watch

Sferen starten, kamers en apparaten bedienen (dimmen, gordijnen, thermostaat met de Digital Crown), flows bekijken (aan/uit zetten kan watchOS niet), een korte opening met de vier tegels. Meldingen van Homio verschijnen vanzelf op de Watch via de iPhone.

## Pushmeldingen (zonder eigen server)

- Zet in **Meer › Meldingen** op één apparaat dat altijd aan staat (bijv. de iPad aan de muur) "Dit apparaat verstuurt meldingen" aan.
- Zet op je iPhone "Meldingen op dit apparaat" aan.
- Gaat er een gekozen deur, raam, slot of bewegingssensor om, dan zet de iPad een bericht in je eigen iCloud (CloudKit, privédatabase) en krijgt de iPhone een echte pushmelding, ook als Homio dicht is.
- Voor de App Store: zet in het CloudKit Dashboard het schema (recordtype `HomioEvent`) over naar Production.

## iCloud-synchronisatie

Apparaten, kamers, sferen en automatiseringen synct Apple Woning zelf. Daarbovenop synct Homio via iCloud-sleutelopslag (`com.apple.developer.ubiquity-kvstore-identifier`) tussen iPhone, iPad en Mac met hetzelfde Apple-account: dashboards, groepen, profielen en favorieten, faces, timers, het bewerken van flows en de keuze waarover je meldingen krijgt. De nieuwste wijziging wint. Per apparaat blijven: weergavemodus-stand, scherm aan, nachtdimmen, nabijheid, versturen/ontvangen van meldingen, de fotolijst en de metingen in Inzichten. Aan/uit en status: **Meer › iCloud-synchronisatie**.

## Beoordelingsvraag

Per apparaat: de eerste keer 4 uur na het eerste gebruik, daarna hooguit één keer per week, alleen ±4 seconden na het openen, nooit tijdens splash, inloggen of de weergavemodus, en pas als er minstens één apparaat in de woning staat. Apple laat de vraag daarnaast hooguit 3 keer per jaar zien.

## Goed om te weten

- **Geschiedenis:** HomeKit bewaart geen meetgeschiedenis. Homio meet elke 5 minuten zolang de app open is en bewaart 7 dagen. De tijdlijn toont wat Homio ziet gebeuren.
- **Flows:** Homio maakt per flow een actiegroep met de naam "Homio · …". In de Woning-app verschijnt die als scène; in Homio wordt hij verborgen.
- **Weer:** via Open-Meteo, zonder sleutel. Gratis gebruik is niet-commercieel; voor een betaalde App Store-app een Open-Meteo-abonnement of WeatherKit nemen.
- **Mac:** apparaten toevoegen kan alleen op iPhone of iPad; de rest werkt op de Mac hetzelfde.
- **Talen:** Nederlands is de brontaal. De kaart "Meer apps van de ontwikkelaar" (LRvdLinden-huisstijl, zoals in Homey Store) volgt de app-taal: Nederlands, Engels, Duits, Frans of Spaans.
