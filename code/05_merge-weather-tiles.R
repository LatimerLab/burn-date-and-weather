## Merge the 1000s of gridmet tiles for each metric-year combo into a single continuous raster

library(terra)
library(tidyverse)

#### Set Geospatial Data Directory (wherever you saved raw data downloaded from Box): ####
geo_dir <- "/mnt/ofo-share-01/reburns"
setwd(geo_dir)




#### Load the tiles for specfic variable-year combos to make sure we have produced all the tiles ####
gmet_vars = c("erc","fm100","fm1000","th","vpd","vs")
years = 2002:2021

var_year = expand.grid(var = gmet_vars, year = years)

var_year = var_year %>%
  mutate(across(everything(),as.character))

merge_tiles = function(i) {
  
  var_year_foc = var_year[i,]
  
  cat("Merging",  var_year_foc$var,   var_year_foc$year, "\n")
  
  tiles = list.files(paste0(geo_dir,"/dob-weather-tiles/"),pattern=paste0(var_year_foc$var,"-",var_year_foc$year,"-[0-9]*\\.tif"), full.names=TRUE)
  
  # make a VRT and save as a single tif
  weather <- vrt(tiles,paste0("/mnt/ofo-share-01/reburns/dob-weather-merged-vrt/",var_year_foc$var,"-",var_year_foc$year,".vrt"), overwrite=TRUE)
  writeRaster(weather,paste0("/mnt/ofo-share-01/reburns/dob-weather-merged-tif/",var_year_foc$var,"-",var_year_foc$year,".tif"), overwrite=TRUE)

  gc()
}

walk(1:nrow(var_year),merge_tiles) #, .options=furrr_options(scheduling=Inf, chunk_size=NULL)
