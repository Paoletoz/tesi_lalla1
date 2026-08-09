# =====================================================================
# 06_grafici.R — Grafici per la tesi
# ---------------------------------------------------------------------
# Per ogni parametro (26) produce:
#   (a) boxplot appaiati PRE/POST per gruppo, con le linee che collegano
#       i singoli soggetti (variabilita' individuale);
#   (b) boxplot dei delta (POST-PRE) per gruppo.
# Etichette in italiano con unita', nessun titolo interno (va in
# didascalia), palette in scala di grigi leggibile anche in B/N.
# Ogni figura in PNG 300 dpi e PDF vettoriale (cairo, per Δ e µ).
# Idempotente.
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
suppressPackageStartupMessages({library(ggplot2); library(tidyr)})

message("[06] Generazione grafici (boxplot appaiati + boxplot delta)...")

## --- Etichette e tema ------------------------------------------------
# Evita "Eosinofili % (%)": se il nome contiene gia' % e l'unita' e' %.
etichetta <- function(parametro, unita) {
  if (unita == "%" && grepl("%", parametro, fixed = TRUE)) parametro
  else paste0(parametro, " (", unita, ")")
}
tema_tesi <- theme_bw(base_size = 11) +
  theme(legend.position = "none",
        panel.grid.minor = element_blank(),
        strip.background = element_rect(fill = "grey92", color = "grey60"),
        strip.text = element_text(face = "bold"),
        axis.title = element_text(face = "bold"))

# Palette in scala di grigi (leggibile in bianco e nero)
FILL_TEMPO  <- c(PRE = "white",   POST = "grey65")
FILL_GRUPPO <- c(CBD = "white",   Placebo = "grey65")

## --- (a) Boxplot appaiati PRE/POST con linee individuali ------------
grafico_prepost <- function(id, parametro, unita) {
  cp <- estrai_coppie(DATI, id)
  if (nrow(cp) == 0) return(NULL)
  cp$sogg <- seq_len(nrow(cp))
  long <- tidyr::pivot_longer(cp, c(pre, post), names_to = "tempo", values_to = "valore")
  long$tempo <- factor(ifelse(long$tempo == "pre", "PRE", "POST"), levels = c("PRE", "POST"))
  ggplot(long, aes(tempo, valore)) +
    geom_line(aes(group = sogg), color = "grey75", linewidth = 0.3, alpha = 0.6) +
    geom_boxplot(aes(fill = tempo), width = 0.55, alpha = 0.75,
                 outlier.shape = NA, color = "black", linewidth = 0.4) +
    geom_point(shape = 21, fill = "grey40", color = "grey20",
               size = 1.1, alpha = 0.7) +
    facet_wrap(~ gruppo) +
    scale_fill_manual(values = FILL_TEMPO) +
    labs(x = "Tempo", y = etichetta(parametro, unita)) +
    tema_tesi
}

## --- (b) Boxplot dei delta per gruppo -------------------------------
grafico_delta <- function(id, parametro, unita) {
  cp <- estrai_coppie(DATI, id)
  if (nrow(cp) == 0) return(NULL)
  ggplot(cp, aes(gruppo, delta)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50", linewidth = 0.4) +
    geom_boxplot(aes(fill = gruppo), width = 0.5, alpha = 0.75,
                 outlier.shape = NA, color = "black", linewidth = 0.4) +
    geom_point(shape = 21, fill = "grey40", color = "grey20", size = 1.1, alpha = 0.7,
               position = position_jitter(width = 0.08, height = 0, seed = 1)) +
    scale_fill_manual(values = FILL_GRUPPO) +
    labs(x = "Gruppo", y = paste0("Δ ", etichetta(parametro, unita)),
         caption = "Δ = POST − PRE") +
    tema_tesi + theme(plot.caption = element_text(color = "grey40"))
}

## --- Salvataggio PNG (300 dpi) + PDF (vettoriale) -------------------
salva <- function(gg, nome, w, h) {
  if (is.null(gg)) return(invisible(FALSE))
  suppressMessages({
    ggsave(file.path(DIR_FIGURE, paste0(nome, ".png")), gg,
           width = w, height = h, dpi = 300, bg = "white")
    ggsave(file.path(DIR_FIGURE, paste0(nome, ".pdf")), gg,
           width = w, height = h, device = cairo_pdf, bg = "white")
  })
  invisible(TRUE)
}

## --- Ciclo su tutti i 26 parametri ----------------------------------
n_ok <- 0
for (i in seq_len(nrow(DIZ))) {
  id <- DIZ$id[i]; par <- DIZ$parametro[i]; uni <- DIZ$unita[i]; ord <- DIZ$ordine[i]
  base <- sprintf("fig_%02d_%s", ord, id)
  ok1 <- salva(grafico_prepost(id, par, uni), paste0(base, "_prepost"), 7.0, 4.2)
  ok2 <- salva(grafico_delta(id, par, uni),   paste0(base, "_delta"),   4.6, 4.2)
  if (ok1 && ok2) n_ok <- n_ok + 1
}

n_file <- length(list.files(DIR_FIGURE, pattern = "\\.(png|pdf)$"))
message(sprintf("[06] Grafici generati per %d/%d parametri -> %d file in %s",
                n_ok, nrow(DIZ), n_file, DIR_FIGURE))
cat(sprintf("\n[06] %d figure salvate (PNG 300 dpi + PDF) in output/figure/\n", n_file))
cat("     - fig_<ordine>_<parametro>_prepost  (boxplot appaiati con linee individuali)\n")
cat("     - fig_<ordine>_<parametro>_delta    (boxplot dei delta per gruppo)\n")
