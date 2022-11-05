#### Description ####

# Adapted from Alison Paulson: https://github.com/akpaulson/2020_Fires_GEB/blob/main/Code/03_extract_gridMET.R

# This code will extract gridMET weather data for each point/pixel within a fire based on the day it burned
# gridMET data were downloaded from http://www.climatologylab.org/gridmet.html


#### Packages  & set up  ####

library(ncdf4)
library(terra)
library(chron) #to deal with dates in netCDF
library(lubridate)
library(tidyr)
library(dplyr)
library(stringr)
library(sf)
library(furrr)

#### Set Geospatial Data Directory (wherever you saved raw data downloaded from Box): ####
geo_dir <- "/mnt/ofo-share-01/reburns"
setwd(geo_dir)


#### Make a grid of the focal area to extract to ####
# Based on western US states
aoi = st_read("focal-region/western-us-states.gpkg")
tiles = st_make_grid(aoi,cellsize=25000)




#### Begin extraction for each year-variable-tile combo ####
gmet_vars = c("erc","fm100","fm1000","th","vpd","vs")
gmet_vars = c("vpd","vs")
years = 2002:2021

for(year in years) {
    
    #Load in fire progressions for year
    prog <- rast(paste0("dob-merged/",year,".tif"))
    
    # Exclude tiles that are outside the progression layer for this year
    keeps = st_intersects(tiles,as.polygons(prog,extent=TRUE) %>% st_as_sf, sparse=FALSE)
    tiles_focs = tiles[keeps]
    
    
    for(gmet_var in gmet_vars) {
      
      
      #### Prep a gridmet layer (variable and year) for extraction ####
      
      # Bring in gridmet data as a raster brick: 
      #EPSG = 4326 --> GCS WGS 1984
      gmet_file = paste0("gridmet/",gmet_var,"_",year,".nc")
      gm <- rast(gmet_file)
      
      #Name each layer of brick by its Julian date
      names(gm) <- 1:nlyr(gm)
      

      for(tile_index in 1:length(tiles_focs)) {
        
        cat("Running",gmet_var, year,"for tile", tile_index, "of", length(tiles_focs),"\n")
        
        tile_name = paste0("dob-weather-tiles/", gmet_var,"-",year,"-",tile_index,".tif")
        tile_name_dummy = paste0("dob-weather-tiles/", gmet_var,"-",year,"-",tile_index,".txt")
        
        if(file.exists(tile_name) | file.exists(tile_name_dummy)) {
          cat("Already exists, skipping.\n")
          next()
        }
      

        tile_foc = tiles_focs[tile_index]
        # get progression for focal tile
        prog_foc = crop(prog,tile_foc)
        
        gc()
        
        ## Get the points to extract to: the raster grid cells
        grid_foc = as.points(prog_foc)
        names(grid_foc) = "dob"
        
        # Some tiles have no burns in them data, can skip them
        if(nrow(grid_foc) == 0) {
          cat("No burns, skipping.\n")
          write.csv(data.frame(a=1), tile_name_dummy)
          next()
        }
        
        
        #Extract gridmet values for each grid point (projection
        # already matched to gridMET data above), output as matrix: 
        grid_foc_proj = project(grid_foc,gm)
        gm_foc = crop(gm,tile_foc %>% st_buffer(10000) %>% st_transform(st_crs(gm)))
        
        gc()
        gm_extract <- terra::extract(gm_foc, grid_foc_proj, method="bilinear")
        gc()
        #Since the extracted data is a matrix with 2,019,660 rows (one row
        # for each grid point) and 366 columns (one column for each day
        # of the year in 2020), we can use matrix indexing to pull out
        # the weather variable for the day of interest for each grid point. 
        
        # Create matrix index to pull out rows/columns for each grid point. 
        # Row numbers represent the grid point number (1:2,019,660)
        # columns represent the day of burn for that grid point. We want
        # to pull out the weather variable corresponding only to the day of 
        # burn for the given grid point: 
        gm_index_df <- data.frame(rows = 1:length(grid_foc_proj$dob), 
                                  dob = grid_foc_proj$dob)
        
        #Now, use the matrix index to extract the weather variable for each
        # gridpoint/day of burn: 
        gm_for_dob <- gm_extract[as.matrix(gm_index_df)]
        grid_foc$gm = gm_for_dob
        
        # Back to raster
        gm_dob_foc = rasterize(grid_foc,prog_foc,field="gm")
        

        writeRaster(gm_dob_foc,tile_name, overwrite=TRUE)
      
        gc()
      
      }
    
    }
}