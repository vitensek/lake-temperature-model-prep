find_parser <- function(coop_wants, parser_filehash) {

  parser_files <- yaml::yaml.load_file(parser_filehash) %>% names()
  parser_env <- new.env()
  sapply(parser_files, source,  parser_env)

  parser_fxns <- ls(envir = parser_env)

  parsers <- c()

  for (i in 1:length(coop_wants)) {

    if (grepl('manualentry', coop_wants[i])) {
      parsers[i] <- 'parse_manualentry_files'

    } else if (grepl('winnie\\D', coop_wants[i], ignore.case = TRUE)) {
      parsers[i] <- 'parse_winnie_files'

    }  else if (grepl('DNRdatarequest', coop_wants[i])){
      parsers[i] <- 'parse_mndnr_files'

    }  else if (grepl('lower_red|upper_red', coop_wants[i])) {
      parsers[i] <- 'parse_upper_lower_redlake_files'

    }  else {
      parsers[i] <- paste0('parse_', tools::file_path_sans_ext(coop_wants[i]))
    }

  parser_exists <- parsers %in% parser_fxns

  }

  if (!all(parser_exists)) {
    stop(paste0('Cooperator data file(s) ', paste0(coop_wants[which(parser_exists == FALSE)], collapse = ', '), ' do not have parsers. Please write a parser and save to 7a_temp_coop_munge/src/data_parser'))
  }

  parsers_list <- as.list(parsers)
  names(parsers_list) <- coop_wants
  return(parsers_list)
}

call_parser <- function(outind, inind, parsers, task_name) {
  parser <- parsers[[task_name]]
  do.call(parser, list(inind, outind))
}

create_coop_munge_taskplan <- function(wants, parsers) {


  # this step finds the appropriate parser, reads in data, parses data, then writes a .rds file and .rds.ind file
  coop_munge_step1 <- scipiper::create_task_step(
    step_name = 'parse_and_write',
    target_name = function(task_name, ...) {
      file.path('7a_temp_coop_munge/tmp', paste0(tools::file_path_sans_ext(task_name), '.rds.ind'))
    },
    command = function(task_name, ...) {
      sprintf("%s(outind = target_name, inind = '6_temp_coop_fetch/in/%s')", parsers[[task_name]], as_ind_file(task_name))
    }
  )

  coop_munge_step2 <- scipiper::create_task_step(
    step_name = 'require_local',
    target_name = function(task_name, ...) {
      sprintf("7a_temp_coop_munge/tmp/%s", paste0(tools::file_path_sans_ext(task_name), '.rds'))
    },
    command = function(target_name, ...) {
      sprintf("require_local(ind_file = '%s')", as_ind_file(target_name))
    }
  )

  # This should first check for the out/.ind file for the parsed data? or depend on the .ind file?

  task_plan <- scipiper::create_task_plan(
    task_names = wants,
    task_steps = list(coop_munge_step1, coop_munge_step2),
    add_complete = FALSE,
    final_steps = 'parse_and_write'
  )

  return(task_plan)
}

create_coop_munge_makefile <- function(target_name, taskplan, final_targets) {
  create_task_makefile(
    makefile = target_name,
    task_plan = taskplan,
    packages = c('scipiper', 'dplyr', 'readxl', 'assertthat', 'RODBC', 'tidyselect'),
    file_extensions = c("ind"),
    include = c('6_temp_coop_fetch.yml', '7a_temp_coop_munge.yml'),
    sources = c('7a_temp_coop_munge/src/data_parsers/parse_test_coop_data.R',
                '7a_temp_coop_munge/src/data_parsers/parse_wilter_files.R',
                '7a_temp_coop_munge/src/data_parsers/parse_vermillion_files.R',
                '7a_temp_coop_munge/src/data_parsers/parse_mndow_coop_files.R',
                '7a_temp_coop_munge/src/data_parsers/parse_manualentry_files.R',
                '7a_temp_coop_munge/src/data_parsers/parse_micorps_files.R',
                '7a_temp_coop_munge/src/data_parsers/parse_mndnr_files.R',
                '7a_temp_coop_munge/src/data_parsers/parse_winnie_files.R',
                '7a_temp_coop_munge/src/data_parsers/parse_wi_wbic_files.R',
                '7a_temp_coop_munge/src/data_parsers/parse_redlake_files.R',
                '7a_temp_coop_munge/src/data_parsers/parse_dakota_files.R',
                '7a_temp_coop_munge/src/data_parsers/parse_indiana_files.R',
                '7a_temp_coop_munge/src/data_parsers/parse_tenmile_files.R',
                '7a_temp_coop_munge/src/parsing_task_fxns.R',
                'lib/src/require_local.R',
                '7a_temp_coop_munge/src/data_parsers/parse_unit_functions.R'),
    final_targets = final_targets
    )
}
