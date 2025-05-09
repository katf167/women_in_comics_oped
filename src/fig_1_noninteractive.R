library(dplyr)
library(ggplot2)
#load the data
marvel <- read.csv('data/marvel_data.csv')
dc <- read.csv('data/dc_data.csv')

na_check <- function(x) !is.na(x) & trimws(x) != ""

#drop nas for sex, align, and alive for now 
#(might need to drop more rows later but not a lot of missing data)
cleaned_m <- marvel |>
  filter(if_all(c(SEX, ALIGN, ALIVE), na_check))


cleaned_dc <- dc |>
  filter(if_all(c(SEX, ALIGN, ALIVE), na_check))

#combine the two datasets!
marvel_dc <- bind_rows(
  cleaned_dc |>
    select(SEX, ALIGN, alive = ALIVE, year = YEAR, appearances = APPEARANCES) |>
    mutate(company = "dc"),
  cleaned_m |>
    select(SEX, ALIGN, alive = ALIVE, year = Year, appearances = APPEARANCES) |>
    mutate(company = "marvel")
)

#percentage of alignment by gender for both comic companies
#clarification: filtering for male/female and good/bad/neutral characters due to
#minimal data in transgender/agender characters and other alignments

alignment_by_gender <- marvel_dc |>
  filter(SEX %in% c("Male Characters","Female Characters"),
         ALIGN %in% c("Good Characters","Bad Characters","Neutral Characters")) |>
  count(SEX, ALIGN, company) |>
  group_by(SEX) |>
  mutate(percentage = n / sum(n)) |>
  mutate(combo  = interaction(SEX, ALIGN, company, sep = "_")) |>
  ungroup()

#hex codes for colors used in figure
my_colors <- c(
  "marvel" = "#e23636",
  "dc"     = "#a0dcff"
)

#plot!
figure1 <- ggplot(alignment_by_gender, aes(x = percentage, y = ALIGN, fill = company)) +
  geom_col(width = 0.35) +
  facet_wrap(~SEX, ncol = 1) +
  scale_fill_manual(values = my_colors, name = "Universe") +
  labs(
    title = "Character Alignment by Sex across Marvel and DC",
    x = "Percentage of Characters",
    y = "Alignment",
    caption = "Figure 1"
  ) +
  theme_minimal() +
  theme(
    panel.background = element_rect(fill = "white", color = NA),
    plot.background  = element_rect(fill = "white", color = NA),
    text= element_text(family = "Optima", color = 'black'),
    plot.title = element_text(hjust = 0.5),
    panel.grid.major.y = element_blank()
  )

ggsave("figs/fig1.png", figure1)

figure1
