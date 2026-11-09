# Formelschreiber

Menüleisten-App für macOS, die Chemie-Schreibweise in sauberen Unicode-Text umwandelt –
z. B. `2 H2 + O2 -> 2 H2O` → `2 H₂ + O₂ → 2 H₂O`. Funktioniert in jeder App (Word, Pages, Mail, Keynote, Browser …).

## Benutzung

- **⌃⌥⌘F** oder Klick auf das Kolben-Symbol: Formelfenster öffnen, tippen, **↩** fügt das Ergebnis in die vorherige App ein.
- **⌃⌥⌘K**: markierten Text in der aktuellen App direkt umwandeln.
- Rechtsklick auf das Symbol: Menü mit „Beenden“.

Direktes Einfügen und ⌃⌥⌘K brauchen die Freigabe unter *Systemeinstellungen › Datenschutz & Sicherheit › Bedienungshilfen*. Ohne sie wird das Ergebnis in die Zwischenablage kopiert.

## Schreibweise

| Eingabe | Ergebnis |
|---|---|
| `H2O`, `Ca(OH)2`, `CuSO4*5H2O` | H₂O, Ca(OH)₂, CuSO₄·5H₂O |
| `Na+`, `Fe3+`, `SO42-`, `[Fe(CN)6]3-` | Na⁺, Fe³⁺, SO₄²⁻, [Fe(CN)₆]³⁻ |
| `SO4^2-`, `^14C`, `C_n H_{2n+2}` | SO₄²⁻, ¹⁴C, Cₙ H₂ₙ₊₂ |
| `->`, `<=>`, `<-` | →, ⇌, ← |
| `CO2 ^`, `AgCl _` | CO₂ ↑, AgCl ↓ |
| `2e-`, `DeltaH`, `25 degC` | 2e⁻, ΔH, 25 °C |

Normale Wörter bleiben unverändert: Zahlen werden nur tiefgestellt, wenn das ganze Wort aus Elementsymbolen besteht.

## Installation

```bash
./install.sh
```

Baut die App, signiert sie mit dem Entwicklerzertifikat (damit die Freigabe Updates übersteht) und startet sie.
