#!/usr/bin/env Rscript
# =============================================================================
# ANNOTATION GUIDE — DETAILED FOL4287-vs-FO47 CIRCULAR SYNTENY FIGURE
# =============================================================================
# The circular plot is intentionally limited to one query genome so the ribbon
# relationships remain interpretable.
#
# Data inputs:
#   reference_chromosome_metadata.tsv  Fol4287 labels/classes/lengths
#   Fo47_chromosome_metadata.tsv       Fo47 labels/classes/lengths
#   fo47_circos_links.tsv              already-filtered canonical alignments
#
# Deterministic layout choices:
#   • Fol4287 chromosomes are explicitly sorted numerically.
#   • Fo47 chromosomes use an explicit Roman-numeral order vector.
#   • every internal sector name is prefixed by its genome name;
#   • ribbon draw order is explicitly sorted by length and coordinates;
#   • fixed literal colors map to biological categories/orientation;
#   • the Ubuntu font is requested explicitly in the SVG device.
#
# The display thresholds are shown in the subtitle but were already applied by
# Step 3 when fo47_circos_links.tsv was generated.
# =============================================================================
options(stringsAsFactors = FALSE, scipen = 999)
suppressPackageStartupMessages(library(circlize))
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
if (length(script_arg) == 0) stop("Could not determine script location")
script_file <- sub("^--file=", "", script_arg[1])
root <- normalizePath(file.path(dirname(normalizePath(script_file)), "..")); setwd(root)
plot_min_length <- as.numeric(Sys.getenv("PLOT_MIN_ALIGNMENT_LENGTH", unset = "50000"))
plot_min_identity <- as.numeric(Sys.getenv("PLOT_MIN_IDENTITY", unset = "90"))
fol <- read.delim("results/reference_chromosome_metadata.tsv", check.names = FALSE)
fo47 <- read.delim("results/Fo47_chromosome_metadata.tsv", check.names = FALSE)
links <- read.delim("results/fo47_circos_links.tsv", check.names = FALSE)
if (nrow(fol) != 15) stop("Expected 15 Fol4287 chromosomes")
if (nrow(fo47) != 12) stop("Expected 12 Fo47 chromosomes")
if (nrow(links) == 0) stop("No Fo47 links passed plotting filters")
fol$chr_num <- as.integer(fol$chromosome); fol <- fol[order(fol$chr_num),]
roman <- c("I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII")
fo47$order <- match(fo47$chromosome, roman); if (any(is.na(fo47$order))) stop("Unexpected Fo47 chromosome label")
fo47 <- fo47[order(fo47$order),]
fol$sector <- paste0("Fol_", fol$chromosome); fo47$sector <- paste0("Fo47_", fo47$chromosome)
fol$label <- paste0("Fol", fol$chromosome); fo47$label <- paste0("Fo47-", fo47$chromosome)
sector_order <- c(fol$sector, fo47$sector)
sector_lengths <- c(as.numeric(fol$length_bp), as.numeric(fo47$length_bp)); names(sector_lengths) <- sector_order
sector_labels <- c(fol$label, fo47$label); names(sector_labels) <- sector_order
color_fol_core <- "#2166AC"; color_fol_ls <- "#D95F02"; color_fo47_core <- "#4DAF4A"
color_fo47_accessory <- "#984EA3"; color_same <- "#4393C3"; color_opposite <- "#D6604D"
sector_colors <- c(ifelse(fol$chromosome_class == "core", color_fol_core, color_fol_ls),
                   ifelse(fo47$chromosome_class == "accessory", color_fo47_accessory, color_fo47_core))
names(sector_colors) <- sector_order
fol_map <- setNames(fol$sector, fol$sequence_id); fo47_map <- setNames(fo47$sector, fo47$sequence_id)
links$fol_sector <- unname(fol_map[links$fol_id]); links$fo47_sector <- unname(fo47_map[links$fo47_id])
if (any(is.na(links$fol_sector)) || any(is.na(links$fo47_sector))) stop("Unmapped chromosome sector")
for (column in c("fol_start","fol_end","fo47_start","fo47_end","alignment_length_bp","percent_identity"))
  links[[column]] <- as.numeric(links[[column]])
links <- links[order(-links$alignment_length_bp, links$fol_sector, links$fol_start,
                     links$fo47_sector, links$fo47_start, links$fo47_end),]

svg("results/Fol4287_vs_Fo47_circos.svg", width = 9.5, height = 9.5, pointsize = 11, family = "Ubuntu")
par(mar = c(1,1,5,1)); circos.clear()
gaps <- rep(1.4, length(sector_order)); gaps[length(fol$sector)] <- 8; gaps[length(sector_order)] <- 8
circos.par(start.degree = 90, gap.after = gaps, track.margin = c(0.004,0.004),
           cell.padding = c(0,0,0,0), points.overflow.warning = FALSE,
           canvas.xlim = c(-1.12,1.12), canvas.ylim = c(-1.12,1.12))
xlim_matrix <- cbind(rep(0, length(sector_order)), sector_lengths)
circos.initialize(factors = factor(sector_order, levels = sector_order), xlim = xlim_matrix)
circos.trackPlotRegion(ylim = c(0,1), track.height = 0.10, bg.border = NA,
  panel.fun = function(x,y) {
    sector <- CELL_META$sector.index; sector_xlim <- CELL_META$xlim
    circos.rect(sector_xlim[1],0,sector_xlim[2],1,col=sector_colors[sector],border="white",lwd=1.0)
    circos.text(CELL_META$xcenter,0.50,labels=sector_labels[sector],facing="bending.inside",
                niceFacing=TRUE,cex=0.62,col="white",font=2)
  })
for (i in seq_len(nrow(links))) {
  link_color <- if (links$orientation[i] == "opposite")
    grDevices::adjustcolor(color_opposite, alpha.f = 0.22) else grDevices::adjustcolor(color_same, alpha.f = 0.18)
  circos.link(links$fol_sector[i], c(links$fol_start[i], links$fol_end[i]),
              links$fo47_sector[i], c(links$fo47_start[i], links$fo47_end[i]), col=link_color, border=NA)
}
title(main="Chromosome-scale synteny between Fol4287 and Fo47",cex.main=1.30,font.main=2,line=2.6)
mtext(paste0("Canonical Minimap2 links: ≥ ", format(plot_min_length,big.mark=",",scientific=FALSE),
             " bp reference span and ≥ ", plot_min_identity, "% identity"),
      side=3,line=1.2,cex=0.78,col="#444444")
legend("topleft", legend=c("Fol4287 core chromosome","Fol4287 lineage-specific chromosome",
                           "Fo47 core chromosome","Fo47 accessory chromosome VII",
                           "Same-orientation alignment","Opposite-orientation alignment"),
       fill=c(color_fol_core,color_fol_ls,color_fo47_core,color_fo47_accessory,
              grDevices::adjustcolor(color_same,alpha.f=0.60),grDevices::adjustcolor(color_opposite,alpha.f=0.60)),
       border=NA,bty="n",cex=0.82,inset=c(0,0),x.intersp=0.55,y.intersp=0.90)
circos.clear(); dev.off()
cat("Generated results/Fol4287_vs_Fo47_circos.svg with", nrow(links), "links.\n")
