# ============================================================
# SEX-CHROMOSOME DOSAGE ANALYSIS
# Species: Rock Pigeon (Columba livia)
# Data: Whole-genome DNA sequencing read depth
# ============================================================

# 1. Read Samtools coverage data
cov <- read.delim(
  "chromosome_coverage.tsv",
  comment.char = "",
  check.names = FALSE,
  stringsAsFactors = FALSE
)

names(cov)[1] <- "rname"

if (!"meandepth" %in% names(cov)) {
  stop("Missing meandepth column")
}

# 2. Read chromosome classification file
key <- read.csv(
  "chromosome_groups.csv",
  stringsAsFactors = FALSE
)

if (!all(c("rname", "group") %in% names(key))) {
  stop("Incorrect chromosome_groups.csv columns")
}

key$rname <- trimws(key$rname)
key$group <- toupper(trimws(key$group))

if (anyDuplicated(key$rname)) {
  stop("Repeated chromosome identifiers")
}

if (!all(key$group %in% c("A", "X", "Y", "Z", "W"))) {
  stop("Invalid chromosome group")
}

# 3. Match chromosome identifiers with coverage data
x <- merge(
  key,
  cov[, c("rname", "meandepth")],
  by = "rname",
  all.x = TRUE,
  sort = FALSE
)

x$meandepth <- suppressWarnings(
  as.numeric(x$meandepth)
)

if (anyNA(x$meandepth)) {
  stop("Missing depths: check chromosome identifiers")
}

if (any(x$meandepth < 0)) {
  stop("Negative depth is not valid")
}

if (sum(x$group == "A") < 5) {
  stop("At least five autosomes are required")
}

# 4. Identify the sex chromosome
if ("X" %in% x$group && "Z" %in% x$group) {
  stop("Cannot classify both X and Z")
}

if (sum(x$group == "Z") == 1 &&
    !any(x$group == "X")) {
  
  target <- "Z"
  one_copy <- "ZW-like"
  two_copies <- "ZZ-like"
  
} else if (sum(x$group == "X") == 1 &&
           !any(x$group == "Z")) {
  
  target <- "X"
  one_copy <- "XY-like"
  two_copies <- "XX-like"
  
} else {
  stop("Label exactly one X or one Z chromosome")
}

# 5. Calculate median autosomal depth
A <- median(x$meandepth[x$group == "A"])

if (!is.finite(A) || A <= 0) {
  stop("No usable autosomal coverage")
}

# 6. Calculate relative chromosome depth
x$relative_depth <- x$meandepth / A

ratio <- x$relative_depth[x$group == target]

# 7. Interpret sex-chromosome dosage
call <- if (ratio >= 0.80) {
  two_copies
} else if (ratio <= 0.65) {
  one_copy
} else {
  "Ambiguous"
}

if (A < 1) {
  call <- "Inconclusive: very low autosomal depth"
}

# 8. Optional W chromosome evidence
partner <- if (target == "X") "Y" else "W"

partner_ratio <- if (partner %in% x$group) {
  x$relative_depth[x$group == partner][1]
} else {
  NA_real_
}

# 9. Export results
dir.create("results", showWarnings = FALSE)

write.csv(
  x,
  "results/chromosome_relative_depth.csv",
  row.names = FALSE
)

# 10. Generate chromosome depth graph
png(
  "results/chromosome_depth.png",
  width = 1000,
  height = 580
)

par(mar = c(8, 4, 3, 1))

barplot(
  x$relative_depth,
  names.arg = x$rname,
  las = 2,
  ylab = "Depth relative to median autosome",
  main = "Rock Pigeon Chromosome Depth",
  cex.names = 0.75
)

abline(h = c(0.5, 1.0), lty = 2)

dev.off()

# 11. Save interpretation
summary <- c(
  paste("Median autosome depth:", round(A, 3)),
  paste("Sex chromosome:", target),
  paste("Sex chromosome / autosome ratio:", round(ratio, 3)),
  paste("W/Y relative depth:", round(partner_ratio, 3)),
  paste("Dosage interpretation:", call)
)

writeLines(
  summary,
  "results/sex_inference.txt"
)

# 12. Display results
cat(
  paste(summary, collapse = "\n"),
  "\n"
)

setwd("C:/Rock_Pigeon_Genome")
list.files()
source("sex_depth_analysis.R")

list.files("results")