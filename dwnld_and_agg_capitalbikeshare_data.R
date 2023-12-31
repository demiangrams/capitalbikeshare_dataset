# This is an inefficient R script for downloading and aggregating the raw capital bikeshare trip data, is based in loops and growing the dataset by rowbinding :(
  
library(tidyverse)
library(janitor)


# exemplo de link
# https://s3.amazonaws.com/capitalbikeshare-data/2010-capitalbikeshare-tripdata.zip


anos <- seq(2010, 2015) |> as.character()

for (ano in seq_along(anos)) {

  # construir a URL (já sabendo o padrão)
  url <- paste0("https://s3.amazonaws.com/capitalbikeshare-data/", 
                anos[ano], 
                "-capitalbikeshare-tripdata.zip")
  
  # criar objeto temporário e baixar os dados nesse objeto
  temp <- paste0("temp_", anos[ano], ".zip")
  download.file(url, temp)
  unzipped_files <- unzip(temp)
  
  # pode ser que no arquivo zipado tenha mais de um arquivo .csv entao vamos
  # "crescer" um dataset empilhando por linhas os TRIMESTRES com um bind_rows()
  for (file in seq_along(unzipped_files)) {
    
    if (file == 1) {
      growing_df <- read.csv(unzipped_files[file])
    } else {
      growing_df <- bind_rows(growing_df, read.csv(unzipped_files[file]))
    }
  }
  
  # ineficientemente também vamos crescer o dataset empilhando os datasets dos ANOS
  # ou seja, bind_rows(df2010, df2011, df2012, ...)
  if (ano == 1) {
    another_growing_df <- growing_df
  } else {
    another_growing_df <- bind_rows(another_growing_df, growing_df)
  }

  
  # reestruturar o dataframe para agrupar a contagem de locações por data e tipo de membro
  megazord_df <- another_growing_df |> 
    clean_names() |> 
    select(start_date, member_type) |> 
    mutate(member_type = tolower(member_type)) |> 
    group_by(start_date = date(start_date), member_type) |> 
    summarize(count = n())  |> 
    pivot_wider(names_from = member_type, 
                values_from = count, 
                values_fill = 0)
  
}

# como esse processo é demorado vou salvar o dataframe
write.csv(x = megazord_df, 
          file = "capitalbikeshare_countdata_2010_2015.csv")


# I asked chatGPT to optimize that code but I haven't even tried to run the code bellow...
# chatGPT -----------------------------------------------------------------

library(dplyr)
library(tidyr)
library(purrr)

# List of years
anos <- seq(2010, 2015) |> as.character()

# Initialize an empty list to store the data frames
data_frames <- list()

for (ano in anos) {
  # Construct the URL
  url <- glue::glue("https://s3.amazonaws.com/capitalbikeshare-data/{ano}-capitalbikeshare-tripdata.zip")
  
  # Download and unzip the file
  temp <- tempfile(fileext = ".zip")
  download.file(url, temp)
  unzipped_files <- unzip(temp)
  
  # Read and bind rows of all CSV files
  growing_df <- map_dfr(unzipped_files, read.csv)
  
  # Append the growing_df to the list
  data_frames <- append(data_frames, list(growing_df))
}

# Combine all data frames into a single data frame using bind_rows()
all_data <- bind_rows(data_frames)

# Process the combined data frame
megazord_df <- all_data %>%
  clean_names() %>%
  mutate(member_type = tolower(member_type)) %>%
  group_by(start_date = as.Date(start_date), member_type) %>%
  summarize(count = n()) %>%
  pivot_wider(names_from = member_type, values_from = count, values_fill = 0) |> 
  select(-unknown) |> 
  mutate(total = casual + member)
