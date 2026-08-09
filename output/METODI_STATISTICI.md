# Metodi statistici

*Sezione pronta da adattare per la tesi. Descrive cosa è stato fatto e perché.
Terminologia inferenziale rigorosa: con p ≥ 0,05 si scrive «non si rifiuta H₀»,
mai «si accetta H₀».*

## Disegno dello studio e unità statistica

Studio controllato pre-post su 63 cani di canile, assegnati a due gruppi:
trattamento con olio di CBD (n = 32) e placebo (n = 31). Ogni cane costituisce
l'unità statistica ed è stato misurato in due tempi — prima (PRE) e dopo (POST)
il trattamento — su parametri fisici, ematologici, biochimici e di stress
ossidativo (26 parametri complessivi). L'assegnazione al gruppo è codificata
dalla variabile `Treatment` (1 = CBD, 0 = Placebo).

## Trattamento dei dati mancanti

Per ogni parametro l'analisi è stata condotta sulle sole **coppie complete**,
cioè i cani con valore PRE **e** POST entrambi presenti. Le celle contenenti
testo non numerico (per esempio valori sotto il limite di rilevazione come
«<40», annotazioni di laboratorio, campi vuoti) sono state convertite in dato
mancante (`NA`) **senza alcuna imputazione**; il numero di celle così trattate
è documentato in un report di qualità dei dati. Di conseguenza la numerosità
effettiva varia da parametro a parametro ed è **riportata test per test**.

Le statistiche descrittive di ciascun gruppo/tempo sono state calcolate sullo
**stesso sottoinsieme di coppie complete** usato per il test corrispondente,
così che la numerosità della tabella coincida sempre con quella del test.

Due parametri di stress ossidativo, **dRoms** e **Oxy**, presentano una quota
elevata di dati mancanti (rispettivamente 17 e 31 coppie complete sui 63
soggetti, con appena 6 coppie complete per dRoms nel gruppo CBD). I relativi
risultati sono riportati per completezza ma vanno interpretati con cautela per
la bassa numerosità.

## Statistiche descrittive

Trattandosi di analisi non parametrica, la **mediana con intervallo
interquartile (Q1–Q3)** è stata adottata come statistica di sintesi principale;
media e deviazione standard sono riportate a corredo e non in sua sostituzione.
Per ciascun parametro, gruppo e tempo sono riportati n, mediana, Q1, Q3, media,
deviazione standard, minimo e massimo.

## Confronto intra-gruppo (PRE vs POST): test di Wilcoxon dei ranghi con segno

Per verificare la presenza di una variazione pre-post all'interno di ciascun
gruppo è stato impiegato il **test di Wilcoxon dei ranghi con segno per dati
appaiati**, applicato separatamente al gruppo CBD e al gruppo Placebo.

- H₀: non vi è differenza tra pre e post trattamento nel singolo individuo.
- H₁: vi è differenza tra pre e post trattamento nel singolo individuo.

Il test è stato eseguito in formulazione **a due code** con α = 0,05,
utilizzando l'**approssimazione normale** (`exact = FALSE`) con **correzione di
continuità** (`correct = TRUE`). L'approssimazione asintotica è la scelta
obbligata in presenza di ex aequo (ranghi ripetuti) e di differenze nulle, con
cui il test esatto non è applicabile. Dove il test non era eseguibile (per
esempio con tutte le differenze pari a zero) il risultato è riportato come `NA`
con la relativa motivazione, mai come p-value approssimato.

## Confronto tra gruppi: test di Mann-Whitney U sui delta

Per verificare una differenza tra CBD e Placebo è stato impiegato il **test di
Mann-Whitney U** (Wilcoxon per campioni indipendenti), applicato **alla
variazione individuale** Δ = POST − PRE e non ai soli valori POST. Confrontare
i delta neutralizza le eventuali differenze basali tra i gruppi.

- H₀: non vi è differenza tra il gruppo CBD e il gruppo Placebo.
- H₁: vi è differenza tra il gruppo CBD e il gruppo Placebo.

Anche in questo caso: due code, α = 0,05, `exact = FALSE`, `correct = TRUE`.

## Dimensione dell'effetto

Per ogni test è stata calcolata la dimensione dell'effetto **r = |Z| / √N**,
dove Z è la statistica standardizzata del test e N la numerosità (numero di
coppie per il test appaiato; numerosità totale per il test tra gruppi). I valori
sono stati ottenuti con `rstatix::wilcox_effsize()` come fonte primaria e con
`coin::wilcoxsign_test()` / `coin::wilcox_test()` come controllo incrociato
indipendente dello Z. Sono state adottate le soglie convenzionali: r ≈ 0,1
effetto piccolo, 0,3 medio, 0,5 grande.

## Correzione per confronti multipli

Sono stati eseguiti 26 parametri × 3 test = **78 test**. A questa numerosità,
per solo effetto del caso, ci si attendono circa 4 risultati con p < 0,05. Per
controllare la proporzione di falsi positivi è stata applicata la correzione
**FDR di Benjamini-Hochberg**, calcolata **separatamente per ciascuna famiglia
di test** (Wilcoxon CBD, Wilcoxon Placebo, Mann-Whitney). Nelle tabelle sono
riportati **sia il p-value grezzo sia il p-value corretto**, e per ciascun test
una doppia dicitura di esito: la decisione su H₀ al p grezzo e quella al p
corretto (FDR). I p-value sono riportati a 3–4 decimali; valori inferiori a
0,001 sono indicati come «< 0,001».

## Software

Tutte le analisi sono state condotte in **R versione 4.5.3** con i pacchetti
`readxl` 1.5.0 (import), `dplyr` 1.2.1 e `tidyr` 1.3.2 (manipolazione),
`rstatix` 1.1.0 e `coin` 1.4-5 (test ed effect size), `ggplot2` 4.0.2 (grafici),
`openxlsx` 4.2.8.1 e `knitr` 1.51 (tabelle). Il codice è organizzato in script
numerati, riproducibili e indipendenti, con un test di validazione automatico
che confronta i risultati con valori di riferimento calcolati in modo
indipendente; l'ambiente completo di esecuzione è archiviato in
`output/sessionInfo.txt`.

## Nota terminologica

Il termine «significativo» è usato esclusivamente in senso statistico. Con
p ≥ 0,05 si conclude che **non si rifiuta H₀**: l'assenza di prova di una
differenza non costituisce prova della sua assenza. Le interpretazioni
biologiche o cliniche sono trattate separatamente e formulate come ipotesi, non
come conclusioni causali derivate da un test di ipotesi.
