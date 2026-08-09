# =====================================================================
# 05_tabelle.R — Tabella completa dei risultati per la tesi
# ---------------------------------------------------------------------
# Unisce descrittive (02), Wilcoxon (03) e Mann-Whitney (04) in un'unica
# tabella con TUTTI i 26 parametri (significativi e non). Produce:
#   - 05_tabella_completa.csv        (master numerico, fonte di verita')
#   - 05_tabella_completa.xlsx       (3 fogli: numerico, formato tesi, legenda)
# Per ciascun test riporta p grezzo E p corretto (FDR-BH), effect size r,
# e la DOPPIA dicitura di esito: esito su p grezzo ed esito su p FDR.
# Idempotente.
# =====================================================================

## --- Bootstrap: dati + risultati ------------------------------------
.carica <- function(nome) {
  cand <- c(file.path("R", nome), nome, file.path("..", "R", nome))
  f <- cand[file.exists(cand)][1]
  if (is.na(f)) stop(nome, " non trovato: eseguire dalla radice del progetto.")
  source(f)
}
if (!exists("estrai_coppie"))  .carica("_funzioni.R")
if (!exists("DATI"))           .carica("01_import_pulizia.R")
if (!exists("DESCRITTIVE"))    invisible(capture.output(.carica("02_descrittive.R")))
if (!exists("WILCOXON"))       invisible(capture.output(.carica("03_wilcoxon.R")))
if (!exists("MANN_WHITNEY"))   invisible(capture.output(.carica("04_mann_whitney.R")))

message("[05] Assemblaggio tabella completa dei risultati...")

## --- Accessori -------------------------------------------------------
getd  <- function(id, g, tempo, stat)
  DESCRITTIVE[DESCRITTIVE$id == id & DESCRITTIVE$gruppo == g &
              DESCRITTIVE$tempo == tempo, stat]
getW  <- function(id, g, col) WILCOXON[WILCOXON$id == id & WILCOXON$gruppo == g, col]
getMW <- function(id, col)    MANN_WHITNEY[MANN_WHITNEY$id == id, col]

## --- Costruzione tabella master (numerica) --------------------------
righe <- list()
for (i in seq_len(nrow(DIZ))) {
  id <- DIZ$id[i]
  r <- data.frame(
    ordine = DIZ$ordine[i], parametro = DIZ$parametro[i],
    unita = DIZ$unita[i], categoria = DIZ$categoria[i],
    n_cbd = getd(id, "CBD", "PRE", "n"), n_placebo = getd(id, "Placebo", "PRE", "n"),
    # --- descrittive CBD ---
    cbd_pre_mediana  = getd(id,"CBD","PRE","mediana"),  cbd_pre_Q1 = getd(id,"CBD","PRE","Q1"),
    cbd_pre_Q3       = getd(id,"CBD","PRE","Q3"),        cbd_pre_media = getd(id,"CBD","PRE","media"),
    cbd_post_mediana = getd(id,"CBD","POST","mediana"),  cbd_post_Q1 = getd(id,"CBD","POST","Q1"),
    cbd_post_Q3      = getd(id,"CBD","POST","Q3"),       cbd_post_media = getd(id,"CBD","POST","media"),
    # --- descrittive Placebo ---
    pla_pre_mediana  = getd(id,"Placebo","PRE","mediana"),  pla_pre_Q1 = getd(id,"Placebo","PRE","Q1"),
    pla_pre_Q3       = getd(id,"Placebo","PRE","Q3"),        pla_pre_media = getd(id,"Placebo","PRE","media"),
    pla_post_mediana = getd(id,"Placebo","POST","mediana"),  pla_post_Q1 = getd(id,"Placebo","POST","Q1"),
    pla_post_Q3      = getd(id,"Placebo","POST","Q3"),       pla_post_media = getd(id,"Placebo","POST","media"),
    # --- Wilcoxon CBD ---
    wcbd_variazione = getW(id,"CBD","variazione"),
    p_wilcoxon_cbd  = getW(id,"CBD","p_grezzo"), p_fdr_wilcoxon_cbd = getW(id,"CBD","p_fdr"),
    r_wilcoxon_cbd  = getW(id,"CBD","r"),
    # --- Wilcoxon Placebo ---
    wpla_variazione = getW(id,"Placebo","variazione"),
    p_wilcoxon_placebo = getW(id,"Placebo","p_grezzo"), p_fdr_wilcoxon_placebo = getW(id,"Placebo","p_fdr"),
    r_wilcoxon_placebo = getW(id,"Placebo","r"),
    # --- Mann-Whitney (delta) ---
    p_mann_whitney = getMW(id,"p_grezzo"), p_fdr_mann_whitney = getMW(id,"p_fdr"),
    r_mann_whitney = getMW(id,"r"),
    row.names = NULL, stringsAsFactors = FALSE)
  righe[[i]] <- r
}
TAB <- do.call(rbind, righe)

## --- Doppio esito (grezzo / FDR) per ciascun test -------------------
TAB$esito_wilcoxon_cbd_grezzo     <- vapply(TAB$p_wilcoxon_cbd, esito_h0, character(1))
TAB$esito_wilcoxon_cbd_fdr        <- vapply(TAB$p_fdr_wilcoxon_cbd, esito_h0, character(1))
TAB$esito_wilcoxon_placebo_grezzo <- vapply(TAB$p_wilcoxon_placebo, esito_h0, character(1))
TAB$esito_wilcoxon_placebo_fdr    <- vapply(TAB$p_fdr_wilcoxon_placebo, esito_h0, character(1))
TAB$esito_mann_whitney_grezzo     <- vapply(TAB$p_mann_whitney, esito_h0, character(1))
TAB$esito_mann_whitney_fdr        <- vapply(TAB$p_fdr_mann_whitney, esito_h0, character(1))
TAB <- TAB[order(TAB$ordine), ]

## --- Arrotondamenti (solo cosmetici; i p NON sotto 0.001 restano interi) -
arr <- function(x, d) ifelse(is.na(x), NA, round(x, d))
col_desc <- grep("_(mediana|Q1|Q3|media)$", names(TAB), value = TRUE)
col_p    <- grep("^p_", names(TAB), value = TRUE)
col_r    <- grep("^r_", names(TAB), value = TRUE)
for (cc in col_desc) TAB[[cc]] <- arr(TAB[[cc]], 3)
for (cc in col_p)    TAB[[cc]] <- arr(TAB[[cc]], 4)
for (cc in col_r)    TAB[[cc]] <- arr(TAB[[cc]], 3)

## --- Salvataggio CSV master -----------------------------------------
f_csv <- file.path(DIR_TABELLE, "05_tabella_completa.csv")
write.csv(TAB, f_csv, row.names = FALSE, fileEncoding = "UTF-8")
message("[05] CSV master salvato: ", f_csv, "  (", nrow(TAB), " parametri x ", ncol(TAB), " colonne)")

## --- Versione formattata per la tesi --------------------------------
# p secondo CLAUDE.md §1.5: 4 decimali, "< 0.001" sotto 0.001.
fmt_p <- function(p) ifelse(is.na(p), "NA",
                     ifelse(p < 0.001, "< 0.001", formatC(p, format = "f", digits = 4)))
fmt_mq <- function(med, q1, q3) ifelse(is.na(med), "NA",
            sprintf("%.2f [%.2f–%.2f]", med, q1, q3))
# r formattato come "0.618 (grande)"; NA -> "NA"
fmt_r <- function(r, m) ifelse(is.na(r), "NA",
            paste0(formatC(r, format = "f", digits = 3), " (", m, ")"))

# magnitudo allineate all'ordine delle righe di TAB
magn_wcbd <- vapply(TAB$ordine, function(o)
  WILCOXON$magnitudo[WILCOXON$ordine == o & WILCOXON$gruppo == "CBD"], character(1))
magn_wpla <- vapply(TAB$ordine, function(o)
  WILCOXON$magnitudo[WILCOXON$ordine == o & WILCOXON$gruppo == "Placebo"], character(1))
magn_mw   <- MANN_WHITNEY$magnitudo[match(TAB$ordine, MANN_WHITNEY$ordine)]

TAB_FMT <- data.frame(
  Parametro = TAB$parametro, Unita = TAB$unita, Categoria = TAB$categoria,
  `n CBD` = TAB$n_cbd, `n Placebo` = TAB$n_placebo,
  `CBD PRE  mediana [Q1-Q3]`  = fmt_mq(TAB$cbd_pre_mediana,  TAB$cbd_pre_Q1,  TAB$cbd_pre_Q3),
  `CBD POST mediana [Q1-Q3]`  = fmt_mq(TAB$cbd_post_mediana, TAB$cbd_post_Q1, TAB$cbd_post_Q3),
  `CBD media PRE`  = round(TAB$cbd_pre_media, 3),  `CBD media POST`  = round(TAB$cbd_post_media, 3),
  `Placebo PRE  mediana [Q1-Q3]`  = fmt_mq(TAB$pla_pre_mediana,  TAB$pla_pre_Q1,  TAB$pla_pre_Q3),
  `Placebo POST mediana [Q1-Q3]`  = fmt_mq(TAB$pla_post_mediana, TAB$pla_post_Q1, TAB$pla_post_Q3),
  `Placebo media PRE`  = round(TAB$pla_pre_media, 3),  `Placebo media POST`  = round(TAB$pla_post_media, 3),
  # Wilcoxon CBD
  `Wilcoxon CBD variazione` = TAB$wcbd_variazione,
  `Wilcoxon CBD p`     = fmt_p(TAB$p_wilcoxon_cbd),
  `Wilcoxon CBD p FDR` = fmt_p(TAB$p_fdr_wilcoxon_cbd),
  `Wilcoxon CBD r`     = fmt_r(TAB$r_wilcoxon_cbd, magn_wcbd),
  `Wilcoxon CBD esito (grezzo)` = TAB$esito_wilcoxon_cbd_grezzo,
  `Wilcoxon CBD esito (FDR)`    = TAB$esito_wilcoxon_cbd_fdr,
  # Wilcoxon Placebo
  `Wilcoxon Placebo variazione` = TAB$wpla_variazione,
  `Wilcoxon Placebo p`     = fmt_p(TAB$p_wilcoxon_placebo),
  `Wilcoxon Placebo p FDR` = fmt_p(TAB$p_fdr_wilcoxon_placebo),
  `Wilcoxon Placebo r`     = fmt_r(TAB$r_wilcoxon_placebo, magn_wpla),
  `Wilcoxon Placebo esito (grezzo)` = TAB$esito_wilcoxon_placebo_grezzo,
  `Wilcoxon Placebo esito (FDR)`    = TAB$esito_wilcoxon_placebo_fdr,
  # Mann-Whitney
  `Mann-Whitney p`     = fmt_p(TAB$p_mann_whitney),
  `Mann-Whitney p FDR` = fmt_p(TAB$p_fdr_mann_whitney),
  `Mann-Whitney r`     = fmt_r(TAB$r_mann_whitney, magn_mw),
  `Mann-Whitney esito (grezzo)` = TAB$esito_mann_whitney_grezzo,
  `Mann-Whitney esito (FDR)`    = TAB$esito_mann_whitney_fdr,
  check.names = FALSE, stringsAsFactors = FALSE)

f_fmt <- file.path(DIR_TABELLE, "05_tabella_tesi_formattata.csv")
write.csv(TAB_FMT, f_fmt, row.names = FALSE, fileEncoding = "UTF-8")
message("[05] CSV formato tesi salvato: ", f_fmt)

## --- Legenda delle colonne ------------------------------------------
LEGENDA <- data.frame(
  Colonna = c(
    "n_cbd / n_placebo",
    "*_mediana / *_Q1 / *_Q3", "*_media",
    "wcbd_variazione / wpla_variazione",
    "p_wilcoxon_cbd", "p_wilcoxon_placebo", "p_mann_whitney",
    "p_fdr_*",
    "r_wilcoxon_cbd / r_wilcoxon_placebo", "r_mann_whitney",
    "esito_*_grezzo", "esito_*_fdr"),
  Significato = c(
    "Numero di coppie complete (PRE e POST presenti) usate nel test, per gruppo.",
    "Mediana e primo/terzo quartile (IQR) sulle coppie complete. Statistica principale (test non parametrici).",
    "Media (corredo alla mediana, non al suo posto).",
    "Direzione della variazione mediana POST-PRE nel gruppo (aumento/diminuzione/invariato).",
    "p del test di Wilcoxon appaiato PRE vs POST nel gruppo CBD (2 code, exact=FALSE, correct=TRUE).",
    "p del test di Wilcoxon appaiato PRE vs POST nel gruppo Placebo.",
    "p del test di Mann-Whitney sui delta (POST-PRE), CBD vs Placebo.",
    "p corretto con Benjamini-Hochberg (FDR) applicato per famiglia di test separata.",
    "Effect size r = |Z|/sqrt(n) del test appaiato (0.1 piccolo, 0.3 medio, 0.5 grande).",
    "Effect size r = |Z|/sqrt(N) del test di Mann-Whitney.",
    "Decisione su H0 al p GREZZO, alpha=0.05: 'si rifiuta H0' / 'non si rifiuta H0'.",
    "Decisione su H0 al p CORRETTO FDR, alpha=0.05."),
  stringsAsFactors = FALSE)

## --- Scrittura XLSX (3 fogli) ---------------------------------------
wb <- openxlsx::createWorkbook()
stile_hdr <- openxlsx::createStyle(textDecoration = "bold", halign = "center",
                                   valign = "center", fgFill = "#E8E8E8",
                                   border = "TopBottom", wrapText = TRUE)
aggiungi_foglio <- function(wb, nome, df, freeze_col = 1) {
  openxlsx::addWorksheet(wb, nome)
  openxlsx::writeData(wb, nome, df, headerStyle = stile_hdr)
  openxlsx::freezePane(wb, nome, firstActiveRow = 2, firstActiveCol = freeze_col + 1)
  openxlsx::setColWidths(wb, nome, cols = seq_len(ncol(df)), widths = "auto")
}
aggiungi_foglio(wb, "Tabella_completa", TAB, freeze_col = 2)
aggiungi_foglio(wb, "Formato_tesi",     TAB_FMT, freeze_col = 1)
aggiungi_foglio(wb, "Legenda",          LEGENDA, freeze_col = 0)
f_xlsx <- file.path(DIR_TABELLE, "05_tabella_completa.xlsx")
openxlsx::saveWorkbook(wb, f_xlsx, overwrite = TRUE)
message("[05] XLSX salvato: ", f_xlsx, "  (fogli: Tabella_completa, Formato_tesi, Legenda)")

## --- Anteprima a schermo --------------------------------------------
cat("\n[05] Anteprima tabella (colonne chiave, prime 8 righe):\n")
ap <- TAB[1:8, c("parametro","n_cbd","p_wilcoxon_cbd","p_fdr_wilcoxon_cbd",
                 "esito_wilcoxon_cbd_grezzo","esito_wilcoxon_cbd_fdr","p_mann_whitney")]
print(knitr::kable(ap, format = "simple", row.names = FALSE))
