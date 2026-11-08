# Homey-vormgeving (uit Homey-app 8.2.2, voor Homio)

Bron: thema-modules in de Homey Android-app (React Native/Hermes). Alleen maten en kleuren overgenomen; geen iconen of afbeeldingen.

## Kleuren (licht / donker)
| Token | Licht | Donker | Gebruik |
|---|---|---|---|
| body (mono_025) | #F4F4FA | #111218 | pagina-achtergrond |
| component | #FFFFFF | #1F2029 | kaarten |
| component_on | #FFFFFF | #3B3D4A | tegel aan |
| component_off | #F1F1F8 | #1F2029 | tegel uit (+ haarlijn zwart 5% / #2B2C36) |
| text (mono_900) | #1C1C1C | #E4E4E7 | tekst |
| textLight | #93939A | #999AA3 | secundaire tekst |
| line | #DADAE2 | #3B3D4A | lijnen |
| blauw | #0082FA | | accent |
| groen / rood / oranje / geel / paars | #3FC700 / #D81C1D / #FF8400 / #F5B207 / #9033FC | | status, zone-bediening |

## Maten
- su = 8; rand 16 (tablet 32); goot 16; tegel-padding 12
- radius 10 (klein 5, groot 20)
- schaduw licht: y 2, blur 3, 12% zwart
- letters: 32/24/20/17/14/12/11, regelhoogte 38/28/24/20/20/14/13

## Apparaattegel
- vierkant; kolommen = max(3, round(breedte / (124 + goot)))
- ontwerp op 108 pt: icoon 36 (1/3 breedte), naam 14 pt medium, linksonder
- rechtsboven een indicator: waarde, batterij of rood alarmrondje (24% van de tegel) met "!"
- tik = snelle actie (zacht tikje), lang drukken = apparaat openen (medium tik)
- zonder snelle actie (sensor) staat de tegel altijd "aan"

## Homey v10.1.4 (APK, nagelopen)

- body `mono_025` (#F4F4FA / #111218), component `mono_000/mono_050` (#FFF / #1F2029).
- Apparaattegel: uit = `component_off` (#F1F1F8 / #181920) met haarlijn `mono_100` (#DADAE2 / #2B2C36);
  aan = `component_on` (#FFF / #2B2C36) zonder rand; overgang geanimeerd (interpolateColor).
- Tegelmaten blijven: ontwerp op 108 px, icoon 36/108 van de breedte, tekst `fontSize.small`.
- `system_*`-kleuren voor app-iconen (Meer/Instellingen/Flow) en `insights_*`-kleuren voor grafieken
  staan in `SystemColor` en `InsightsColor` in Theme.swift.
