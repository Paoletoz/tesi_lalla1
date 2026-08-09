# =====================================================================
# 99_validazione.R — Test di regressione contro i valori di riferimento
# ---------------------------------------------------------------------
# Confronta l'output della pipeline con i valori calcolati in modo
# indipendente (Python/SciPy) e riportati in CLAUDE.md §5. Se un
# controllo fallisce il codice ha un bug: si interrompe con errore.
# NON si allarga la tolleranza per "far passare" un test.
# =====================================================================

## --- Bootstrap: dati + risultati dei test ---------------------------
.carica <- function(nome) {
  cand <- c(file.path("R", nome), nome, file.path("..", "R", nome))
  f <- cand[file.exists(cand)][1]
  if (is.na(f)) stop(nome, " non trovato: eseguire dalla radice del progetto.")
  source(f)
}
if (!exists("estrai_coppie"))  .carica("_funzioni.R")
if (!exists("DATI"))           .carica("01_import_pulizia.R")
if (!exists("WILCOXON"))       invisible(capture.output(.carica("03_wilcoxon.R")))
if (!exists("MANN_WHITNEY"))   invisible(capture.output(.carica("04_mann_whitney.R")))

## --- Tolleranze ------------------------------------------------------
TOL_MEDIA <- 0.005   # medie riportate a 3 decimali in §5
TOL_P     <- 0.01    # tolleranza esplicita di §5 per i p-value

## --- Raccoglitore di controlli --------------------------------------
CTRL <- data.frame(controllo = character(), atteso = numeric(),
                   ottenuto = numeric(), tol = numeric(),
                   esito = character(), stringsAsFactors = FALSE)
aggiungi <- function(nome, atteso, ottenuto, tol) {
  ok <- !is.na(ottenuto) && abs(atteso - ottenuto) <= tol
  CTRL[nrow(CTRL) + 1, ] <<- list(nome, atteso, ottenuto, tol,
                                  if (ok) "OK" else "FALLITO")
  invisible(ok)
}

## --- Helper sui dati -------------------------------------------------
mediaPre  <- function(id, g) mean(estrai_coppie(DATI, id, g)$pre)
mediaPost <- function(id, g) mean(estrai_coppie(DATI, id, g)$post)
nCoppie   <- function(id, g) nrow(estrai_coppie(DATI, id, g))
pW  <- function(id, g) WILCOXON$p_grezzo[WILCOXON$id == id & WILCOXON$gruppo == g]
pMW <- function(id)    MANN_WHITNEY$p_grezzo[MANN_WHITNEY$id == id]

## --- 1) Controlli strutturali (§5) ----------------------------------
aggiungi("Righe totali",            63, nrow(DATI), 0)
aggiungi("n CBD (Treatment==1)",    32, sum(DATI$gruppo == "CBD"), 0)
aggiungi("n Placebo (Treatment==0)",31, sum(DATI$gruppo == "Placebo"), 0)
aggiungi("n coppie complete Peso — CBD",     32, nCoppie("peso","CBD"), 0)
aggiungi("n coppie complete Peso — Placebo", 29, nCoppie("peso","Placebo"), 0)
aggiungi("Media PRE Peso CBD",   27.397, mediaPre("peso","CBD"),  TOL_MEDIA)
aggiungi("Media POST Peso CBD",  27.881, mediaPost("peso","CBD"), TOL_MEDIA)
aggiungi("Media PRE Peso Placebo",26.774, mediaPre("peso","Placebo"), TOL_MEDIA)
aggiungi("Media PRE RBC CBD",     7.513, mediaPre("rbc","CBD"), TOL_MEDIA)
aggiungi("Media PRE HCT CBD",    49.410, mediaPre("hct","CBD"), TOL_MEDIA)

## --- 2) P-value di riferimento (§5), tolleranza ±0.01 ---------------
rif <- data.frame(
  id   = c("peso","rbc","hct","eos_pct","bil_tot","creat"),
  nome = c("Peso","RBC","HCT","Eosinofili %","Bilirubina","Creatinina"),
  wcbd = c(0.3466, 0.0005, 0.0209, 0.0202, 0.0154, 0.0544),
  wpla = c(0.7126, 0.1880, 0.3135, 0.1551, 0.0671, 0.0586),
  mw   = c(0.6911, 0.1831, 0.5400, 0.6933, 0.7622, 0.8098),
  stringsAsFactors = FALSE)
for (k in seq_len(nrow(rif))) {
  aggiungi(paste0("Wilcoxon CBD — ", rif$nome[k]),     rif$wcbd[k], pW(rif$id[k],"CBD"),     TOL_P)
  aggiungi(paste0("Wilcoxon Placebo — ", rif$nome[k]), rif$wpla[k], pW(rif$id[k],"Placebo"), TOL_P)
  aggiungi(paste0("Mann-Whitney — ", rif$nome[k]),     rif$mw[k],   pMW(rif$id[k]),          TOL_P)
}

## --- Stampa dei controlli numerici ----------------------------------
cat("\n=====================================================================\n")
cat(" VALIDAZIONE — confronto con i valori di riferimento (CLAUDE.md §5)\n")
cat("=====================================================================\n")
vis <- CTRL
vis$atteso   <- round(vis$atteso, 4)
vis$ottenuto <- round(vis$ottenuto, 4)
print(knitr::kable(vis, format = "simple", row.names = FALSE))

## --- 3) Esito complessivo qualitativo (§5) --------------------------
# a) Nessun Mann-Whitney significativo (p grezzo)
mw_sig <- MANN_WHITNEY$parametro[!is.na(MANN_WHITNEY$p_grezzo) &
                                 MANN_WHITNEY$p_grezzo < ALPHA]
ok_mw <- length(mw_sig) == 0
# b) I significativi Wilcoxon CBD sono ESATTAMENTE i 5 attesi
cbd_sig <- sort(WILCOXON$id[WILCOXON$gruppo == "CBD" &
                            !is.na(WILCOXON$p_grezzo) &
                            WILCOXON$p_grezzo < ALPHA])
cbd_atteso <- sort(c("rbc","hct","eos_pct","eos_abs","bil_tot"))
ok_cbd <- identical(cbd_sig, cbd_atteso)

cat("\n--- Esito complessivo qualitativo (§5) ---\n")
cat(sprintf("  Mann-Whitney significativi (p grezzo): %s  ->  %s\n",
            if (length(mw_sig)) paste(mw_sig, collapse=", ") else "nessuno",
            if (ok_mw) "OK (atteso: nessuno)" else "FALLITO"))
cat(sprintf("  Wilcoxon CBD significativi: %s\n", paste(cbd_sig, collapse=", ")))
cat(sprintf("     atteso: %s  ->  %s\n", paste(cbd_atteso, collapse=", "),
            if (ok_cbd) "OK" else "FALLITO"))

# Nota informativa (non bloccante): significativi intra-Placebo.
pla_sig <- WILCOXON[WILCOXON$gruppo == "Placebo" & !is.na(WILCOXON$p_grezzo) &
                    WILCOXON$p_grezzo < ALPHA, c("parametro","n","p_grezzo","p_fdr")]
if (nrow(pla_sig)) {
  cat("\n  NOTA (non bloccante): significativi intra-Placebo su p grezzo:\n")
  for (k in seq_len(nrow(pla_sig)))
    cat(sprintf("     %-8s n=%d  p=%.4f  p_FDR=%.4f  (non significativo dopo FDR)\n",
                pla_sig$parametro[k], pla_sig$n[k], pla_sig$p_grezzo[k], pla_sig$p_fdr[k]))
}

## --- Verdetto finale -------------------------------------------------
n_fall <- sum(CTRL$esito == "FALLITO")
tutto_ok <- n_fall == 0 && ok_mw && ok_cbd
cat("\n=====================================================================\n")
if (tutto_ok) {
  cat(" VALIDAZIONE SUPERATA: tutti i controlli numerici (", nrow(CTRL),
      ") e qualitativi corrispondono a §5.\n", sep = "")
  cat("=====================================================================\n")
} else {
  cat(" VALIDAZIONE FALLITA:", n_fall, "controlli numerici fuori tolleranza",
      if (!ok_mw) "; Mann-Whitney inattesi" else "",
      if (!ok_cbd) "; set significativi CBD inatteso" else "", "\n")
  cat("=====================================================================\n")
  stop("Validazione fallita: NON consegnare. Indagare la causa (CLAUDE.md §5).")
}
