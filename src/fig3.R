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

fig3_cleaned <- marvel_dc |>
  filter(SEX %in% c("Male Characters", "Female Characters"), !is.na(ALIGN)) |>
  mutate(
    gender = if_else(SEX == "Female Characters", "Female", "Male"),
    group = paste(gender, ALIGN, sep = " ")
  )

gender_alignment <- bind_rows(
  fig3_cleaned|> 
    count(group)|> 
    mutate(status="Overall"),
  fig3_cleaned|> 
    filter(alive=="Deceased Characters")|> 
    count(group)|> 
    mutate(status="Deceased"),
  fig3_cleaned|> 
    filter(alive=="Living Characters")|> 
    count(group)|> 
    mutate(status="Living")
)|>
  group_by(status)|>
  mutate(percentage = n/sum(n))|>
  ungroup()

#comic book palette!! (specifically marvel's logo)
custom_palette <- c(
  "Female Good Characters"= "#e23636", "Male Good Characters"= "#000000",
  "Female Neutral Characters"="#504a4a", "Male Neutral Characters"= "#518cca",
  "Female Bad Characters"= "#f78f3f", "Male Bad Characters"= "#906aa3"
)

# Three???panel pie chart
fig3 <- ggplot(gender_alignment, aes(x = "", y = percentage, fill = group)) +
  geom_col(width = 1) +
  coord_polar(theta = "y") +
  facet_wrap(~status, nrow = 1) +
  scale_fill_manual(values = custom_palette, name = "") +
  labs(title = "Character distribution by gender and moral alignment") +
  theme_void(base_family = "Optima") +
  theme(
    plot.title = element_text(hjust = 0.5, color = "black"),
    legend.title = element_text(color = "black"),
    legend.text = element_text(color = "black"),
    strip.text = element_text(color = "black"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("figs/fig3.png", fig3)
fig3
