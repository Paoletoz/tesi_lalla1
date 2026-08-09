# Guida al progetto — Analisi CBD vs Placebo

Questo documento spiega **cosa fa la pipeline**, **come è organizzato e come
funziona il codice R**, e **come leggere le tabelle e i grafici** prodotti.
È pensato per accompagnare la tesi e per permettere a chiunque di rieseguire e
capire l'analisi.

> Regola di fondo del progetto: **nessun numero è inventato**. Ogni valore in
> output proviene da un calcolo sui dati reali. Dove un dato manca, è marcato
> `NA` con la motivazione, mai stimato.

---

## 1. Cosa fa l'analisi (in breve)

Studio pre-post controllato su **63 cani** (CBD n = 32, Placebo n = 31), con 26
parametri misurati **prima (PRE)** e **dopo (POST)** il trattamento. Si
rispondono due domande, con test **non parametrici**:

1. **Dentro ciascun gruppo**, c'è una variazione PRE→POST? → *Wilcoxon appaiato*
   (eseguito separatamente su CBD e Placebo).
2. **Tra i due gruppi**, la variazione è diversa? → *Mann-Whitney sui delta*
   (Δ = POST − PRE).

A corredo: statistiche descrittive, dimensione dell'effetto *r*, correzione per
confronti multipli (FDR) e grafici.

### Risultato in sintesi (valori calcolati su questi dati)

- **Mann-Whitney: nessun parametro significativo.** Non è dimostrata alcuna
  differenza tra CBD e Placebo.
- **Wilcoxon intra-CBD**, significativi al p grezzo (α = 0,05): **RBC**
  (p < 0,001), **Bilirubina** (0,0154), **Eosinofili %** (0,0202), **HCT**
  (0,0209), **Eosinofili assoluti** (0,0248). RBC e HCT **in diminuzione**,
  eosinofili e bilirubina **in aumento**.
- **Dopo la correzione FDR** (26 test nella famiglia CBD) **rimane significativo
  solo RBC** (p FDR = 0,0127); gli altri quattro salgono a ≈ 0,13.
- **Wilcoxon intra-Placebo**: solo dRoms al p grezzo (0,0415), ma **non
  significativo dopo FDR** (0,4956) e su dati molto scarsi → da non enfatizzare.

---

## 2. Struttura del progetto

```
progetto_r/
├── CLAUDE.md                 # protocollo e regole vincolanti del progetto
├── GUIDA.md                  # questo file
├── run_all.R                 # esegue tutta la pipeline in ordine
├── dati/                     # SOLA LETTURA — file Excel di origine
│   └── Dati per Wilcoxon e Mann Whitney 14.06.26.xlsx
├── config/
│   └── dizionario_parametri.csv   # mappa parametro → indici colonna PRE/POST
├── R/
│   ├── 00_setup.R            # pacchetti, opzioni, percorsi, costanti
│   ├── _funzioni.R           # funzioni statistiche condivise
│   ├── 01_import_pulizia.R   # import, coercizione numerica, report qualità
│   ├── 02_descrittive.R      # descrittive per gruppo e tempo
│   ├── 03_wilcoxon.R         # Wilcoxon appaiato intra-gruppo
│   ├── 04_mann_whitney.R     # Mann-Whitney sui delta
│   ├── 05_tabelle.R          # tabella completa per la tesi (.csv/.xlsx)
│   ├── 06_grafici.R          # figure (PNG 300 dpi + PDF)
│   └── 99_validazione.R      # test di regressione contro i riferimenti §5
└── output/
    ├── tabelle/              # tutti i .csv e l'.xlsx
    ├── figure/               # 104 figure (52 PNG + 52 PDF)
    ├── METODI_STATISTICI.md  # sezione "Metodi" pronta per la tesi
    └── sessionInfo.txt       # ambiente R usato (riproducibilità)
```

---

## 3. Come si esegue

**Tutto in un colpo** (dalla cartella del progetto):

```bash
Rscript run_all.R
```

Esegue in ordine: setup → import → descrittive → Wilcoxon → Mann-Whitney →
**validazione** → tabelle → grafici → `sessionInfo.txt`. La validazione è un
**cancello**: se un risultato non corrisponde ai valori di riferimento, la
pipeline si ferma con errore **prima** di produrre gli output della tesi.

**Uno script per volta** (ognuno è indipendente e idempotente; si carica da solo
ciò che gli serve):

```bash
Rscript R/01_import_pulizia.R    # stampa e salva il report di qualità dei dati
Rscript R/03_wilcoxon.R          # ricalcola i test intra-gruppo
Rscript R/99_validazione.R       # verifica la corrispondenza con §5
```

I pacchetti richiesti sono `readxl, dplyr, tidyr, rstatix, coin, ggplot2,
openxlsx, knitr`. Se ne manca uno, `00_setup.R` si ferma indicando come
installarlo.

---

## 4. Come funziona il codice (passaggi chiave)

### 4.1 Selezione delle colonne **per indice** (non per nome)
Le intestazioni del file usano **due caratteri "micro" diversi** — `µ` (U+00B5)
in RBC/WBC e `μ` (U+03BC) nei valori assoluti/piastrine. Selezionare per nome
letterale è fragile. Perciò `config/dizionario_parametri.csv` mappa ogni
parametro ai suoi **indici di colonna PRE/POST**, e il codice seleziona per
indice. All'import i nomi vengono normalizzati (U+00B5 → U+03BC) solo a fini
cosmetici; la selezione resta per indice.

### 4.2 Import e coercizione numerica **tracciata** (`01_import_pulizia.R`)
Il foglio è letto **come testo** per non subire coercizioni silenziose. La
funzione `coerci_numerico()` converte a numero e distingue tre casi per ogni
cella: valore valido, **cella vuota**, **testo non numerico** (es. «<40»,
annotazioni, «#VALUE!»). Il testo non numerico diventa `NA` e viene **contato e
riportato** — nessuna imputazione. Prima di procedere il codice **verifica la
struttura** (63 righe, 90 colonne, `Treatment` con soli 0/1, gruppi 32/31): se
qualcosa non torna, si ferma.

### 4.3 Coppie complete (`_funzioni.R` → `estrai_coppie()`)
Per ogni parametro si tengono solo i cani con PRE **e** POST presenti. Le
descrittive e i test usano **lo stesso sottoinsieme**, così la n della tabella
coincide sempre con la n del test.

### 4.4 I test (`_funzioni.R`)
- `test_wilcoxon_appaiato()` → `wilcox.test(pre, post, paired=TRUE,
  exact=FALSE, correct=TRUE)`. `exact=FALSE` è obbligatorio con ex aequo e zeri.
- `test_mann_whitney()` → `wilcox.test(delta ~ gruppo, exact=FALSE,
  correct=TRUE)` sui **delta** (Δ = POST − PRE).
- Test **a due code**, α = 0,05. Se un test non è eseguibile → `NA` con nota.

### 4.5 Dimensione dell'effetto (doppia fonte)
`effsize_appaiato()` / `effsize_indip()` calcolano **r = |Z| / √N**. La fonte
primaria è `rstatix::wilcox_effsize()`; lo Z e un **controllo incrociato**
vengono da `coin`. Se le due fonti divergessero, il codice lo segnala
(`check_effsize`).

### 4.6 Correzione FDR **per famiglia** (`fdr_bh()`)
Con 78 test totali, ~4 falsi positivi a p < 0,05 sono attesi per caso. Si
applica Benjamini-Hochberg **separatamente** a tre famiglie: Wilcoxon CBD,
Wilcoxon Placebo, Mann-Whitney. Si riportano **sempre** p grezzo **e** p FDR.

### 4.7 Indipendenza degli script
Ogni script inizia con un piccolo *bootstrap* (`if (!exists(...)) source(...)`)
che carica setup, funzioni e dati solo se non già presenti. Così ogni script
gira da solo, ma dentro `run_all.R` nulla viene ricalcolato due volte.

---

## 5. Come leggere le tabelle (`output/tabelle/`)

### `01_report_qualita_dati.csv` — qualità dei dati
Una riga per parametro. Colonne principali:
- `n_pre_presenti` / `n_post_presenti`: valori numerici presenti a PRE/POST.
- `pre_vuoti` / `pre_testo_na` (e POST): celle mancanti perché **vuote** vs
  perché contenevano **testo**.
- `coppie_complete_CBD` / `_Placebo` / `_tot`: **la n che entra nei test**.
- `nota`: avvisi di bassa numerosità / molti mancanti (dRoms, Oxy).

### `01_report_celle_non_numeriche.csv` — cosa è stato convertito in NA
Per ogni cella testuale: parametro, tempo (PRE/POST), colonna, il **testo
originale** e quante volte compare. Qui si vede, per esempio, che i «<40» di
dRoms sono valori sotto il limite di rilevazione.

### `02_descrittive.csv` — descrittive
Formato lungo: una riga per **parametro × gruppo × tempo** (104 righe). Contiene
`n, mediana, Q1, Q3, media, ds, min, max`. La **mediana [Q1–Q3]** è la sintesi
principale (test non parametrici); media e DS sono di corredo.

### `03_wilcoxon.csv` — Wilcoxon intra-gruppo
Una riga per **parametro × gruppo** (52 righe):
- `mediana_pre`, `mediana_post`, `delta_mediana`, `variazione`
  (aumento/diminuzione/invariato);
- `p_grezzo`, `p_fdr` (BH nella famiglia del gruppo);
- `Z`, `r`, `magnitudo` (piccolo/medio/grande);
- `esito` (sul p grezzo), `nota`.

### `04_mann_whitney.csv` — Mann-Whitney tra gruppi
Una riga per parametro (26 righe): `n_cbd`, `n_placebo`,
`mediana_delta_cbd/_placebo`, `p_grezzo`, `p_fdr`, `Z`, `r`, `magnitudo`,
`esito`, `nota`.

### `05_tabella_completa.csv` / `.xlsx` — **tabella riassuntiva per la tesi**
Una riga per parametro con **tutto** insieme. L'`.xlsx` ha tre fogli:
- **Tabella_completa**: valori numerici (fonte di verità). Per ciascuno dei tre
  test: `p_...`, `p_fdr_...`, `r_...` e la **doppia dicitura di esito**
  `esito_..._grezzo` e `esito_..._fdr`.
- **Formato_tesi**: la stessa informazione **formattata** — mediana [Q1–Q3], p
  a 4 decimali con «< 0,001» sotto 0,001, r con magnitudo. Da copiare nella tesi.
- **Legenda**: descrizione di ogni colonna.

> Perché due colonne di esito? Perché la significatività al **p grezzo** può
> sparire dopo la correzione per **confronti multipli** (FDR). Riportare
> entrambe è onesto e permette al lettore di vedere dove ciò accade (es. HCT:
> «si rifiuta H₀» al grezzo, «non si rifiuta H₀» dopo FDR).

---

## 6. Come leggere i grafici (`output/figure/`)

Due figure per parametro (nome: `fig_<ordine>_<parametro>_...`), in **PNG a 300
dpi** e **PDF vettoriale**. Nessun titolo interno (va nella didascalia della
tesi); palette in **scala di grigi**, leggibile anche in bianco e nero.

- **`..._prepost`** — boxplot appaiati PRE/POST, un **pannello per gruppo**
  (CBD | Placebo). Le **linee sottili collegano lo stesso cane** tra PRE e POST:
  mostrano la variabilità individuale, non solo lo spostamento delle mediane.
  *Esempio:* in RBC le linee del CBD scendono quasi tutte (calo), nel Placebo
  sono miste.
- **`..._delta`** — boxplot della **variazione** Δ = POST − PRE per gruppo, con
  **linea tratteggiata sullo zero** (nessuna variazione). Una scatola spostata
  sopra lo zero indica un aumento prevalente, sotto una diminuzione.

---

## 7. Come interpretare i risultati (avvertenze)

- **Terminologia.** Con p ≥ 0,05 si scrive **«non si rifiuta H₀»**, mai «si
  accetta H₀»: l'assenza di prova di una differenza non è prova della sua
  assenza. «Significativo» è usato solo in senso statistico.
- **Nessuna conclusione causale** da un test di ipotesi. Le eventuali letture
  biologiche vanno in una sezione separata, come ipotesi.
- **Effetto vs significatività.** Il p dice *se* c'è evidenza di un effetto,
  l'`r` *quanto è grande*. Vanno letti insieme (soprattutto con n piccola).
- **dRoms e Oxy.** Pochissime coppie complete (dRoms CBD n = 6). I loro
  risultati sono riportati ma **fragili**; per dRoms molti valori «<40»
  (censura a sinistra) sono stati esclusi come `NA`: è una limitazione da
  dichiarare, non un dato pulito.
- **Confronti multipli.** La colonna FDR è la difesa contro i falsi positivi
  attesi su 78 test: privilegiare la lettura FDR per le conclusioni.

---

## 8. Validazione e riproducibilità

`99_validazione.R` confronta l'output con valori calcolati **indipendentemente**
(Python/SciPy) e riportati in `CLAUDE.md` §5: numerosità, medie di ancoraggio e
18 p-value di riferimento (tolleranza ± 0,01), più i controlli qualitativi
(«nessun Mann-Whitney significativo»; l'insieme dei significativi CBD). Allo
stato attuale **tutti i 28 controlli numerici e quelli qualitativi passano**. Se
un domani un valore non corrispondesse, la pipeline si ferma: è il segnale che
qualcosa nel codice o nei dati è cambiato e va indagato — **non** si allarga la
tolleranza per «far passare» il test. L'ambiente esatto è in
`output/sessionInfo.txt`.
