# =====================================================================
# _funzioni.R — Funzioni statistiche condivise
# ---------------------------------------------------------------------
# Non e' uno "step" della pipeline: il prefisso _ la tiene fuori
# dall'ordine numerico. E' caricata da 02/03/04/05/06/99.
# Nessuno stato: solo funzioni pure. Idempotente.
# =====================================================================

if (!exists("PROJ_ROOT")) {
  .cand <- c(file.path("R", "00_setup.R"), "00_setup.R",
             file.path("..", "R", "00_setup.R"))
  .s <- .cand[file.exists(.cand)][1]
  if (is.na(.s)) stop("00_setup.R non trovato: eseguire dalla radice del progetto.")
  source(.s)
}

## --- Estrazione coppie complete -------------------------------------
# Restituisce le coppie con PRE e POST entrambi presenti per un parametro.
# Se 'gruppo' e' indicato, filtra su quel gruppo. Le descrittive e i test
# usano SEMPRE questo stesso sottoinsieme (coerenza n <-> statistiche).
estrai_coppie <- function(dati, id, gruppo = NULL) {
  pre  <- dati[[paste0(id, "_pre")]]
  post <- dati[[paste0(id, "_post")]]
  g    <- dati$gruppo
  if (!is.null(gruppo)) {
    sel <- !is.na(g) & g == gruppo
    pre <- pre[sel]; post <- post[sel]; g <- g[sel]
  }
  comp <- !is.na(pre) & !is.na(post)
  data.frame(gruppo = g[comp], pre = pre[comp], post = post[comp],
             delta = post[comp] - pre[comp], stringsAsFactors = FALSE)
}

## --- Descrittive di un vettore --------------------------------------
# Statistiche non parametriche in primo piano (mediana, Q1, Q3) + corredo
# parametrico (media, DS). Q1/Q3 con quantile type = 7 (default R).
descrittive_vec <- function(x) {
  x <- x[!is.na(x)]
  n <- length(x)
  if (n == 0)
    return(c(n = 0, mediana = NA, Q1 = NA, Q3 = NA,
             media = NA, ds = NA, min = NA, max = NA))
  q <- quantile(x, c(0.25, 0.5, 0.75), type = 7, names = FALSE)
  c(n = n, mediana = q[2], Q1 = q[1], Q3 = q[3],
    media = mean(x), ds = stats::sd(x), min = min(x), max = max(x))
}

## --- Magnitudo dell'effect size r (soglie CLAUDE.md §3) -------------
# 0.1 piccolo, 0.3 medio, 0.5 grande. Sotto 0.1: trascurabile.
magnitudo_r <- function(r) {
  if (length(r) != 1 || is.na(r)) return(NA_character_)
  if (r < 0.1) "trascurabile"
  else if (r < 0.3) "piccolo"
  else if (r < 0.5) "medio"
  else "grande"
}

## --- Terminologia sull'ipotesi nulla (CLAUDE.md §3) -----------------
# p >= alpha  -> "non si rifiuta H0" (mai "si accetta H0").
esito_h0 <- function(p, alpha = ALPHA) {
  if (length(p) != 1 || is.na(p)) return("non valutabile (NA)")
  if (p < alpha) "si rifiuta H0" else "non si rifiuta H0"
}

## --- Test di Wilcoxon appaiato (intra-gruppo, PRE vs POST) ----------
# wilcox.test(pre, post, paired = TRUE, exact = FALSE, correct = TRUE).
# Non eseguibile -> p = NA con nota (CLAUDE.md §1.6).
test_wilcoxon_appaiato <- function(pre, post) {
  n <- length(pre)
  if (n < 1) return(list(n = 0L, p = NA_real_, nota = "n = 0"))
  d <- post - pre
  if (all(d == 0))
    return(list(n = n, p = NA_real_, nota = "tutte le differenze nulle"))
  p <- tryCatch(
    suppressWarnings(stats::wilcox.test(pre, post, paired = TRUE,
                                        exact = FALSE, correct = TRUE)$p.value),
    error = function(e) NA_real_)
  list(n = n, p = p, nota = if (is.na(p)) "test non calcolabile" else "")
}

## --- Test di Mann-Whitney U sui delta (tra gruppi) ------------------
# wilcox.test(delta ~ gruppo, exact = FALSE, correct = TRUE).
test_mann_whitney <- function(delta, gruppo) {
  g <- droplevels(factor(gruppo, levels = LIV_GRUPPO))
  n_cbd <- sum(g == "CBD"); n_pla <- sum(g == "Placebo")
  if (nlevels(g) < 2 || n_cbd < 1 || n_pla < 1)
    return(list(n_cbd = n_cbd, n_pla = n_pla, p = NA_real_,
                nota = "un gruppo senza dati"))
  df <- data.frame(delta = delta, gruppo = g)
  p <- tryCatch(
    suppressWarnings(stats::wilcox.test(delta ~ gruppo, data = df,
                                        exact = FALSE, correct = TRUE)$p.value),
    error = function(e) NA_real_)
  list(n_cbd = n_cbd, n_pla = n_pla, p = p,
       nota = if (is.na(p)) "test non calcolabile" else "")
}

## --- Effect size r, test appaiato -----------------------------------
# Fonte primaria: rstatix::wilcox_effsize (paired). Z e controllo
# incrociato: coin::wilcoxsign_test. r = |Z| / sqrt(n_coppie).
effsize_appaiato <- function(pre, post) {
  n <- length(pre)
  out <- list(r = NA_real_, Z = NA_real_, magnitudo = NA_character_, check_ok = NA)
  if (n < 1 || all((post - pre) == 0)) return(out)
  Z <- tryCatch(as.numeric(coin::statistic(
        coin::wilcoxsign_test(post ~ pre, distribution = "asymptotic"),
        type = "standardized")), error = function(e) NA_real_)
  lungo <- data.frame(sogg = rep(seq_len(n), 2),
                      tempo = factor(rep(c("pre", "post"), each = n),
                                     levels = c("pre", "post")),
                      val = c(pre, post))
  r_rs <- tryCatch(
    as.numeric(rstatix::wilcox_effsize(lungo, val ~ tempo, paired = TRUE)$effsize),
    error = function(e) NA_real_)
  r <- if (!is.na(r_rs)) r_rs else if (!is.na(Z)) abs(Z) / sqrt(n) else NA_real_
  check_ok <- if (!is.na(r_rs) && !is.na(Z)) abs(r_rs - abs(Z) / sqrt(n)) < 1e-3 else NA
  list(r = r, Z = Z, magnitudo = magnitudo_r(r), check_ok = check_ok)
}

## --- Effect size r, test indipendente (Mann-Whitney sui delta) ------
# Fonte primaria: rstatix::wilcox_effsize (indip). Z: coin::wilcox_test.
# r = |Z| / sqrt(N_totale).
effsize_indip <- function(delta, gruppo) {
  N <- length(delta)
  out <- list(r = NA_real_, Z = NA_real_, magnitudo = NA_character_, check_ok = NA)
  g <- droplevels(factor(gruppo, levels = LIV_GRUPPO))
  if (N < 1 || nlevels(g) < 2 || any(table(g) < 1)) return(out)
  df <- data.frame(delta = delta, gruppo = g)
  Z <- tryCatch(as.numeric(coin::statistic(
        coin::wilcox_test(delta ~ gruppo, data = df, distribution = "asymptotic"),
        type = "standardized")), error = function(e) NA_real_)
  r_rs <- tryCatch(
    as.numeric(rstatix::wilcox_effsize(df, delta ~ gruppo, paired = FALSE)$effsize),
    error = function(e) NA_real_)
  r <- if (!is.na(r_rs)) r_rs else if (!is.na(Z)) abs(Z) / sqrt(N) else NA_real_
  check_ok <- if (!is.na(r_rs) && !is.na(Z)) abs(r_rs - abs(Z) / sqrt(N)) < 1e-3 else NA
  list(r = r, Z = Z, magnitudo = magnitudo_r(r), check_ok = check_ok)
}

## --- Correzione FDR di Benjamini-Hochberg (per famiglia) -----------
# Applica BH solo ai p non-NA, con n = numero di test effettivi della
# famiglia; i NA restano NA (evita l'inflazione di n di p.adjust).
fdr_bh <- function(p) {
  res <- rep(NA_real_, length(p))
  ok <- !is.na(p)
  if (any(ok)) res[ok] <- stats::p.adjust(p[ok], method = "BH")
  res
}
