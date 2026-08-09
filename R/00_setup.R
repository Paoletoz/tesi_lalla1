# =====================================================================
# 00_setup.R  —  Pacchetti, opzioni, percorsi, costanti
# Studio CBD vs Placebo — analisi non parametrica pre/post (tesi)
# ---------------------------------------------------------------------
# Sourced da tutti gli altri script. Idempotente: puo' essere eseguito
# piu' volte senza effetti collaterali.
# =====================================================================

## --- Pacchetti -------------------------------------------------------
pacchetti <- c("readxl", "dplyr", "tidyr", "rstatix",
               "coin", "ggplot2", "openxlsx", "knitr")
mancanti <- pacchetti[!vapply(pacchetti, requireNamespace,
                              logical(1), quietly = TRUE)]
if (length(mancanti)) {
  stop("Pacchetti mancanti: ", paste(mancanti, collapse = ", "),
       "\nInstallare con: install.packages(c(",
       paste(sprintf('"%s"', mancanti), collapse = ", "), "))")
}
suppressPackageStartupMessages({
  library(readxl);  library(dplyr);   library(tidyr)
  library(rstatix); library(coin);    library(ggplot2)
  library(openxlsx); library(knitr)
})

## --- Opzioni globali -------------------------------------------------
options(stringsAsFactors = FALSE)
options(scipen = 999)     # niente notazione scientifica
options(OutDec = ".")     # punto come separatore decimale nell'output
set.seed(20260614)        # riproducibilita' (ove entrasse casualita')

## --- Radice del progetto --------------------------------------------
# Risale l'albero delle cartelle finche' trova '.claude': funziona sia
# lanciando dalla radice sia dalla cartella R/.
trova_radice <- function(start = getwd()) {
  d <- normalizePath(start, winslash = "/", mustWork = FALSE)
  repeat {
    if (dir.exists(file.path(d, ".claude"))) return(d)
    su <- dirname(d)
    if (identical(su, d))
      stop("Radice del progetto non trovata (nessuna cartella '.claude' ",
           "risalendo da ", start, ")")
    d <- su
  }
}
if (!exists("PROJ_ROOT")) PROJ_ROOT <- trova_radice()

## --- File dati (SOLA LETTURA) ---------------------------------------
# CLAUDE.md §4 prescrive la cartella dati/, ma nel repository il file si
# trova in excel/. Si prova prima dati/, poi excel/. La sorgente NON va
# mai spostata, duplicata o modificata.
.nome_file_dati <- "Dati per Wilcoxon e Mann Whitney 14.06.26.xlsx"
.candidati_dati <- file.path(PROJ_ROOT, c("dati", "excel"), .nome_file_dati)
FILE_DATI <- .candidati_dati[file.exists(.candidati_dati)][1]
if (is.na(FILE_DATI))
  stop("File dati non trovato. Cercato in:\n  ",
       paste(.candidati_dati, collapse = "\n  "))
FOGLIO_DATI <- "Foglio1"

## --- Cartelle di progetto -------------------------------------------
DIR_CONFIG  <- file.path(PROJ_ROOT, "config")
DIR_OUTPUT  <- file.path(PROJ_ROOT, "output")
DIR_TABELLE <- file.path(DIR_OUTPUT, "tabelle")
DIR_FIGURE  <- file.path(DIR_OUTPUT, "figure")
for (d in c(DIR_OUTPUT, DIR_TABELLE, DIR_FIGURE))
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)

FILE_DIZIONARIO <- file.path(DIR_CONFIG, "dizionario_parametri.csv")
if (!file.exists(FILE_DIZIONARIO))
  stop("Dizionario dei parametri non trovato: ", FILE_DIZIONARIO)

## --- Costanti statistiche -------------------------------------------
ALPHA      <- 0.05
# Codifica gruppi (CLAUDE.md §2): Treatment 1 = CBD, 0 = Placebo.
LIV_GRUPPO <- c("CBD", "Placebo")
# Soglia (per gruppo) sotto la quale si segnala bassa numerosita' delle
# coppie complete: e' la n che entra nel test intra-gruppo, non il totale.
SOGLIA_N_BASSA <- 10
# Quota di coppie mancanti oltre la quale si segnala l'elevata perdita di
# dati (frazione delle 63 coppie potenzialmente osservabili).
SOGLIA_MANCANTI_FRAZ <- 0.5

## --- Log -------------------------------------------------------------
cat("[00_setup] Radice progetto :", PROJ_ROOT, "\n")
cat("[00_setup] File dati        :", FILE_DATI, "\n")
if (basename(dirname(FILE_DATI)) != "dati")
  cat("[00_setup] NOTA: il file dati e' in '", basename(dirname(FILE_DATI)),
      "/', non in 'dati/' come da CLAUDE.md §4 (sorgente non modificata).\n",
      sep = "")
