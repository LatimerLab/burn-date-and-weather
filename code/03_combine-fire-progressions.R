#### Description ####

# Code adapted from Ali Paulson: https://github.com/akpaulson/2020_Fires_GEB/blob/main/Code/02_combine_fire_progressions.R

# Take fire progressions (one for each fire) and produce a raster that combines the progression information across each year into one raster 

#### Packages ####

library(terra)
library(sf)
library(dplyr)
library(stringr)
library(furrr)

# Set Geospatial Data Directory (wherever you placed data downloaded from Box): 

geo_dir <- "/mnt/ofo-share-01/reburns/"


# #### Get top 40 fire names ####
# 
# #I made a shapefile for the perimeters of just the top 40 fires in the
#   # get_fire_perim_make_90m_grid.R code. Get list of names for top 40 fires: 
# perim_40 <- as.data.frame(st_read("InProcessData/perim_2020_top40.shp")) %>% 
#   select(FIRE_NAME)
# 
# fires <- unique(perim_40$FIRE_NAME)

#### Bring in fire progression rasters for top 40 fires ####

#Get list of folders in the fire progression folder (these are from Derek Young's
  # fire progression Box folder): 

merge_year = function(year) {
  
  folder_list <- list.files(path = paste0(geo_dir, paste0("dob/",year)), full.names = TRUE)
  
  # #subset to the folders associated with our 40 biggest fires: 
  # folder_list_fires <- str_subset(folder_list, paste(fires, collapse = "|"))
  # #Note that Red salmon complex and Gold fire are missing - email to DY on 5/18/21 
  #   # to ask to run these progressions. 
  
  #Now, pull out file paths to the .tif files associated with fire progressions: 
  files <- NA
  
  for (i in 1:length(folder_list)){
    
    a <- list.files(path = folder_list[i], pattern = "dob.tif$", full.names = TRUE)
    files = c(files, a)
  }
  
  # reverse the file list so that if a location burned twice in one year, use the date of the first time it burned that year
  files = rev(files)
  
  files <- files[-1] #remove NA
  
  files #looks correct
  
  prog <- vrt(files,paste0("/mnt/ofo-share-01/reburns/dob-merged/",year,".vrt"), overwrite=TRUE)
  
  writeRaster(prog,paste0("/mnt/ofo-share-01/reburns/dob-merged/",year,".tif"), overwrite=TRUE)

}

plan(multisession, workers=3)
future_walk(2002:2019,merge_year)
