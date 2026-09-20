#!/usr/bin/env Rscript
# =============================================================================
# ANNOTATION GUIDE — MULTI-GENOME SUMMARY FIGURES
# =============================================================================
# This script reads deterministic Step 3 TSV files and makes two SVG figures.
#
# Figure 1: Fol4287 chromosome × query heatmap
#   • cell value = percent of that Fol4287 chromosome covered by canonical
#     Minimap2 alignments;
#   • chromosome 1 is displayed at the top;
#   • lineage-specific rows receive an explicit (LS) label and orange emphasis;
#   • the numeric percentage is printed inside every cell.
#
# Figure 2: grouped core-vs-lineage-specific plot
#   • one core and one lineage-specific bar for every query genome;
#   • values come directly from core_vs_lineage_specific_by_query.tsv;
#   • numeric labels are printed above the bars.
#
# The SVG device explicitly uses the Ubuntu font supplied by the locked Conda
# environment to reduce machine-specific font substitution in byte-level output.
# =============================================================================
options(stringsAsFactors = FALSE, scipen = 999)
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
if (length(script_arg) == 0) stop("Could not determine script location")
script_file <- sub("^--file=", "", script_arg[1])
root <- normalizePath(file.path(dirname(normalizePath(script_file)), ".."))
setwd(root)

mat_df <- read.delim("results/percent_aligned_matrix.tsv", check.names = FALSE)
class_df <- read.delim("results/core_vs_lineage_specific_by_query.tsv", check.names = FALSE)
query_names <- names(mat_df)[-(1:2)]
values <- as.matrix(mat_df[, query_names, drop = FALSE]); storage.mode(values) <- "numeric"
n_chr <- nrow(values); n_q <- ncol(values)
core_color <- "#2166AC"; ls_color <- "#D95F02"
heat_colors <- colorRampPalette(c("#F7FBFF","#DEEBF7","#9ECAE1","#4292C6","#08519C","#08306B"))(101)

svg("results/Fol4287_multigenome_heatmap.svg", width = 9.2, height = 8.0, pointsize = 11, family = "Ubuntu")
par(mar = c(6.5, 7.0, 4.2, 5.5), mgp = c(2.2, 0.65, 0), xpd = FALSE)
plot(NA, xlim = c(0.5, n_q + 1.25), ylim = c(0.5, n_chr + 0.5), xlab = "", ylab = "",
     xaxt = "n", yaxt = "n", bty = "n", axes = FALSE)
title(main = expression(paste("Conservation of Fol4287 chromosomes across ", italic("Fusarium oxysporum"), " genomes")),
      cex.main = 1.35, font.main = 2, line = 1.4)
row_y <- n_chr:1
for (i in seq_len(n_chr)) for (j in seq_len(n_q)) {
  value <- max(0, min(100, values[i, j])); cell_color <- heat_colors[round(value) + 1]
  rect(j - 0.5, row_y[i] - 0.5, j + 0.5, row_y[i] + 0.5, col = cell_color, border = "white", lwd = 1.25)
  text(j, row_y[i], sprintf("%.1f", value), cex = 0.82, col = if (value >= 60) "white" else "#222222", font = 2)
}
axis(1, at = seq_len(n_q), labels = query_names, tick = FALSE, line = -0.5, cex.axis = 1.0)
row_labels <- paste0("Chr", mat_df$chromosome, ifelse(mat_df$chromosome_class == "lineage_specific", " (LS)", ""))
for (i in seq_len(n_chr)) {
  is_ls <- mat_df$chromosome_class[i] == "lineage_specific"
  text(0.38, row_y[i], row_labels[i], adj = 1, xpd = NA, cex = 0.92,
       font = ifelse(is_ls, 2, 1), col = ifelse(is_ls, ls_color, "#222222"))
}
mtext("LS = lineage-specific chromosome", side = 2, line = 5.0, cex = 0.72, col = "#555555")
legend_x1 <- n_q + 0.57; legend_x2 <- n_q + 0.78; legend_bottom <- 2; legend_top <- n_chr - 1
for (k in 0:99) {
  y1 <- legend_bottom + k * (legend_top - legend_bottom) / 100
  y2 <- legend_bottom + (k + 1) * (legend_top - legend_bottom) / 100
  rect(legend_x1, y1, legend_x2, y2, col = heat_colors[k + 1], border = NA)
}
text(n_q + 0.88, legend_bottom, "0", adj = 0, cex = 0.78)
text(n_q + 0.88, (legend_bottom + legend_top) / 2, "50", adj = 0, cex = 0.78)
text(n_q + 0.88, legend_top, "100", adj = 0, cex = 0.78)
text(n_q + 0.68, legend_top + 0.75, "Aligned\nsequence (%)", cex = 0.77, font = 2)
mtext("Cells show the percentage of each Fol4287 chromosome covered by canonical Minimap2 alignments.",
      side = 1, line = 4.5, cex = 0.75, col = "#444444")
rect(0.5, 0.5, n_q + 0.5, n_chr + 0.5, border = "#444444", lwd = 0.8)
dev.off()

query_order <- unique(class_df$query)
core <- sapply(query_order, function(q) as.numeric(class_df$percent_aligned[class_df$query == q & class_df$chromosome_class == "core"]))
ls <- sapply(query_order, function(q) as.numeric(class_df$percent_aligned[class_df$query == q & class_df$chromosome_class == "lineage_specific"]))
plot_matrix <- rbind(Core = core, Lineage_specific = ls)
svg("results/core_vs_lineage_specific_by_query.svg", width = 8.5, height = 6.2, pointsize = 11, family = "Ubuntu")
par(mar = c(5.0, 5.8, 4.3, 1.8), mgp = c(2.7, 0.8, 0), las = 1)
bar_positions <- barplot(plot_matrix, beside = TRUE, plot = FALSE); x_max <- max(bar_positions) + 1
plot(NA, xlim = c(0, x_max), ylim = c(0, 105), xlab = "", ylab = "", xaxt = "n", yaxt = "n", bty = "n")
abline(h = seq(0, 100, 20), col = "#D9D9D9", lty = 1, lwd = 0.7)
bar_width <- 0.8
for (j in seq_len(ncol(plot_matrix))) {
  rect(bar_positions[1,j]-bar_width/2, 0, bar_positions[1,j]+bar_width/2, core[j], col = core_color, border = NA)
  rect(bar_positions[2,j]-bar_width/2, 0, bar_positions[2,j]+bar_width/2, ls[j], col = ls_color, border = NA)
}
for (j in seq_along(query_order)) {
  text(bar_positions[1,j], core[j] + 2, sprintf("%.1f", core[j]), cex = 0.82, font = 2, col = "#222222")
  text(bar_positions[2,j], ls[j] + 2, sprintf("%.1f", ls[j]), cex = 0.82, font = 2, col = "#222222")
}
axis(2, at = seq(0,100,20), labels = paste0(seq(0,100,20), "%"), las = 1, cex.axis = 0.9, tck = -0.015)
mtext("Fol4287 chromosome sequence aligned", side = 2, line = 3.5, cex = 1.0)
axis(1, at = colMeans(bar_positions), labels = query_order, tick = FALSE, cex.axis = 1.0, line = -0.3)
title(main = "Core versus lineage-specific Fol4287 sequence conservation", cex.main = 1.3, font.main = 2, line = 1.5)
legend("topright", legend = c("Core chromosomes","Lineage-specific chromosomes"), fill = c(core_color, ls_color),
       border = NA, bty = "n", cex = 0.9, inset = c(0.01,0.01))
segments(0,0,x_max,0,col="#333333",lwd=0.8); segments(0,0,0,100,col="#333333",lwd=0.8)
dev.off()
cat("Generated Minimap2-based summary figures.\n")
