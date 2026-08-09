# =====================================================================
# 01_import_pulizia.R — Import, coercizione numerica, report qualita'
# ---------------------------------------------------------------------
# - Legge il foglio come TESTO (nessuna coercizione silenziosa di readxl)
# - Verifica la struttura contro CLAUDE.md §2
# - Seleziona le coppie PRE/POST per INDICE (dizionario), mai per nome:
#   le intestazioni usano due caratteri "micro" diversi (U+00B5 / U+03BC)
# - Converte a numerico tracciando ogni cella persa (vuota o testo)
# - Produce il report di qualita' dei dati (a schermo + file)
#
# Espone nell'ambiente globale: DATI, DIZ, GRUPPO,
#   REPORT_QUALITA, REPORT_TOKEN
# Idempotente. Eseguibile da solo (Rscript R/01_import_pulizia.R).
# =====================================================================

## --- Bootstrap: carica il setup se non gia' caricato -----------------
if (!exists("PROJ_ROOT")) {
  .cand <- c(file.path("R", "00_setup.R"), "00_setup.R",
             file.path("..", "R", "00_setup.R"))
  .s <- .cand[file.exists(.cand)][1]
  if (is.na(.s)) stop("00_setup.R non trovato: eseguire dalla radice del progetto.")
  source(.s)
}

## --- Lettura grezza come testo --------------------------------------
message("[01] Lettura file: ", FILE_DATI)
grezzo <- readxl::read_excel(FILE_DATI, sheet = FOGLIO_DATI,
                             col_types = "text", .name_repair = "minimal")
grezzo <- as.data.frame(grezzo, check.names = FALSE)

## --- Verifiche strutturali (CLAUDE.md §2) ---------------------------
# Se qualcosa non torna ci si ferma: non si aggiusta in silenzio.
if (nrow(grezzo) != 63)
  stop("Righe attese 63, trovate ", nrow(grezzo), ".")
if (ncol(grezzo) != 90)
  stop("Colonne attese 90, trovate ", ncol(grezzo), ".")
if (names(grezzo)[5] != "Treatment")
  stop("La colonna 5 doveva essere 'Treatment', e' '", names(grezzo)[5], "'.")
# I due caratteri micro dove attesi (col 34 = U+00B5, col 54 = U+03BC)
if (!grepl("µ", names(grezzo)[34], fixed = TRUE))
  warning("[01] Col 34: MICRO SIGN (U+00B5) atteso non trovato nell'intestazione.")
if (!grepl("μ", names(grezzo)[54], fixed = TRUE))
  warning("[01] Col 54: GREEK MU (U+03BC) atteso non trovato nell'intestazione.")

## --- Normalizzazione dei nomi (documentata) -------------------------
# Unifico i due micro su U+03BC per leggibilita'. La SELEZIONE resta
# sempre per indice: la normalizzazione e' solo cosmetica.
nomi_orig <- names(grezzo)
names(grezzo) <- gsub("µ", "μ", names(grezzo), fixed = TRUE)
n_nomi_norm <- sum(nomi_orig != names(grezzo))
message("[01] Intestazioni con U+00B5 normalizzate a U+03BC: ", n_nomi_norm)

## --- Gruppo di trattamento ------------------------------------------
trt <- trimws(grezzo[["Treatment"]])
val_inattesi <- setdiff(unique(trt), c("0", "1"))
if (length(val_inattesi))
  stop("Valori inattesi in 'Treatment': ", paste(val_inattesi, collapse = ", "))
GRUPPO <- factor(ifelse(trt == "1", "CBD", "Placebo"), levels = LIV_GRUPPO)
n_cbd <- sum(GRUPPO == "CBD"); n_pla <- sum(GRUPPO == "Placebo")
message(sprintf("[01] Gruppi: CBD = %d, Placebo = %d (attesi 32 e 31)", n_cbd, n_pla))
if (n_cbd != 32 || n_pla != 31)
  stop("Numerosita' dei gruppi diversa dall'attesa: interrompo.")

## --- Coercizione numerica con tracciamento --------------------------
# Restituisce i valori numerici e la diagnostica delle celle perse.
# 'vuoto'    = cella gia' mancante (NA o stringa vuota)
# 'testo_na' = cella NON vuota che non si converte in numero (es. "<40")
coerci_numerico <- function(x) {
  originale <- x
  g <- trimws(x)
  g[is.na(g)] <- ""
  vuoto <- g == ""
  # virgola decimale -> punto (per numeri eventualmente salvati come testo)
  p <- gsub(",", ".", g, fixed = TRUE)
  num <- suppressWarnings(as.numeric(p))
  testo_na <- !vuoto & is.na(num)
  list(valori     = num,
       n_vuoti    = sum(vuoto),
       n_testo_na = sum(testo_na),
       token      = if (any(testo_na)) trimws(originale[testo_na]) else character(0))
}

## --- Dizionario dei parametri ---------------------------------------
DIZ <- read.csv(FILE_DIZIONARIO, fileEncoding = "UTF-8",
                stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(DIZ) != 26)
  stop("Il dizionario deve contenere 26 parametri, ne ha ", nrow(DIZ), ".")
DIZ <- DIZ[order(DIZ$ordine), ]

## --- Costruzione dataset pulito (formato largo) + report ------------
DATI <- data.frame(
  dog    = grezzo[["Dogs"]],
  dog_id = grezzo[["Dog ID"]],
  box    = grezzo[["Box"]],
  gruppo = GRUPPO,
  stringsAsFactors = FALSE
)

righe_report <- vector("list", nrow(DIZ))
righe_token  <- list()

for (i in seq_len(nrow(DIZ))) {
  cp <- DIZ$col_pre[i]; cq <- DIZ$col_post[i]
  pre  <- coerci_numerico(grezzo[[cp]])
  post <- coerci_numerico(grezzo[[cq]])
  DATI[[paste0(DIZ$id[i], "_pre")]]  <- pre$valori
  DATI[[paste0(DIZ$id[i], "_post")]] <- post$valori

  comp <- !is.na(pre$valori) & !is.na(post$valori)
  cc_cbd <- sum(comp & GRUPPO == "CBD")
  cc_pla <- sum(comp & GRUPPO == "Placebo")
  cc_tot <- sum(comp)

  # Avvisi di numerosita': (a) n per-gruppo bassa (entra nel test intra-
  # gruppo); (b) piu' della meta' delle coppie potenziali mancanti.
  note <- character(0)
  if (min(cc_cbd, cc_pla) < SOGLIA_N_BASSA)
    note <- c(note, sprintf("numerosita' per-gruppo bassa (CBD=%d, Placebo=%d)",
                            cc_cbd, cc_pla))
  if (cc_tot < SOGLIA_MANCANTI_FRAZ * nrow(grezzo))
    note <- c(note, sprintf("dati mancanti elevati (coppie complete tot=%d/%d)",
                            cc_tot, nrow(grezzo)))
  nota <- paste(note, collapse = "; ")

  righe_report[[i]] <- data.frame(
    ordine = DIZ$ordine[i], parametro = DIZ$parametro[i],
    unita = DIZ$unita[i], categoria = DIZ$categoria[i],
    col_pre = cp, col_post = cq,
    n_pre_presenti = sum(!is.na(pre$valori)),
    n_post_presenti = sum(!is.na(post$valori)),
    pre_vuoti = pre$n_vuoti, pre_testo_na = pre$n_testo_na,
    post_vuoti = post$n_vuoti, post_testo_na = post$n_testo_na,
    coppie_complete_CBD = cc_cbd,
    coppie_complete_Placebo = cc_pla,
    coppie_complete_tot = cc_tot,
    nota = nota, stringsAsFactors = FALSE)

  # dettaglio token testuali -> NA, per parametro e tempo
  agg <- function(tempo, tok) {
    if (!length(tok)) return(NULL)
    tb <- table(tok)
    data.frame(parametro = DIZ$parametro[i], tempo = tempo,
               col = if (tempo == "PRE") cp else cq,
               token = names(tb), n = as.integer(tb),
               trattamento = "convertito in NA", stringsAsFactors = FALSE)
  }
  righe_token <- c(righe_token, list(agg("PRE", pre$token), agg("POST", post$token)))
}

REPORT_QUALITA <- do.call(rbind, righe_report)
righe_token <- righe_token[!vapply(righe_token, is.null, logical(1))]
REPORT_TOKEN <- if (length(righe_token)) do.call(rbind, righe_token) else
  data.frame(parametro = character(0), tempo = character(0), col = integer(0),
             token = character(0), n = integer(0), trattamento = character(0))

## --- Salvataggio report ---------------------------------------------
f_qual  <- file.path(DIR_TABELLE, "01_report_qualita_dati.csv")
f_token <- file.path(DIR_TABELLE, "01_report_celle_non_numeriche.csv")
write.csv(REPORT_QUALITA, f_qual, row.names = FALSE, fileEncoding = "UTF-8")
write.csv(REPORT_TOKEN,  f_token, row.names = FALSE, fileEncoding = "UTF-8")

## --- Stampa a schermo (solo se eseguito come script, non se sourced) -
stampa_report_qualita <- function() {
  cat("\n=====================================================================\n")
  cat(" REPORT DI QUALITA' DEI DATI — CBD vs Placebo\n")
  cat("=====================================================================\n")
  cat(sprintf("File          : %s\n", basename(FILE_DATI)))
  cat(sprintf("Cartella      : %s/\n", basename(dirname(FILE_DATI))))
  cat(sprintf("Righe (cani)  : %d   |   Colonne: %d\n", nrow(grezzo), ncol(grezzo)))
  cat(sprintf("Gruppi        : CBD = %d, Placebo = %d\n", n_cbd, n_pla))
  cat(sprintf("Nomi normalizzati (U+00B5 -> U+03BC): %d intestazioni\n", n_nomi_norm))
  cat(sprintf("Parametri     : %d (coppie PRE/POST selezionate per indice)\n", nrow(DIZ)))

  vista <- REPORT_QUALITA[, c("parametro", "n_pre_presenti", "n_post_presenti",
                              "coppie_complete_CBD", "coppie_complete_Placebo",
                              "coppie_complete_tot")]
  vista$testo_NA <- REPORT_QUALITA$pre_testo_na + REPORT_QUALITA$post_testo_na
  names(vista) <- c("Parametro", "n PRE", "n POST", "coppie CBD",
                    "coppie Plac", "coppie tot", "testo->NA")
  cat("\n--- Presenza dati e coppie complete (per test intra-gruppo) ---\n")
  print(knitr::kable(vista, format = "simple", row.names = FALSE))

  cat("\n--- Celle con testo non numerico (convertite in NA) ---\n")
  if (nrow(REPORT_TOKEN)) {
    print(knitr::kable(REPORT_TOKEN[, c("parametro","tempo","col","token","n")],
                       format = "simple", row.names = FALSE))
  } else {
    cat("Nessuna cella testuale trovata nei parametri analizzati.\n")
  }

  bassa <- REPORT_QUALITA[REPORT_QUALITA$nota != "", c("parametro", "nota")]
  cat("\n--- Avvisi di numerosita' / dati mancanti ---\n")
  if (nrow(bassa)) {
    for (k in seq_len(nrow(bassa)))
      cat(sprintf("  ! %-20s %s\n", bassa$parametro[k], bassa$nota[k]))
  } else cat("  Nessun parametro sotto le soglie.\n")

  cat("\nFile salvati:\n  ", f_qual, "\n  ", f_token, "\n", sep = "")
  cat("=====================================================================\n")
}

# Il report viene stampato a ogni esecuzione di questo script. Gli script
# a valle (02-06) caricano i dati con la guardia if(!exists("DATI")), quindi
# non ri-eseguono 01 e non duplicano la stampa quando i dati sono gia' in
# memoria (es. dentro run_all.R).
stampa_report_qualita()

