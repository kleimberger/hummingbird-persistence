#########################################
##Function for summarizing resource data
########################################

# See below for summarizing function to calculate sighting rates.
# 
# Inputs are the lowest (i.e., finest) levels you want in the organizational hierarchy (patch, plant species, individual plant/camera number) and in time (experimental phase, date).
# Also need to indicate whether the sighting data should be total sightings, or broken down by bird type (i.e., GREH/VISA versus non-GREH/VISA) or hummingbird species, as is needed to create networks.
# 
# Organizational hierarchy
# 
# - Patch
# - Plant species
# - Individual plant (camera number)
# 
# Time
# 
# - Experimental phase (pre/post)
# - Date
# 
# Bird type 
# 
# - Functional group: Green hermits/violet sabrewings, etc.
# - Hummingbird species


#Function to calculate sighting rates
#Argument 'include_unknown_spp' refers to unknown species. Only relevant if summarizing all species (combined or separately), not certain groups (e.g., GREH/VISA)
#Argument 'sightings' can be either 'all' (no filtering), 'with_visit', or 'honest_visit'
#Argument 'marked' can be either 'all' (no filtering), 'unmarked' or 'marked'
#Default arguments reflect single overall network across sites, years
calculate_sighting_rates <- function(data, level_org = "plant_species_across_sites", level_time = "all", level_bird = "individual_marked", sightings = "with_visit", marked = "all", include_unknown_spp = FALSE){
  
  #---------------------------------------------------------------------
  #Define the variables of interest (levels at which to summarize data)
  #---------------------------------------------------------------------
  #'vars' = the variables to summarize the data by
  if(level_org == "patch"){vars = c("year", "patch", "control_treatment")} #Patch within a year. NOT PATCH GENERALLY.
  if(level_org == "plant_species"){vars = c("year", "patch", "control_treatment", "plant_species")} #Plant species within a patch. NOT PLANT SPECIES GENERALLY.
  if(level_org == "plant_species_across_sites"){vars = c("plant_species")} #Plant species across all patches. THIS IS WHAT IS USED FOR WEIGHTING RESOURCE DATA.
  if(level_org == "camera_num"){vars = c("year", "patch", "control_treatment", "plant_species", "camera_num", "camera_id")}

  if(level_time == "exp_phase"){vars = append(vars, "exp_phase")}
  if(level_time == "date_video"){vars = append(vars, c("exp_phase", "date_video"))}
  if(level_time == "all"){vars = vars}  

  #---------------------------------------------------------------------
  #Subset sightings according to certain visit criteria
  #---------------------------------------------------------------------
  #Remove videos with no sightings, because when summarise sightings, want each row to equal a sighting. Will fill in zero sightings when join to effort summary
  data_sightings <- data %>% 
    filter(!(sightings_yes_or_no == "N"))
  
  if(sightings == "all"){data_sightings <- data_sightings} #Do not filter out sightings based on visit type
  if(sightings == "with_visit"){data_sightings <- data_sightings %>% filter(visit_type != "none")} #Only look at sightings with confirmed visit
  if(sightings == "honest_visit"){data_sightings <- data_sightings %>% filter(visit_type == "honest" | visit_type == "honest_and_rob")} #Only look at sightings with confirmed honest visit

  if(marked == "all"){data_sightings <- data_sightings} #Do not filter out sightings based on mark status
  if(marked == "marked"){data_sightings <- data_sightings %>% filter(mark_status == "Marked")}
  if(marked == "unmarked"){data_sightings <- data_sightings %>% filter(mark_status == "Unmarked")}
  
  #-----------------------------------------
  #Subset sightings to bird group of interest
  #-----------------------------------------
  bird_vars = vars #Set bird_vars to vars here. Will override below if want a summary for individual bird species
  
  #All bird species considered separately, not grouped together. This species-level summary is what is needed to create networks
  if(level_bird == "camera_spp_separate"){
    
    bird_vars = append(vars, "bird_species")
    
  }
  
  #All bird species considered separately, not grouped together. This species-level summary is what is needed to create networks
  if(level_bird == "camera_spp_separate_sex"){
    
    bird_vars = append(vars, c("bird_species", "bird_sex"))
    
  }
  
  #Individually marked birds
  if(level_bird == "individual_marked"){
    
    bird_vars = append(vars, c("bird_species", "color_id"))
    
    data_sightings <- data_sightings %>%
      filter(!is.na(colors) & colors != "None" & colors != "M" & colors != "U") %>% #Remove birds without distinguishable marks
      filter(color_id != "2018_29_STRH_B") #This mark is duplicated, not distinguishable
    
  }
  
  #Remove unknown species (cannot definitively say what bird group they belong in)
  if(include_unknown_spp == FALSE){
    
    data_sightings <- data_sightings %>%
      filter(bird_species != "U")
    
  }
  
  #------------BIRD GROUPS/TYPES------------#
  
  #Use camera data indicating 'normal' visitation for establishing species groups (i.e., which birds visit which species)
  #All species ever seen on camera. No additional subsetting, N = 17 species
  if(level_bird == "camera_spp_combined"){
    
    data_sightings <- data_sightings %>%
      mutate(bird_type = "camera_spp_combined")
    
  }
  
  #Filter to named list of bird species codes. Name should be input as whatever you want the bird group to be. e.g., list(greh_visa = c("GREH", "VISA"))
  if(is.list(level_bird)){
    
    data_sightings <- data_sightings %>%
      mutate(bird_group = ifelse(bird_species %in% unlist(level_bird), names(level_bird), NA)) %>%
      filter(!is.na(bird_group))
    
    level_bird <- names(level_bird) #just use the names for subsetting
    
  }
  
  #-----------------------------------------
  #Summarize sightings
  #-----------------------------------------
  sum_sightings <- data_sightings %>%
    group_by_at(bird_vars) %>%  #If not summarizing by individual bird species, then this is just vars.
    summarise(sightings = n()) %>%
    ungroup()
  
  #-----------------------------------------
  #Summarize sighting duration (how long the flower was visited, across all sightings)
  #-----------------------------------------
  sum_sightings_time <- data_sightings %>%
    group_by_at(bird_vars) %>%  #If not summarizing by individual bird species, then this is just vars.
    summarise(sightings_time = sum(sighting_length, na.rm = TRUE)) %>%
    ungroup()
  
  #-----------------------------------------
  #Summarize effort and number of flowers
  #-----------------------------------------
  
  #To create effort/flower summaries, need to reduce to the finest level and get unique values using 'distinct'
  vars_effort <- c("year", "patch", "control_treatment", "plant_species", "camera_num", "camera_id", "date_video", "exp_phase", "file_id", "video_length") #Effort is calculated at level of FILE ID
  vars_flowers <- c("year", "patch", "control_treatment", "plant_species", "camera_num", "camera_id", "date_video", "exp_phase", "flowers_camera_video") #Number of flowers is calculated at level of DATE
  
  #Effort summary (how long the video recorded)
  sum_effort <- data %>%
    select(all_of(vars_effort)) %>%
    distinct() %>%
    group_by_at(vars) %>% 
    summarise(hours = sum(video_length, na.rm = TRUE)) %>%
    ungroup()
  
  #Flower summary (how many flowers were available each day)
  #If summarizing at level of date, this will just be the number of flowers on that day. If summarizing at the level of experimental phase, this will be average number of flowers per day.
  #Days with zero flowers have already been removed
  sum_flowers <- data %>%
    select(all_of(vars_flowers)) %>%
    distinct() %>%
    group_by_at(vars) %>%
    summarise(flowers = mean(flowers_camera_video, na.rm = TRUE)) %>%
    ungroup()
  
  #----------------------------------------------------------------
  #Join to effort and flower summaries + calculate sighting rates
  #----------------------------------------------------------------
  
  #If not summarizing by individual bird species, this is pretty straightforward.
  rates <- sum_effort %>%
    left_join(sum_flowers) %>%
    left_join(sum_sightings) %>%
    left_join(sum_sightings_time) %>%
    mutate(sightings = ifelse(is.na(sightings), 0, sightings)) %>% #Fill in zero sightings
    mutate(sightings_per_hour = sightings/hours) %>% #Sighting rate without controlling for number of flowers
    mutate(bird_group = level_bird) #Add info about any subsetting that was done
  
  #If summarizing at level of individual bird species, it's a bit more complicated.
  #Need to fill in zero sightings for each possible species per patch/camera/etc, i.e., make IMPLICITLY missing bird species EXPLICITLY missing bird species so can compare pre and post.
  if(level_bird == "camera_spp_separate"){
    
    nesting_vars <- append(vars, c("hours", "flowers"))
    nesting_vars <- syms(nesting_vars) #with 'ensyms', get an error saying only strings can be converted to symbols. 'syms' converts a character names vector into a list of symbols
    
    rates <- sum_effort %>%
      left_join(sum_flowers) %>%
      left_join(sum_sightings) %>%
      complete(bird_species, nesting(!!!nesting_vars), fill = list(sightings = 0)) %>%
      filter(!is.na(bird_species)) %>% #Remove NAs in the bird column. NAs were introduced for zero sightings
      mutate(sightings_per_hour = sightings/hours) %>% 
      mutate(bird_group = level_bird)
    
  }
  
  #This is currently hard-coded to summarize sightings to level of plant species (within site) + experimental phase, then fill in zeroes for pre/post (if individual was only associated with that plant species during one period)
  if(level_bird == "individual_marked" & level_org == "plant_species" & level_time == "exp_phase"){
  
    sum_sightings_complete <- sum_sightings %>%
      group_by(year, patch, control_treatment) %>%
      complete(exp_phase, nesting(bird_species, color_id, plant_species), fill = list(sightings = 0)) %>%
      ungroup()
    
    rates <- sum_effort %>%
      left_join(sum_flowers) %>%
      left_join(sum_sightings_complete) %>%
      filter(!is.na(color_id)) %>%
      mutate(sightings_per_hour = sightings/hours) %>% 
      mutate(bird_group = level_bird) %>%
      arrange(color_id, plant_species)
    
  }
  
  return(rates)
  
}

###############################################
##Function to convert sighting rates to weights
###############################################
#I.e., normalize sighting rates to be between 0 and 1 by dividing by maximum rate
rates_to_weights <- function(rate_data, level_bird){
  
  if(level_bird == "camera_spp_separate"){
  
  weights <- rate_data %>%
    group_by(bird_species) %>%
    arrange(desc(sightings_per_hour)) %>%
    mutate(max_rate = max(sightings_per_hour)) %>%
    mutate(rank = 1:length(sightings_per_hour)) %>%
    ungroup() %>%
    mutate(weight = sightings_per_hour/max_rate)
  
  return(weights)
  
  }
  
  #For other subsets, do not need to group by subset. Just calculate rate based on max value.
  weights <- rate_data %>%
    arrange(desc(sightings_per_hour)) %>%
    mutate(max_rate = max(sightings_per_hour)) %>%
    mutate(rank = 1:length(sightings_per_hour)) %>%
    mutate(weight = sightings_per_hour/max_rate)
  
  return(weights)
  
}