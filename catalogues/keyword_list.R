# What it does: Holds the search vocabulary for the four streams of the
#   synthesis protocol (docs/synthesis/03-search-strategy.md) in one place,
#   as blocks of terms, and says which blocks each search crosses.
# Reads: nothing.
# Writes: nothing. This file is sourced by R/01_search/openalex_search.R.
# Flags: none.
#
# A search is a list of blocks joined by AND. Inside a block the terms are
# joined by OR. The practice block is special: the search is run once per
# practice, so each practice gets its own query and its own search log row.
#
# The strings come from 03-search-strategy.md and should match it. Change
# them there first (it is the protocol), then here. Every string is tested
# at calibration: hit counts, and recall of at least 90% on the known
# includes set (03 section 0). A term that adds hits but no includes is
# dropped. Adding a term means rerunning step 1 only; everything downstream
# is keyed to the record, not to the query.
#
# A trailing * is a wildcard where the database supports one. OpenAlex does
# not, so step 1 expands or drops it; other databases take it as written.

# ---- block: the practice -----------------------------------------------

# One entry per in scope practice_code in catalogues/vocab_practices.csv.
# `terms` are ORed. `and_any`, where present, is a second block the practice
# always carries, because the bare terms (AWD, SRI, hay, supplementation)
# return mostly noise on their own (03 section 0).
KW_PRACTICE <- list(
  awd = list(
    terms = c("alternate wetting and drying", "AWD", "intermittent irrigation",
              "controlled irrigation", "safe AWD"),
    and_any = c("rice")
  ),
  biochar = list(
    terms = c("biochar", "bio-char", "pyrolysed biomass", "charcoal amendment")
  ),
  rotational_grazing = list(
    terms = c("rotational grazing", "planned grazing", "holistic grazing",
              "holistic planned grazing", "deferred grazing",
              "grazing management", "rotational resting", "grazing reserve",
              "kalo", "olopololi", "controlled grazing")
  ),
  ca_bundle = list(
    terms = c("conservation agriculture", "no-till", "zero till*",
              "minimum till*", "reduced till*", "ripping", "direct seeding"),
    and_any = c("mulch", "residue*", "soil cover")
  ),
  cover_crops = list(
    terms = c("cover crop*", "green manure", "relay crop*", "mucuna",
              "velvet bean", "lablab", "canavalia", "crotalaria")
  ),
  nutrient_mgmt_b = list(
    terms = c("integrated soil fertility", "ISFM", "micro-dosing",
              "microdosing", "deep placement", "fertilizer use efficiency",
              "fertiliser use efficiency", "site-specific nutrient", "4R")
  ),
  trees_in_farmlands = list(
    # Screen out multistrata, boundary plantings and fallows at title and
    # abstract; the string cannot exclude them.
    terms = c("parkland*", "scattered trees", "on-farm trees",
              "trees on farm*", "Faidherbia", "Vitellaria", "shea",
              "alley crop*", "hedgerow intercrop*", "FMNR",
              "farmer managed natural regeneration", "agroforestry")
  ),
  fodder_banks = list(
    terms = c("fodder bank*", "fodder tree*", "fodder shrub*", "Calliandra",
              "Leucaena", "Gliricidia", "Sesbania", "tree fodder"),
    and_any = c("dairy", "milk", "cattle", "goat*", "sheep", "livestock")
  ),
  feed_mgmt = list(
    # Methane additive studies are excluded at screening.
    terms = c("feed management", "forage conservation", "silage", "hay",
              "urea treatment", "crop residue treatment", "supplementation",
              "improved forage*", "Napier", "Brachiaria"),
    and_any = c("dairy", "milk", "cattle", "goat*", "sheep", "livestock")
  ),
  silvopasture = list(
    terms = c("silvopast*", "silvo-past*", "agrosilvopast*", "shade trees"),
    and_any = c("cattle", "dairy", "livestock", "heat stress", "THI")
  ),
  dsr = list(
    terms = c("direct seeded rice", "direct-seeded rice", "dry seeding",
              "wet seeding", "DSR"),
    and_any = c("rice")
  ),
  sri = list(
    terms = c("system of rice intensification", "SRI"),
    and_any = c("rice")
  ),
  erw = list(
    terms = c("rock dust", "rock powder", "basalt", "silicate rock",
              "enhanced weathering", "remineral*"),
    and_any = c("yield", "drought", "water")
  )
)

# ---- stream 1: practice evidence ---------------------------------------

# Stress seasons (03 section 1.3).
KW_STRESS <- c(
  "drought", "dry spell", "water stress", "moisture stress", "water deficit",
  "low rainfall", "dry year", "dry season", "rainfall variability",
  "heat stress", "high temperature", "waterlog*", "flood*",
  "yield stability", "yield variability", "stress year", "bad year",
  "resilien*", "El Niño", "La Niña"
)

# The stress block favours studies whose authors chose to report stress
# seasons. So every practice is also searched for multi-season trials with
# no stress block, and S5 classifies the seasons afterwards (03 step 4a).
KW_MULTISEASON <- c("long-term", "multi-year", "seasons")

KW_OUTCOME <- c(
  "yield", "productivity", "grain yield", "biomass", "milk yield",
  "milk production", "liveweight", "live weight", "weight gain",
  "mortality", "forage production"
)

# Costs and practice characteristics, run separately and weighted to grey
# literature. Profitability papers are read for their cost tables only.
KW_COST_CHAR <- c(
  "cost*", "labour requirement", "labor requirement", "person-days",
  "establishment cost", "gross margin", "cost-benefit", "partial budget",
  "profitab*", "lifespan", "useful life", "replacement", "tree survival",
  "mortality", "persistence", "revers*", "disadopt*", "abandon*",
  "monitoring cost", "transaction cost", "verification cost",
  "cost per farmer"
)

# ---- stream 3: the loss matrix -----------------------------------------

KW_LOSS_CROP <- c(
  "maize", "corn", "sorghum", "millet", "rice", "cassava", "bean*", "wheat",
  "teff", "groundnut"
)
KW_LOSS_CROP_HAZARD <- c(
  "drought", "dry spell", "water stress", "heat stress", "high temperature",
  "waterlog*", "flood*"
)
KW_LOSS_CROP_LOSS <- c(
  "yield loss", "yield reduction", "yield penalty", "production loss",
  "crop failure", "yield decline"
)

KW_LOSS_LIVESTOCK <- c(
  "cattle", "dairy", "goat*", "sheep", "camel*", "livestock", "pastoral*"
)
KW_LOSS_LIVESTOCK_HAZARD <- c(
  "drought", "heat stress", "temperature-humidity index", "THI"
)
KW_LOSS_LIVESTOCK_LOSS <- c(
  "milk yield", "milk production", "mortality", "weight loss", "liveweight",
  "forage", "biomass"
)

# The silver event search (crop assessments for named drought years) is
# built per country and year from S5's list, not from a fixed block. See 03
# section 3.4.

# ---- stream 4: adoption, drivers and benefit sharing --------------------

# Run alongside streams 1 to 3, with its own search log rows and screening,
# so the adoption literature stays separate (decision D8).
KW_ADOPTION <- c(
  "adopt*", "uptake", "use of", "extent", "area under", "prevalence",
  "diffusion", "disadopt*", "abandon*"
)

# Determinants of adoption, payment experiments and choice experiments
# (docs/synthesis/10 section 3.2 and 3.3). Plain intention surveys are
# still excluded at screening.
KW_ADOPTION_DRIVER <- c(
  "determinant*", "factors influencing", "drivers of adoption",
  "choice experiment", "willingness to accept",
  "payment for ecosystem services", "PES", "conditional payment",
  "incentive payment"
)

# Share of carbon income to farmers (10 section 3.1). Mostly found in carbon
# project documents already opened for costs.
KW_BENEFIT_SHARE <- c(
  "carbon credit*", "carbon revenue", "carbon payment*", "benefit sharing",
  "benefit-sharing", "revenue sharing"
)

# ---- geography ----------------------------------------------------------

# For databases that cannot filter on country (Scopus, CAB Abstracts, AGRIS,
# Google Scholar). OpenAlex filters on institution country server side
# instead (AFRICA_ISO2 in R/00_shared/paths.R), which beats matching names
# in text but mislabels fieldwork written up abroad, so screening checks
# geography again. The protocol drops this block for mechanism searches and
# where SSA returns fewer than about 30 hits: evidence from outside SSA is
# admitted for mechanism and where SSA is thin (01 section 1.4).
KW_GEOGRAPHY <- c(
  "Africa", "sub-Saharan", "Sahel", "Kenya", "Ethiopia", "Nigeria",
  "Tanzania", "Uganda", "Rwanda", "Malawi", "Zambia", "Zimbabwe",
  "Mozambique", "Ghana", "Burkina Faso", "Mali", "Niger", "Senegal",
  "Benin", "Cameroon", "Madagascar", "South Africa", "Sudan", "Somalia"
)

# ---- what each search crosses -------------------------------------------

# One entry per search. `blocks` are the block objects above, ANDed in this
# order; "practice" means the search runs once per entry in KW_PRACTICE.
# `geography` says whether the geography block (or the OpenAlex country
# filter) applies: "yes", or "optional" where the protocol drops it when
# SSA is thin. The search log records the search name with every record, so
# the four streams keep separate funnels.
KW_SEARCHES <- list(
  s1_stress = list(
    stream = 1, blocks = c("practice", "KW_STRESS", "KW_OUTCOME"),
    geography = "optional"
  ),
  s1_multiseason = list(
    stream = 1, blocks = c("practice", "KW_MULTISEASON", "KW_OUTCOME"),
    geography = "optional"
  ),
  s1_cost = list(
    stream = 1, blocks = c("practice", "KW_COST_CHAR"),
    geography = "yes"
  ),
  s3_crop = list(
    stream = 3,
    blocks = c("KW_LOSS_CROP", "KW_LOSS_CROP_HAZARD", "KW_LOSS_CROP_LOSS"),
    geography = "yes"
  ),
  s3_livestock = list(
    stream = 3,
    blocks = c("KW_LOSS_LIVESTOCK", "KW_LOSS_LIVESTOCK_HAZARD",
               "KW_LOSS_LIVESTOCK_LOSS"),
    geography = "yes"
  ),
  s4_adoption = list(
    stream = 4, blocks = c("practice", "KW_ADOPTION"),
    geography = "yes"
  ),
  s4_driver = list(
    stream = 4, blocks = c("practice", "KW_ADOPTION_DRIVER"),
    geography = "yes"
  ),
  s4_benefit_share = list(
    stream = 4, blocks = c("practice", "KW_BENEFIT_SHARE"),
    geography = "yes"
  )
)

# Stream 2 (long term trials and datasets) is not a keyword search. It is
# worked from ERA, CGIAR archives and trial networks by hand, into the
# dataset register (03 section 2).

# ---- terms that mark a record as noise ---------------------------------

# Not used to filter the query, because a title-only exclusion throws away
# good records. Used in the search log to show how much noise each search
# returns, and read again by the screener prompt.
KW_EXCLUDE_HINTS <- c(
  "urban forestry", "greenhouse gas inventory", "life cycle assessment",
  "laboratory incubation", "pot experiment", "glasshouse",
  "3-NOP", "methane inhibitor", "enteric methane"
)
