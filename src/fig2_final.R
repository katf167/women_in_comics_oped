library(dplyr)
library(ggplot2)
#load the data
marvel <- read.csv('data/marvel_data.csv')
dc <- read.csv('data/dc_data.csv')

na_check <- function(x) !is.na(x) & trimws(x) != ""

#drop nas for sex, align, and alive for now 
#(might need to drop more rows later but not a lot of missing data)
cleaned_m <- marvel |>
  filter(if_all(c(SEX, ALIGN, ALIVE, APPEARANCES), na_check))


cleaned_dc <- dc |>
  filter(if_all(c(SEX, ALIGN, ALIVE, APPEARANCES), na_check))

#combine the two datasets!
marvel_dc <- bind_rows(
  cleaned_dc |>
    select(SEX, ALIGN, alive = ALIVE, year = YEAR, appearances = APPEARANCES) |>
    mutate(company = "dc"),
  cleaned_m |>
    select(SEX, ALIGN, alive = ALIVE, year = Year, appearances = APPEARANCES) |>
    mutate(company = "marvel")
)

#gender ratio (female/male) by number of appearances for deceased and alive characters
#1000+ are main/popular/reoccurring characters
gender_ratio <- marvel_dc |>
  filter(SEX %in% c("Male Characters","Female Characters")) |>
  mutate(
    appearances = as.numeric(appearances),
    category = case_when(
      appearances <= 10 ~ "1–10",
      appearances <= 50 ~ "11–50",
      appearances <= 100 ~ "51–100",
      appearances <= 200 ~ "101–200",
      TRUE ~ "200+"
    ),
    category = factor(category, levels = c("1–10","11–50","51–100", 
                                           "101–200", "200+")))|>
  count(category, alive, SEX) |>
  pivot_wider(names_from = SEX, values_from = n, values_fill = 0) |>
  mutate(ratio = `Female Characters` / `Male Characters`)

#overall male/female ratio
total_ratio <- marvel_dc |>
  filter(SEX %in% c("Male Characters","Female Characters")) |>
  count(SEX) |>
  pivot_wider(names_from = SEX, values_from = n) |>
  summarise(r = `Female Characters` / `Male Characters`) |>
  pull(r)

#fig2
fig2 <- ggplot(gender_ratio, aes(x = category, y = ratio, fill = alive)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.4) + 
  geom_hline(yintercept = total_ratio, linetype = "dashed", color = "black") +
  annotate(
    "text", x = Inf, y = total_ratio,
    label = "Overall F/M Ratio", hjust = 1, vjust = -0.6,
    family = "Optima", color = "black"
  ) +
  scale_fill_manual(
    values = c("Deceased Characters" = "gray",
               "Living Characters"   = "#a0dcff"),
    name = "Status"
  ) +
  labs(
    title = "Gender Ratio by Appearance & Living Status",
    x     = "# of Appearances",
    y     = "Female/Male Ratio"
  ) +
  theme_minimal(base_family = "Optima") +
  theme(
    panel.background = element_rect(fill = "white", color = NA), plot.background = element_rect(fill = "white", color = NA),
    text = element_text(color = "black"), plot.title = element_text(hjust = 0.5, color = "black"),
    axis.text = element_text(color = "black"), axis.title = element_text(color = "black"),
    legend.title = element_text(color = "black"), legend.text = element_text(color = "black"),
    panel.grid.major = element_line(color = "grey90"), panel.grid.minor = element_blank()
  )

ggsave("figs/fig2.png", fig2)
#fig2
