library(dplyr)
library(ggplot2)
library(tidyverse)
# load the data
marvel <- read.csv("data/marvel_data.csv")
dc <- read.csv("data/dc_data.csv")

na_check <- function(x) !is.na(x) & trimws(x) != ""

cleaned_m <- marvel |>
  filter(if_all(c(SEX, ALIGN, ALIVE, APPEARANCES), na_check))


cleaned_dc <- dc |>
  filter(if_all(c(SEX, ALIGN, ALIVE, APPEARANCES), na_check))

marvel_dc <- bind_rows(
  cleaned_dc |>
    select(SEX, ALIGN, alive = ALIVE, year = YEAR, appearances = APPEARANCES) |>
    mutate(company = "dc"),
  cleaned_m |>
    select(SEX, ALIGN, alive = ALIVE, year = Year, appearances = APPEARANCES) |>
    mutate(company = "marvel")
)

# gender ratio (female/male) by number of appearances for deceased and alive characters
# 1000+ are main/popular/reoccurring characters
gender_ratio <- marvel_dc |>
  filter(SEX %in% c("Male Characters", "Female Characters")) |>
  mutate(
    appearances = as.numeric(appearances),
    category = case_when(
      appearances <= 10 ~ "1 to 10",
      appearances <= 50 ~ "11 to 50",
      appearances <= 100 ~ "51 to 100",
      appearances <= 200 ~ "101 to 200",
      TRUE ~ "200+"
    ),
    category = factor(category, levels = c(
      "1 to 10", "11 to 50", "51 to 100",
      "101 to 200", "200+"
    ))
  ) |>
  count(category, alive, SEX) |>
  pivot_wider(names_from = SEX, values_from = n, values_fill = 0) |>
  mutate(ratio = `Female Characters` / `Male Characters`)

last_cat <- levels(gender_ratio$category)[nlevels(gender_ratio$category)]

label_data <- gender_ratio |>
  filter(category == last_cat)

fig_1 <- ggplot(gender_ratio, aes(x = category, y = ratio, group = alive, color = alive)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  geom_hline(yintercept = total_ratio, linetype = "dashed", color = "black") +
  annotate(
    "text",
    x = Inf, y = total_ratio,
    label = "Overall F/M Ratio", hjust = 1, vjust = -0.5,
    family = "Optima", color = "black"
  ) +
  # Direct labels instead of legend
  geom_text(
    data = label_data,
    aes(x = category, y = ratio, label = alive),
    hjust = .7, vjust = 2,
    family = "Optima", color = "black"
  ) +
  scale_y_continuous(limits = c(0, NA)) +
  scale_color_manual(
    values = c(
      "Deceased Characters" = "grey",
      "Living Characters"   = "#63a7ff"
    )
  ) +
  labs(
    title = "Female-per-Male Character Ratio by Appearance & Living Status",
    x     = "Number of Appearances",
    y     = "Number of Female per Male Character"
  ) +
  theme_gray(base_family = "Optima") +
  theme(
    legend.position = "none", plot.title = element_text(hjust = 0.5)
  )

ggsave("figs/fig1.png", fig_1)
