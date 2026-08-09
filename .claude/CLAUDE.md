# Analisi statistica non parametrica — Studio CBD vs Placebo (tesi magistrale)

Progetto di analisi dati per una tesi magistrale. Studio controllato pre-post su cani di
canile: un gruppo riceve olio di CBD, un gruppo riceve placebo. Si confrontano parametri
fisici, ematologici, biochimici e di stress ossidativo prima e dopo il trattamento.

Il deliverable è **codice R riproducibile** che produce tabelle e grafici destinati
direttamente alla tesi. I risultati verranno letti da un relatore e da una commissione.

---

## 1. Regole non negoziabili

Queste regole vengono prima di qualunque altra istruzione in questo file.

1. **Nessun numero inventato, mai.** Ogni valore stampato, salvato o citato deve essere
   l'output di un calcolo eseguito sui dati reali in questa sessione. Non generare valori
   "plausibili", "di esempio", "tipici" o "in attesa del calcolo". Non riempire una tabella
   con placeholder numerici.
2. **Se un dato non c'è, dichiaralo e fermati.** Se una colonna richiesta non esiste nel
   file, non stimarla, non derivarla di nascosto e non sostituirla con un parametro simile:
   segnalalo esplicitamente all'utente e chiedi come procedere.
3. **Non riutilizzare i valori del file `Risultati Wilcoxon_Mann Whitney_13.05.26.xlsx`.**
   Quei p-value non sono riproducibili dai dati grezzi (medie incongruenti, N sbagliato,
   parametri inesistenti nel dataset, i due fogli si contraddicono). Vanno trattati come
   non validi. Servono solo come termine di paragone in un eventuale foglio di confronto,
   mai come fonte.
4. **Ogni tabella di risultati riporta la n effettiva** usata per quel test, parametro per
   parametro. La n varia perché varia il numero di dati mancanti.
5. **Nessun arrotondamento "estetico".** I p-value si riportano a 3-4 decimali; sotto
   0.001 si scrive `< 0.001`. Non convertire 0.0503 in 0.05.
6. **Se un test non è eseguibile** (n troppo bassa, tutte le differenze nulle, varianza
   zero), il risultato è `NA` con una nota sul motivo — non un p-value approssimato.

---

## 2. Dati

- **File:** `dati/Dati per Wilcoxon e Mann Whitney 14.06.26.xlsx`
- **Foglio:** `Foglio1` — unico foglio, 63 righe di dati + 1 riga di intestazione, 90 colonne
- **Unità statistica:** un cane per riga
- **Variabile di gruppo:** colonna `Treatment` — `1` = CBD (n = 32), `0` = Placebo (n = 31)
- **Identificativi:** `Dogs` (nome), `Dog ID`, `Microchip`, `Box`

### Trappola nei nomi di colonna

Il file usa **due caratteri "micro" diversi** nelle intestazioni:

- `µ` (MICRO SIGN, U+00B5) nelle colonne dei globuli rossi e dei WBC
- `μ` (GREEK SMALL LETTER MU, U+03BC) nelle colonne dei valori assoluti e delle piastrine

Selezionare le colonne **per indice numerico**, non per nome letterale. Un `select("1Neu μL")`
scritto con il carattere sbagliato fallisce in modo silenzioso o rumoroso a seconda del
pacchetto. In alternativa, normalizzare i nomi all'import (`gsub("\u00b5", "\u03bc", names(df))`)
e documentarlo.

### Dizionario delle coppie PRE / POST (indici 1-based del foglio)

| Parametro                | Col. PRE | Col. POST | Nome PRE              | Nome POST              |
|--------------------------|---------:|----------:|-----------------------|------------------------|
| Peso (kg)                |        6 |         7 | `Weight pre (kg)`     | `Weight post (kg)`     |
| BCS Fat %                |        8 |         9 | `1_BCS Fat %`         | `2_BCS Fat %2`         |
| RBC (10^6/µl)            |       34 |        35 | `1Red cells mil/µL`   | `2Red cells mil/µL2`   |
| HGB (g/dl)               |       36 |        37 | `1Hemogl g/dL`        | `2Hemogl g/dL2`        |
| HCT (%)                  |       38 |        39 | `1HCT %`              | `2HCT %2`              |
| MCHC (g/dl)              |       40 |        41 | `1MCHC`               | `2MCHC`                |
| RDW (%)                  |       42 |        43 | `1RDW (%)`            | `2RDW (%)`             |
| WBC (10^3/µl)            |       44 |        45 | `1WBC migliaia/µL`    | `2WBC migliaia/µL2`    |
| Neutrofili (%)           |       46 |        47 | `1Neutr (%)`          | `2Neutr (%)`           |
| Linfociti (%)            |       48 |        49 | `1Lym %`              | `2Lym %2`              |
| Monociti (%)             |       50 |        51 | `1Mon %`              | `2Mon %2`              |
| Eosinofili (%)           |       52 |        53 | `1Eos %`              | `2Eos %2`              |
| Neutrofili (10^3/µl)     |       54 |        55 | `1Neu μL`             | `2Neu μL`              |
| Linfociti (10^3/µl)      |       56 |        57 | `1Lym μL`             | `2Lym μL`              |
| Monociti (10^3/µl)       |       58 |        59 | `1Mon μL`             | `2Mon μL`              |
| Eosinofili (10^3/µl)     |       60 |        61 | `1Eos thous/μL`       | `2Eos thous/μL2`       |
| PLT (10^3/µl)            |       62 |        63 | `1PLT thous/μL`       | `2PLT thous/μL2`       |
| MPV (fL)                 |       64 |        65 | `1MPV fL`             | `2MPV fL2`             |
| PCT (%)                  |       66 |        67 | `1PCT %`              | `2PCT %2`              |
| GOT-AST (U/L)            |       68 |        69 | `1GOT-AST`            | `2GOT-AST2`            |
| GPT-ALT (U/L)            |       70 |        71 | `1GPT-ALT`            | `2GPT-ALT2`            |
| Bilirubina tot (mg/dl)   |       72 |        73 | `1Bil Tot`            | `2Bil Tot2`            |
| BUN (mg/dl)              |       74 |        75 | `1BUN`                | `2BUN2`                |
| Creatinina (mg/dl)       |       76 |        77 | `1Creatinin`          | `2Creatinin2`          |
| dRoms (U.CARR.)          |       80 |        81 | `1dRoms U.CARR.`      | `2dRoms U.CARR.2`      |
| Oxy (µmol HClO/ml)       |       82 |        83 | `1Oxy (umol HClO/ml)` | `2Oxy (umol HClO/ml)2` |

Il dizionario va scritto in un file di configurazione (`R/00_dizionario.R` o un CSV in
`config/`), non ripetuto dentro gli script di analisi.

### Parametri NON presenti nel dataset

**MCV e MCH non esistono come colonne.** Sono derivabili (`MCV = HCT/RBC*10`,
`MCH = HGB/RBC*10`) ma i valori derivati non coincidono con quelli del vecchio file
risultati. Se vengono calcolati, devono comparire in una sezione separata e
**etichettati come derivati**, mai mescolati ai parametri misurati.

### Valori non numerici da gestire

Alcune celle contengono testo dove ci si aspetta un numero: `"<40"`, `"<0,09"`,
`"non ancora presente"`, `"#VALUE!"`, `"#DIV/0!"`, celle vuote. La conversione a numerico
deve produrre `NA` **e stampare un conteggio per colonna** di quante celle sono state
convertite in `NA`, così che l'utente veda cosa ha perso. Nessuna imputazione.

`dRoms` e `Oxy` hanno moltissimi dati mancanti (poche coppie complete): vanno analizzati
ma con un avviso esplicito sulla bassa numerosità.

---

## 3. Protocollo statistico

### Ipotesi

**Test di Wilcoxon dei ranghi con segno** — confronto intra-gruppo, PRE vs POST, eseguito
separatamente in CBD e in Placebo:

- H0: non c'è differenza tra pre e post trattamento nel singolo individuo
- H1: c'è differenza tra pre e post trattamento nel singolo individuo

**Test di Mann-Whitney U** — confronto tra i due gruppi:

- H0: non c'è differenza tra il gruppo CBD e il gruppo Placebo
- H1: c'è differenza tra il gruppo CBD e il gruppo Placebo

### Specifiche di calcolo

- **Wilcoxon:** `wilcox.test(pre, post, paired = TRUE, exact = FALSE, correct = TRUE)`.
  `exact = FALSE` è obbligatorio: con ex aequo (ties) e zeri il test esatto non è
  applicabile e R emetterebbe comunque un warning. La correzione di continuità va tenuta
  attiva e dichiarata nel metodo.
- **Mann-Whitney:** si applica **al delta individuale** `delta = POST - PRE`, non ai soli
  valori POST. Confrontare i delta annulla le differenze basali tra i gruppi.
  `wilcox.test(delta ~ gruppo, exact = FALSE, correct = TRUE)`.
- **Coppie complete:** per ogni parametro si usano solo i cani con PRE e POST entrambi
  presenti. Le descrittive (media, mediana) vanno calcolate **sullo stesso sottoinsieme**
  usato per il test, altrimenti la n della tabella non corrisponde alle medie.
- **Test a due code**, α = 0.05.
- **Effect size:** `r = |Z| / sqrt(N)`. Usare `rstatix::wilcox_effsize()` come fonte
  primaria e `coin::wilcoxsign_test()` / `coin::wilcox_test()` per ottenere lo Z e fare
  un controllo incrociato. Convenzione: 0.1 piccolo, 0.3 medio, 0.5 grande.
- **Confronti multipli:** 26 parametri × 3 test = 78 test. Con 78 test, circa 4 risultati
  con p < 0.05 sono attesi per solo effetto del caso. Va aggiunta una colonna con p
  corretto **Benjamini-Hochberg (FDR)**, applicata per famiglia di test separata
  (Wilcoxon CBD / Wilcoxon Placebo / Mann-Whitney). Riportare sempre **entrambe** le
  colonne, p grezzo e p corretto.
- **Descrittive:** per ogni gruppo e tempo: n, mediana, Q1, Q3, media, DS, min, max.
  I test sono non parametrici, quindi **la mediana con IQR è la statistica principale**;
  la media si riporta come corredo, non al suo posto.

### Terminologia obbligatoria

Con p ≥ 0.05 si scrive **"non si rifiuta H0"**, mai "si accetta H0": l'assenza di prova di
una differenza non è prova della sua assenza. Con p < 0.05 si scrive "si rifiuta H0" /
"differenza statisticamente significativa".

Il termine "significativo" va usato solo in senso statistico. Le interpretazioni
biologiche/cliniche vanno in una sezione separata, formulate come ipotesi e non come
conclusioni.

---

## 4. Struttura del progetto

```
.
├── CLAUDE.md
├── dati/                    # sola lettura, mai modificare
│   └── Dati per Wilcoxon e Mann Whitney 14.06.26.xlsx
├── R/
│   ├── 00_setup.R           # pacchetti, opzioni, path
│   ├── 01_import_pulizia.R  # import, coercizione numerica, report NA
│   ├── 02_descrittive.R
│   ├── 03_wilcoxon.R
│   ├── 04_mann_whitney.R
│   ├── 05_tabelle.R         # tabelle per la tesi
│   ├── 06_grafici.R
│   └── 99_validazione.R     # test di regressione, vedi §5
├── output/
│   ├── tabelle/             # .csv e .xlsx
│   └── figure/              # .png 300 dpi + .pdf vettoriale
└── run_all.R                # esegue tutto in ordine
```

- Pacchetti: `readxl`, `dplyr`, `tidyr`, `rstatix`, `coin`, `ggplot2`, `openxlsx`, `knitr`.
  Nessun pacchetto esotico senza motivo.
- Ogni script gira in modo indipendente ed è idempotente.
- `sessionInfo()` va salvato in `output/sessionInfo.txt` a fine esecuzione.
- Codice e commenti **in italiano**, nomi di oggetti in italiano o inglese purché coerenti.

### Requisiti dei grafici

Boxplot appaiati PRE/POST per gruppo con le linee che collegano i singoli soggetti
(mostrare la variabilità individuale, non solo le mediane), boxplot dei delta per gruppo,
etichette in italiano con unità di misura, nessun titolo interno al grafico (va in
didascalia), palette leggibile anche in bianco e nero.

---

## 5. Validazione obbligatoria

Prima di consegnare qualsiasi risultato, `99_validazione.R` deve confrontare l'output con
questi valori di riferimento, calcolati indipendentemente in Python/SciPy sugli stessi dati.
**Se non corrispondono, il codice R ha un bug: non consegnare, indaga.**

| Controllo                              | Atteso |
|----------------------------------------|-------:|
| Righe totali                           |     63 |
| n CBD (`Treatment == 1`)               |     32 |
| n Placebo (`Treatment == 0`)           |     31 |
| n coppie complete Peso — CBD           |     32 |
| n coppie complete Peso — Placebo       |     29 |
| Media PRE Peso CBD (coppie complete)   | 27.397 |
| Media POST Peso CBD                    | 27.881 |
| Media PRE Peso Placebo                 | 26.774 |
| Media PRE RBC CBD                      |  7.513 |
| Media PRE HCT CBD                      | 49.410 |

P-value attesi (`exact = FALSE, correct = TRUE`, tolleranza ± 0.01):

| Parametro     | Wilcoxon CBD | Wilcoxon Placebo | Mann-Whitney (delta) |
|---------------|-------------:|-----------------:|---------------------:|
| Peso (kg)     |       0.3466 |           0.7126 |               0.6911 |
| RBC           |       0.0005 |           0.1880 |               0.1831 |
| HCT           |       0.0209 |           0.3135 |               0.5400 |
| Eosinofili %  |       0.0202 |           0.1551 |               0.6933 |
| Bilirubina    |       0.0154 |           0.0671 |               0.7622 |
| Creatinina    |       0.0544 |           0.0586 |               0.8098 |

Esito atteso complessivo: **nessun Mann-Whitney significativo** (nessuna differenza
dimostrata tra CBD e Placebo); risultati significativi solo intra-gruppo nel CBD per
RBC, HCT, eosinofili (in **aumento**, non in calo), eosinofili assoluti e bilirubina.
Se il codice produce un Mann-Whitney significativo sul peso o sui monociti, sta
riproducendo gli errori del vecchio file: fermarsi e verificare.

---

## 6. Cosa non fare

- Non sostituire i test non parametrici con t-test o ANOVA senza che l'utente lo chieda
  esplicitamente. Il protocollo della tesi è non parametrico.
- Non usare test a una coda per "far uscire" un risultato.
- Non rimuovere outlier senza un criterio dichiarato e concordato con l'utente.
- Non selezionare i parametri da riportare in base al p-value ottenuto: la tabella
  contiene **tutti** i parametri analizzati, significativi e non.
- Non scrivere conclusioni causali ("il CBD ha protetto i cani da...") a partire da un
  test di ipotesi. Descrivere il risultato, ipotizzare in una sezione separata.
- Non modificare il file Excel di origine. È di sola lettura.