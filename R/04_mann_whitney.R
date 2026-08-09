# =====================================================================
# 04_mann_whitney.R — Test di Mann-Whitney U tra i gruppi, sui DELTA
# ---------------------------------------------------------------------
# H0: nessuna differenza tra CBD e Placebo.
# Applicato al delta individuale delta = POST - PRE (annulla le
# differenze basali), NON ai soli valori POST.
# wilcox.test(delta ~ gruppo, exact=FALSE, correct=TRUE), 2 code.
# Effect size r (|Z|/sqrt(N)); FDR di Benjamini-Hochberg sulla famiglia
# dei 26 test Mann-Whitney. Riporta p grezzo E p corretto.
# Espone MANN_WHITNEY. Idempotente.
# =====================================================================

## --- Bootstrap -------------------------------------------------------
.carica <- function(nome) {
  cand <- c(file.path("R", nome), nome, file.path("..", "R", nome))
  f <- cand[file.exists(cand)][1]
  if (is.na(f)) stop(nome, " non trovato: eseguire dalla radice del progetto.")
  source(f)
}
if (!exists("estrai_coppie")) .carica("_funzioni.R")
if (!exists("DATI"))          .carica("01_import_pulizia.R")

## --- Calcolo per ogni parametro -------------------------------------
message("[04] Mann-Whitney sui delta (POST - PRE), CBD vs Placebo...")

righe <- list()
for (i in seq_len(nrow(DIZ))) {
  id <- DIZ$id[i]
  cp <- estrai_coppie(DATI, id)                 # coppie complete, ENTRAMBI i gruppi
  tt <- test_mann_whitney(cp$delta, cp$gruppo)
  es <- effsize_indip(cp$delta, cp$gruppo)

  med_delta_cbd <- stats::median(cp$delta[cp$gruppo == "CBD"])
  med_delta_pla <- stats::median(cp$delta[cp$gruppo == "Placebo"])

  note <- character(0)
  if (nzchar(tt$nota)) note <- c(note, tt$nota)
  if (min(tt$n_cbd, tt$n_pla) < SOGLIA_N_BASSA)
    note <- c(note, sprintf("n bassa (CBD=%d, Placebo=%d)", tt$n_cbd, tt$n_pla))

  righe[[length(righe) + 1]] <- data.frame(
    ordine = DIZ$ordine[i], id = id, parametro = DIZ$parametro[i],
    unita = DIZ$unita[i], categoria = DIZ$categoria[i],
    n_cbd = tt$n_cbd, n_placebo = tt$n_pla,
    mediana_delta_cbd = med_delta_cbd, mediana_delta_placebo = med_delta_pla,
    p_grezzo = tt$p, Z = es$Z, r = es$r, magnitudo = es$magnitudo,
    check_effsize = es$check_ok, nota = paste(note, collapse = "; "),
    row.names = NULL, stringsAsFactors = FALSE)
}
MANN_WHITNEY <- do.call(rbind, righe)

## --- FDR di Benjamini-Hochberg (famiglia unica: 26 test) -----------
MANN_WHITNEY$p_fdr <- fdr_bh(MANN_WHITNEY$p_grezzo)

## --- Esito (terminologia CLAUDE.md §3) su p grezzo ------------------
MANN_WHITNEY$esito <- vapply(MANN_WHITNEY$p_grezzo, esito_h0, character(1))

## --- Ordinamento colonne --------------------------------------------
MANN_WHITNEY <- MANN_WHITNEY[, c("ordine","id","parametro","unita","categoria",
                                 "n_cbd","n_placebo","mediana_delta_cbd",
                                 "mediana_delta_placebo","p_grezzo","p_fdr","Z","r",
                                 "magnitudo","check_effsize","esito","nota")]
MANN_WHITNEY <- MANN_WHITNEY[order(MANN_WHITNEY$ordine), ]
rownames(MANN_WHITNEY) <- NULL

## --- Salvataggio -----------------------------------------------------
f_out <- file.path(DIR_TABELLE, "04_mann_whitney.csv")
write.csv(MANN_WHITNEY, f_out, row.names = FALSE, fileEncoding = "UTF-8")
message("[04] Mann-Whitney salvato in: ", f_out, "  (", nrow(MANN_WHITNEY), " righe)")

n_bad <- sum(MANN_WHITNEY$check_effsize == FALSE, na.rm = TRUE)
if (n_bad > 0) warning("[04] Effect size rstatix/coin discordanti in ", n_bad, " righe.")

## --- Anteprima: quanti significativi + i p piu' piccoli -------------
n_sig <- sum(!is.na(MANN_WHITNEY$p_grezzo) & MANN_WHITNEY$p_grezzo < ALPHA)
cat(sprintf("\n[04] Mann-Whitney: %d parametri con p grezzo < %.2f (atteso: 0).\n",
            n_sig, ALPHA))
cat("[04] I 5 p-value piu' piccoli:\n")
ap <- MANN_WHITNEY[order(MANN_WHITNEY$p_grezzo), ][1:5,
        c("parametro","n_cbd","n_placebo","p_grezzo","p_fdr","r","magnitudo","esito")]
ap$p_grezzo <- round(ap$p_grezzo, 4); ap$p_fdr <- round(ap$p_fdr, 4); ap$r <- round(ap$r, 3)
print(knitr::kable(ap, format = "simple", row.names = FALSE))
