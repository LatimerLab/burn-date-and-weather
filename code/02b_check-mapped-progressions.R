### Check the set of mapped progressions and make sure it's complete (compare against the perims used to create it)

library(sf)
library(tidyverse)
library(here)


# The root of the data directory
data_dir = "/mnt/ofo-share-01/reburns/"
# Convenience functions, including function datadir() to prepend data directory to a relative path
datadir = function(dir) {
  return (paste0(data_dir,dir))
}


# This is a shapefile of fire perimeters
# Note this is set up to run on the MTBS fire history shapefile

fire.perims = st_read(datadir("perims/mtbs_west_fs_nps_sub_updated21.shp"))
fire.perims = fire.perims %>%
  filter(Fire_Year > 2019) %>%
  rename(Year = Fire_Year)





## Get the set of fire names from the progressions that were written
progs = list.files(datadir("dob-new-final"))

## Get the fire names from the perims
perims = fire.perims$Fire_ID

## Get the perims that do not have a progression
unprocessed = setdiff(perims,progs)
unprocessed

## OK the only missing ones are as expected: very small with few/no hotspots detected