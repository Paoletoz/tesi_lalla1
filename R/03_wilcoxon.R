# =====================================================================
# 03_wilcoxon.R — Test di Wilcoxon appaiato (intra-gruppo, PRE vs POST)
# ---------------------------------------------------------------------
# H0: nessuna differenza pre/post nel singolo individuo.
# Eseguito separatamente in CBD e in Placebo, sulle coppie complete.
# wilcox.test(pre, post, paired=TRUE, exact=FALSE, correct=TRUE), 2 code.
# Effect size r (|Z|/sqrt(n)); FDR di Benjamini-Hochberg PER FAMIGLIA
# (CBD e Placebo separate). Riporta sempre p grezzo E p corretto.
# Espone WILCOXON. Idempotente.
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

## --- Calcolo per ogni parametro e gruppo ----------------------------
message("[03] Wilcoxon appaiato PRE vs POST, per gruppo (CBD, Placebo)...")

righe <- list()
for (i in seq_len(nrow(DIZ))) {
  id <- DIZ$id[i]
  for (g in LIV_GRUPPO) {
    cp <- estrai_coppie(DATI, id, g)
    tt <- test_wilcoxon_appaiato(cp$pre, cp$post)
    es <- effsize_appaiato(cp$pre, cp$post)

    med_pre  <- if (nrow(cp)) stats::median(cp$pre)  else NA_real_
    med_post <- if (nrow(cp)) stats::median(cp$post) else NA_real_
    dmed <- med_post - med_pre
    variazione <- if (is.na(dmed)) NA_character_ else
      if (dmed > 0) "aumento" else if (dmed < 0) "diminuzione" else "invariato"

    # nota: unisce eventuali avvisi del test e la bassa numerosita'
    note <- character(0)
    if (nzchar(tt$nota)) note <- c(note, tt$nota)
    if (!is.na(tt$n) && tt$n < SOGLIA_N_BASSA)
      note <- c(note, sprintf("n bassa (%d)", tt$n))

    righe[[length(righe) + 1]] <- data.frame(
      ordine = DIZ$ordine[i], id = id, parametro = DIZ$parametro[i],
      unita = DIZ$unita[i], categoria = DIZ$categoria[i], gruppo = g,
      n = tt$n, mediana_pre = med_pre, mediana_post = med_post,
      delta_mediana = dmed, variazione = variazione,
      p_grezzo = tt$p, Z = es$Z, r = es$r, magnitudo = es$magnitudo,
      check_effsize = es$check_ok, nota = paste(note, collapse = "; "),
      row.names = NULL, stringsAsFactors = FALSE)
  }
}
WILCOXON <- do.call(rbind, righe)

## --- FDR di Benjamini-Hochberg, PER FAMIGLIA (gruppo) ---------------
WILCOXON$p_fdr <- NA_real_
for (g in LIV_GRUPPO) {
  sel <- WILCOXON$gruppo == g
  WILCOXON$p_fdr[sel] <- fdr_bh(WILCOXON$p_grezzo[sel])
}

## --- Esito (terminologia CLAUDE.md §3) su p grezzo ------------------
WILCOXON$esito <- vapply(WILCOXON$p_grezzo, esito_h0, character(1))

## --- Ordinamento colonne e righe ------------------------------------
WILCOXON <- WILCOXON[, c("ordine","id","parametro","unita","categoria","gruppo",
                         "n","mediana_pre","mediana_post","delta_mediana","variazione",
                         "p_grezzo","p_fdr","Z","r","magnitudo","check_effsize",
                         "esito","nota")]
WILCOXON <- WILCOXON[order(WILCOXON$gruppo, WILCOXON$ordine), ]
rownames(WILCOXON) <- NULL

## --- Salvataggio -----------------------------------------------------
f_out <- file.path(DIR_TABELLE, "03_wilcoxon.csv")
write.csv(WILCOXON, f_out, row.names = FALSE, fileEncoding = "UTF-8")
message("[03] Wilcoxon salvato in: ", f_out, "  (", nrow(WILCOXON), " righe)")

# controllo incrociato effect size rstatix vs coin
n_bad <- sum(WILCOXON$check_effsize == FALSE, na.rm = TRUE)
if (n_bad > 0) warning("[03] Effect size rstatix/coin discordanti in ", n_bad, " righe.")

## --- Anteprima: risultati significativi (p grezzo < alpha) ----------
cat("\n[03] Wilcoxon — righe con p grezzo <", ALPHA, "(p a 4 decimali):\n")
sig <- WILCOXON[!is.na(WILCOXON$p_grezzo) & WILCOXON$p_grezzo < ALPHA,
                c("parametro","gruppo","n","variazione","p_grezzo","p_fdr","r","magnitudo","esito")]
if (nrow(sig)) {
  sig$p_grezzo <- round(sig$p_grezzo, 4); sig$p_fdr <- round(sig$p_fdr, 4)
  sig$r <- round(sig$r, 3)
  print(knitr::kable(sig, format = "simple", row.names = FALSE))
} else cat("  Nessuna.\n")
