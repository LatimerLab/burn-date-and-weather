#### Prep to feed fire data into the function (list of list of fire.shp, fire.hotspots)
## Makes a list of the three elements (fire name, fire perim, fire hotspots) needed to feed into the main DOB mapping function

library(FNN)
library(timeDate)
library(raster)
library(fasterize)
library(sf)
library(lubridate)
# Added by DYoung:
library(tidyverse)
library(here)
library(chron)
library(furrr)
plan(multisession(workers=32))

## Added by DYoung:
# The root of the data directory
data_dir = "/mnt/ofo-share-01/reburns/"
# Convenience functions, including function datadir() to prepend data directory to a relative path
datadir = function(dir) {
  return (paste0(data_dir,dir))
}
# End added.


# Year of fires. You will need to modify this file if you have several years to process
year <- 2021 # <- mod by DYoung. Originai: fire.perims$Year[1]


# set projection; this is the standard projection used by many national (USA) programs

the.prj <- "+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=23 +lon_0=-96 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs"




# This is a shapefile of fire perimeters
# Note this is set up to run on the MTBS fire history shapefile

fire.perims = st_read(datadir("perims/mtbs_west_fs_nps_sub_updated21.shp"))
fire.perims = fire.perims %>%
  filter(Fire_Year > 2019) %>%
  rename(Year = Fire_Year) %>%
  filter(Year == year)





## Get MODIS fire detections

hotspots <- st_read(datadir("hotspots/fire_archive_M-C61_306333.shp"))
hotspots <- hotspots[, c('LATITUDE', 'LONGITUDE', 'ACQ_DATE', 'ACQ_TIME', 'SATELLITE', 'INSTRUMENT')]

## Get VIIRS fire detections
if (year >= 2012) {
  hotspots3 <- st_read(datadir("hotspots/fire_archive_SV-C2_306334.shp"))
  hotspots3 <- hotspots3[, c('LATITUDE', 'LONGITUDE', 'ACQ_DATE', 'ACQ_TIME', 'SATELLITE', 'INSTRUMENT')]
  hotspots <- rbind(hotspots, hotspots3) # Combine MODIS and VIIRS
}


## DYoung addition: filter hotspots to the focal year
hotspots = hotspots %>%
  filter(str_sub(ACQ_DATE,1,4) == year)

hotspots = hotspots %>% st_transform(the.prj)


fire.list <- unique(subset(fire.perims, Year == year)$Fire_ID)


prep_fire_data = function(i) {
  
  
  fire <- fire.list[[i]]
  
  cat("Running for fire",i,"      \r")
  
  fire.shp <- subset(fire.perims, Fire_ID == fire)
  
  fire.shp.prj <- st_transform(fire.shp, crs=the.prj)
  fire.shp.buffer.prj <- st_buffer(fire.shp.prj, dist=750)
  fire.shp.buffer.dd <- st_transform(fire.shp.buffer.prj, projection(fire.shp))
  
  # If there are clearly times when a fire should not be burning, those boundaries can be set here. Sometimes the fire detection
  # data picks up on industrial activities or slash pile burning or ???. The numbers correspond to Julian day.
  
  
  # DYoung removed:
  # # Again, if there are dates for specific fires that are invalid, they can be stated here. The numbers correspond to Julian day.
  # 
  # if (fire == 'MT4715311245620170723') {
  # 	min.date <- 200; max.date <- 300 }
  
  
  # This actually selects fire detections points relevant to the fire of interest
  
  fire.hotspots <- hotspots[fire.shp.buffer.dd,]
  
  fire_data_element = list(fire = fire,
                           fire.shp = fire.shp,
                           fire.hotspots = fire.hotspots)
  
  gc()
  
  return(fire_data_element)
  
}

l = future_map(1:length(fire.list),prep_fire_data)

saveRDS(l,datadir(paste0("prepped-firedata-for-dob-mapping/prepped-firedata-for-dob-mapping_",year,".rds")))

# l = readRDS(datadir(paste0("prepped-firedata-for-dob-mapping/prepped-firedata-for-dob-mapping_",year,".rds")))
