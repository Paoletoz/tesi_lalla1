# =====================================================================
# 02_descrittive.R — Statistiche descrittive per gruppo e tempo
# ---------------------------------------------------------------------
# Per ogni parametro e gruppo (CBD, Placebo) calcola, sulle COPPIE
# COMPLETE (lo stesso sottoinsieme usato dai test), n / mediana / Q1 /
# Q3 / media / DS / min / max, separatamente per PRE e POST.
# La mediana con IQR e' la statistica principale (test non parametrici).
# Espone DESCRITTIVE. Idempotente.
# =====================================================================

## --- Bootstrap: funzioni condivise + dati ---------------------------
.carica <- function(nome) {
  cand <- c(file.path("R", nome), nome, file.path("..", "R", nome))
  f <- cand[file.exists(cand)][1]
  if (is.na(f)) stop(nome, " non trovato: eseguire dalla radice del progetto.")
  source(f)
}
if (!exists("estrai_coppie")) .carica("_funzioni.R")
if (!exists("DATI"))          .carica("01_import_pulizia.R")

## --- Calcolo descrittive --------------------------------------------
message("[02] Calcolo descrittive su coppie complete, per gruppo e tempo...")

righe <- list()
for (i in seq_len(nrow(DIZ))) {
  id <- DIZ$id[i]
  for (g in LIV_GRUPPO) {
    cp <- estrai_coppie(DATI, id, g)          # coppie complete del gruppo
    for (tempo in c("PRE", "POST")) {
      x <- if (tempo == "PRE") cp$pre else cp$post
      d <- descrittive_vec(x)
      righe[[length(righe) + 1]] <- data.frame(
        ordine = DIZ$ordine[i], id = id, parametro = DIZ$parametro[i],
        unita = DIZ$unita[i], categoria = DIZ$categoria[i],
        gruppo = g, tempo = tempo,
        n = as.integer(d["n"]), mediana = d["mediana"],
        Q1 = d["Q1"], Q3 = d["Q3"], media = d["media"], ds = d["ds"],
        min = d["min"], max = d["max"],
        row.names = NULL, stringsAsFactors = FALSE)
    }
  }
}
DESCRITTIVE <- do.call(rbind, righe)
DESCRITTIVE <- DESCRITTIVE[order(DESCRITTIVE$ordine,
                                 DESCRITTIVE$gruppo,
                                 factor(DESCRITTIVE$tempo, c("PRE", "POST"))), ]
rownames(DESCRITTIVE) <- NULL

## --- Salvataggio -----------------------------------------------------
f_out <- file.path(DIR_TABELLE, "02_descrittive.csv")
write.csv(DESCRITTIVE, f_out, row.names = FALSE, fileEncoding = "UTF-8")
message("[02] Descrittive salvate in: ", f_out,
        "  (", nrow(DESCRITTIVE), " righe = 26 parametri x 2 gruppi x 2 tempi)")

## --- Anteprima a schermo (Peso, per controllo) ----------------------
cat("\n[02] Anteprima — Peso (kg), coppie complete:\n")
ap <- DESCRITTIVE[DESCRITTIVE$id == "peso",
                  c("gruppo", "tempo", "n", "mediana", "Q1", "Q3", "media", "ds")]
ap[, 4:8] <- round(ap[, 4:8], 3)
print(knitr::kable(ap, format = "simple", row.names = FALSE))
