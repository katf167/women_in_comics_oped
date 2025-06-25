library(dplyr)
library(ggplot2)

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

alignment_percentages <- bind_rows(
  cleaned_dc |> mutate(universe = "DC"),
  cleaned_m |> mutate(universe = "Marvel")
) |>
  filter(
    SEX %in% c("Male Characters", "Female Characters"),
    ALIGN %in% c("Good Characters", "Bad Characters", "Neutral Characters")
  ) |>
  mutate(
    gender = if_else(SEX == "Female Characters", "Female", "Male"),
    ALIGN  = factor(ALIGN, levels = c("Good Characters", "Neutral Characters", "Bad Characters"))
  ) |>
  count(universe, gender, ALIGN, name = "n") |>
  group_by(universe, gender) |>
  mutate(percentages = n / sum(n)) |>
  ungroup() |>
  mutate(x_position = as.numeric(ALIGN))

fm_diff <- alignment_percentages |>
  select(universe, ALIGN, gender, percentages, x_position) |>
  pivot_wider(names_from = gender, values_from = percentages) |>
  mutate(
    diff = Female - Male,
    ystart = Male,
    yend = Female,
    ymid = (Male + Female) / 2,
    diff_label = paste0(abs(round(diff * 100, 1)), "%")
  )

fm_diff <- fm_diff |>
  mutate(
    hjust = case_when(
      ALIGN == "Good Characters" ~ 1.1,
      ALIGN == "Neutral Characters" ~ -0.7,
      ALIGN == "Bad Characters" ~ -0.1
    )
  )

labels_no_legend <- alignment_percentages |>
  group_by(universe, gender) |>
  filter(x_position == max(x_position)) |>
  ungroup()

fig_2 <- ggplot(alignment_percentages, aes(x = ALIGN, y = percentages, group = gender)) +
  geom_line(aes(color = gender, linetype = gender), linewidth = 0.8) +
  geom_point(aes(color = gender), size = 3) +
  geom_segment(
    data = fm_diff,
    aes(x = x_position, xend = x_position, y = ystart, yend = yend),
    linetype = "dotted", color = "#a50000", inherit.aes = F
  ) +
  geom_text(
    data = fm_diff,
    aes(x = x_position, y = ymid, label = diff_label),
    family = "Optima", color = "#a50000",
    hjust = fm_diff$hjust, size = 3, inherit.aes = F
  ) +
  geom_text(
    data = labels_no_legend,
    aes(x = x_position + 0.1, y = percentages, label = gender, color = gender),
    hjust = 0, family = "Optima", size = 3, inherit.aes = F
  ) +
  facet_wrap(~universe, ncol = 1) +
  scale_y_continuous(labels = scales::percent_format(1), limits = c(0, NA)) +
  scale_color_manual(
    values = c(Female = "#a50000", Male = "#A9A9A9")
  ) +
  scale_linetype_manual(
    values = c(Female = "solid", Male = "dashed")
  ) +
  labs(
    title = "Percentages of Character Alignment by Gender",
    x = "",
    y = "Percent of Characters"
  ) +
  theme_gray(base_family = "Optima") +
  theme(
    legend.position       = "none",
    plot.title            = element_text(hjust = 0.5),
    panel.background      = element_rect(fill = "white", color = NA),
    plot.background       = element_rect(fill = "white")
  )

ggsave("figs/fig2.png", fig_2)