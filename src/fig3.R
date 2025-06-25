library(dplyr)
library(ggplot2)
library(CGPfunctions)

marvel <- read.csv("data/marvel_data.csv")
dc <- read.csv("data/dc_data.csv")

na_check <- function(x) !is.na(x) & trimws(x) != ""

cleaned_m <- marvel |>
  filter(if_all(c(SEX, ALIGN, ALIVE), na_check))

cleaned_dc <- dc |>
  filter(if_all(c(SEX, ALIGN, ALIVE), na_check))

marvel_dc <- bind_rows(
  cleaned_dc |>
    select(SEX, ALIGN, alive = ALIVE, year = YEAR, appearances = APPEARANCES) |>
    mutate(company = "dc"),
  cleaned_m |>
    select(SEX, ALIGN, alive = ALIVE, year = Year, appearances = APPEARANCES) |>
    mutate(company = "marvel")
)

slope_data <- marvel_dc |>
  filter(
    SEX %in% c("Male Characters", "Female Characters"),
    ALIGN %in% c("Good Characters", "Neutral Characters", "Bad Characters")
  ) |>
  mutate(
    status = if_else(alive == "Living Characters", "Living", "Deceased"),
    align_short = str_remove(ALIGN, " Characters"),
    group_label = paste0(
      tolower(align_short), " ",
      if_else(SEX == "Female Characters", "female", "male"),
      " characters"
    )
  ) |>
  count(status, group_label, name = "n") |>
  group_by(status) |>
  mutate(prop = n / sum(n)) |>
  mutate(prop = round(prop, 2)) |>
  ungroup()

# 3. Draw with newggslopegraph
fig_3 <- newggslopegraph(
  slope_data,
  status,
  prop,
  group_label,
  Title = "Alignment Distribution: Living vs Deceased by Gender",
  TitleJustify = "C",
  SubTitle = NULL,
  Caption = NULL,
  LineThickness = 0.5,
  YTextSize = 3
)

ggsave("figs/fig3.png", fig_3)