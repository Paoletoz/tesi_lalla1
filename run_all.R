# =====================================================================
# run_all.R — Esegue l'intera pipeline in ordine
# ---------------------------------------------------------------------
# Studio CBD vs Placebo — analisi non parametrica pre/post (tesi).
# Uso:  Rscript run_all.R   (dalla radice del progetto)
#
# Ordine: setup -> import/pulizia -> descrittive -> Wilcoxon ->
#         Mann-Whitney -> VALIDAZIONE (gate) -> tabelle -> grafici.
# La validazione (99) e' un cancello: se un valore non corrisponde ai
# riferimenti di CLAUDE.md §5 si ferma PRIMA di produrre gli output.
# =====================================================================

t0 <- Sys.time()

# Porta la working directory sulla radice del progetto (cartella di
# questo file), cosi' i percorsi relativi "R/..." funzionano sempre.
.args <- commandArgs(FALSE)
.fa <- sub("^--file=", "", grep("^--file=", .args, value = TRUE))
if (length(.fa)) setwd(dirname(normalizePath(.fa)))

cat("=====================================================================\n")
cat(" PIPELINE CBD vs PLACEBO — esecuzione completa\n")
cat("=====================================================================\n")

source("R/00_setup.R")        # pacchetti, opzioni, percorsi, costanti
source("R/_funzioni.R")       # funzioni statistiche condivise
source("R/01_import_pulizia.R")  # import + coercizione + report qualita'
source("R/02_descrittive.R")     # descrittive per gruppo e tempo
source("R/03_wilcoxon.R")        # Wilcoxon appaiato intra-gruppo
source("R/04_mann_whitney.R")    # Mann-Whitney sui delta

# --- Cancello di validazione (si ferma con errore se fallisce) ------
source("R/99_validazione.R")

# --- Output per la tesi (solo se la validazione e' passata) ---------
source("R/05_tabelle.R")      # tabella completa .csv/.xlsx
source("R/06_grafici.R")      # figure PNG 300 dpi + PDF

# --- Ambiente di esecuzione (riproducibilita') ----------------------
f_si <- file.path(DIR_OUTPUT, "sessionInfo.txt")
writeLines(c(paste("Generato:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
             "", capture.output(sessionInfo())), f_si)
cat("\n[run_all] sessionInfo salvato in:", f_si, "\n")

dt <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
cat("=====================================================================\n")
cat(sprintf(" PIPELINE COMPLETATA in %.1f s. Output in: %s\n", dt, DIR_OUTPUT))
cat("=====================================================================\n")
