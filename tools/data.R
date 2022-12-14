################################################################################
## 03. 데이터
################################################################################
##==============================================================================
## 03.01. 데이터 > 데이터 준비
##==============================================================================

##------------------------------------------------------------------------------
## 03.01.01. Alert Messages
##------------------------------------------------------------------------------
alert_message <- function(session, type = c("choice", "input", "be"),
                          name = NULL, coda = TRUE, message = NULL) {
  if (type %in% "be") {
    if (is.null(message))
      message <- "없습니다."
    
    title <- translate("정합성 오류")
    postfix <- ifelse(TRUE, "이", "가")
    text <- glue::glue("{name}{postfix} {message}")
  } else {
    postfix <- ifelse(TRUE, "을", "를")
    
    if (type %in% "input") {
      title <- translate("미입력 오류")
      text <- glue::glue("{name}{postfix} 입력하지 않았습니다.")
    } else {
      title <- translate("미선택 오류")
      text <- glue::glue("{name}{postfix} 선택하지 않았습니다.")
    }
  }
  
  shinyWidgets::sendSweetAlert(session = session,
                               title = title,
                               btn_labels = c("Ok"),
                               text = text,
                               type = "error"
  )
}


##------------------------------------------------------------------------------
## 03.01.02. 데이터 > 데이터 준비 > 데이터셋 관리, 데이터셋 목록 테이블 출력
##------------------------------------------------------------------------------
tab_data_list <- function(.data) {
  if (length(.data) == 0) {
    tab <- data.frame(
      dataset_id = character(0),
      dataset_name = character(0),
      dataset_desc = character(0),
      n_observation = integer(0),
      n_column = integer(0)
    ) %>%
      reactable(
        sortable = FALSE,
        columns = list(
          dataset_id = colDef(
            name = translate("데이터셋 아이디")
          ),
          dataset_name = colDef(
            name = translate("데이터셋 이름")
          ),
          dataset_desc = colDef(
            name = translate("데이터셋 설명")
          ),
          n_observation = colDef(
            name = translate("관측치 개수")
          ),
          n_column = colDef(
            name = translate("변수 개수")
          )
        )
      )
    
    return(tab)
  }
  
  dataset_name <- names(.data)
  
  tab <- dataset_name %>%
    purrr::map_df(
      function(x) {
        data.frame(
          dataset_name = .data[[x]]$dataset_name,
          dataset_desc = .data[[x]]$dataset_desc,
          n_observation = .data[[x]]$n_observation,
          n_column = .data[[x]]$n_column,
          dataset_id = .data[[x]]$dataset_id
        )
      }
    )
  
  tab %>%
    reactable(
      sortable = FALSE,
      selection = "single",
      onClick = "select",
      columns = list(
        dataset_id = colDef(
          name = translate("데이터셋 아이디")
        ),
        dataset_name = colDef(
          name = translate("데이터셋 이름")
        ),
        dataset_desc = colDef(
          name = translate("데이터셋 설명")
        ),
        n_observation = colDef(
          name = translate("관측치 개수"),
          format = colFormat(separators = TRUE)
        ),
        n_column = colDef(
          name = translate("변수 개수")
        )
      ),
      details = function(index) {
        tab_sample <- .data[[index]]$dataset %>%
          filter(row_number() <= 10) %>%
          reactable(
            sortable = FALSE
          )
        
        data_type <- .data[[index]]$dataset %>%
          dlookr::get_class() %>%
          reactable(
            sortable = FALSE,
            columns = list(
              variable = colDef(
                name = translate("변수 이름")
              ),
              class = colDef(
                name = translate("데이터 타입")
              )
            )
          )
        
        shiny::tabsetPanel(
          shiny::tabPanel(
            title = translate("변수 정보"), 
            data_type,
            hr(style = "border-top: 1px solid black;"),
            style = "padding-top:5px; padding-bottom:25px;"
          ),
          shiny::tabPanel(
            title = translate("샘플 데이터"), 
            tab_sample,
            hr(style = "border-top: 1px solid black;"),
            style = "padding-top:5px; padding-bottom:25px;"
          )
        )
      }
    )
}


##==============================================================================
## 03.02. 데이터 > 데이터 진단
##==============================================================================
##------------------------------------------------------------------------------
## 03.02.01. 데이터 > 데이터 진단 > 진단 개요
##------------------------------------------------------------------------------
diagnose_warning <- function(reportData, thres_uniq_cat = 0.5,
                             thres_uniq_num = 5, sample_percent = 100) {
  # Number of observations
  N <- NROW(reportData)
  
  # sampling with sample_percent
  if (sample_percent < 100) {
    N_sample <- ceiling(N * sample_percent / 100)
    idx <- sample(seq(N), size = N_sample)
    
    reportData <- reportData[idx, ]
  } else {
    N_sample <- N
  }
  
  # solve the overview
  ov <- overview(reportData)
  
  # diagnose the missing & unique
  diagn_na_unique <- diagnose(reportData)
  
  # diagnose the numeric
  diagn_numeric <- diagnose_numeric(reportData)
  
  tab_warning <- data.frame(
    warnings = character(5000), status = character(5000),
    variables = character(5000), types = character(5000),
    indicator = numeric(5000), ratio = numeric(5000),
    recommand = character(5000), stringsAsFactors = FALSE)
  
  # duplicate ------------------------------------------------------------------
  idx_last <- 0
  n_duplicate <- length(attr(ov, "duplicate"))
  
  if (n_duplicate > 0) {
    idx <- 1
    
    tab_warning$status[idx]    <- "duplicate"
    tab_warning$variables[idx] <- NA
    tab_warning$types[idx] <- NA
    tab_warning$indicator[idx] <- n_duplicate
    tab_warning$ratio[idx]     <- n_duplicate / N
    tab_warning$warnings[idx]  <- sprintf(
      "dataset has %s (%s%%) duplicated observations",
      format(n_duplicate, big.mark = ","),
      round(n_duplicate / N * 100, 1))
    tab_warning$recommand[idx]  <- "check"
  } else {
    idx <- NULL
  }
  
  # missing --------------------------------------------------------------------
  idx_last <- idx_last + length(idx)
  
  warn_miss <- diagn_na_unique %>%
    filter(missing_count > 0) %>%
    select(variables, types, missing_count, missing_percent) %>%
    arrange(desc(missing_count))
  
  if (nrow(warn_miss) > 0) {
    idx <- seq(nrow(warn_miss)) + idx_last
    
    tab_warning$status[idx]    <- "missing"
    tab_warning$variables[idx] <- warn_miss$variables
    tab_warning$types[idx]     <- warn_miss$types
    tab_warning$indicator[idx] <- warn_miss$missing_count
    tab_warning$ratio[idx]     <- warn_miss$missing_percent / 100
    tab_warning$warnings[idx]  <- sprintf(
      "%s has %s (%s%%) missing values", warn_miss$variables,
      format(warn_miss$missing_count, big.mark = ","),
      round(warn_miss$missing_percent, 1))
    tab_warning$recommand[idx]  <- "judgement"
  } else {
    idx <- NULL
  }
  
  # cardinality: identifier ----------------------------------------------------
  idx_last <- idx_last + length(idx)
  
  warn_identifier <- diagn_na_unique %>%
    filter(unique_rate == 1) %>%
    select(variables, types, unique_count, unique_rate)
  
  if (nrow(warn_identifier) > 0) {
    idx <- seq(nrow(warn_identifier)) + idx_last
    
    tab_warning$status[idx]     <- "cardinality"
    tab_warning$variables[idx]  <- warn_identifier$variables
    tab_warning$types[idx]      <- warn_identifier$types
    tab_warning$indicator[idx]  <- warn_identifier$unique_count
    tab_warning$ratio[idx]      <- warn_identifier$unique_rate
    tab_warning$warnings[idx]   <- sprintf(
      "%s has high(%.2f) cardinality, Maybe identifier",
      warn_identifier$variables, warn_identifier$unique_rate)
    tab_warning$recommand[idx]  <- "check"
  } else {
    idx <- NULL
  }
  
  # cardinality: constant ------------------------------------------------------
  idx_last <- idx_last + length(idx)
  
  warn_constant <- diagn_na_unique %>%
    filter(unique_count == 1) %>%
    select(variables, types, unique_count, unique_rate)
  
  if (nrow(warn_constant) > 0) {
    idx <- seq(nrow(warn_constant)) + idx_last
    
    tab_warning$status[idx]     <- "cardinality"
    tab_warning$variables[idx]  <- warn_constant$variables
    tab_warning$types[idx]      <- warn_constant$types
    tab_warning$indicator[idx]  <- warn_constant$unique_count
    tab_warning$ratio[idx]      <- warn_constant$unique_rate
    tab_warning$warnings[idx]   <- sprintf(
      "%s has constant value \"%s\"",
      warn_constant$variables,
      reportData[1, warn_constant$variables %>% as.character()] %>%
        t() %>%
        as.vector()
    )
    tab_warning$recommand[idx]  <- "remove"
  } else {
    idx <- NULL
  }
  
  # cardinally: high cardinality(category) -------------------------------------
  idx_last <- idx_last + length(idx)
  
  warn_unique_cat <- diagn_na_unique %>%
    filter(types %in% c("character", "factor", "ordered", "Date", "POSIXct")) %>%
    filter(unique_rate >= thres_uniq_cat & unique_rate < 1) %>%
    select(variables, types, unique_count, unique_rate)
  
  if (nrow(warn_unique_cat) > 0) {
    idx <- seq(nrow(warn_unique_cat)) + idx_last
    
    tab_warning$status[idx]     <- "cardinality"
    tab_warning$variables[idx]  <- warn_unique_cat$variables
    tab_warning$types[idx]      <- warn_unique_cat$types
    tab_warning$indicator[idx]  <- warn_unique_cat$unique_count
    tab_warning$ratio[idx]      <- warn_unique_cat$unique_rate
    tab_warning$warnings[idx]   <- sprintf(
      "%s has a high cardinality. %s (%s%%) distinct values",
      warn_unique_cat$variables,
      format(warn_unique_cat$unique_count, big.mark = ","),
      round(warn_unique_cat$unique_rate * 100, 1))
    tab_warning$recommand[idx]  <- "judgement"
  } else {
    idx <- NULL
  }
  
  # cardinally: low cardinality(numerical) -------------------------------------
  warn_unique_num <- diagn_na_unique %>%
    filter(types %in% c("numeric", "integer")) %>%
    filter(unique_count <= thres_uniq_num & unique_count > 1) %>%
    select(variables, types, unique_count, unique_rate)
  
  if (nrow(warn_unique_num) > 0) {
    idx <- seq(nrow(warn_unique_num)) + idx_last
    
    tab_warning$status[idx]     <- "cardinality"
    tab_warning$variables[idx]  <- warn_unique_num$variables
    tab_warning$types[idx]      <- warn_unique_num$types
    tab_warning$indicator[idx]  <- warn_unique_num$unique_count
    tab_warning$ratio[idx]      <- warn_unique_num$unique_rate
    tab_warning$warnings[idx]   <- sprintf(
      "%s has a low cardinality. %s (%s%%) distinct values",
      warn_unique_num$variables,
      format(warn_unique_num$unique_count, big.mark = ","),
      round(warn_unique_num$unique_rate * 100, 1))
    tab_warning$recommand[idx]  <- "judgement"
  } else {
    idx <- NULL
  }
  
  # zeros ----------------------------------------------------------------------
  idx_last <- idx_last + length(idx)
  
  warn_zero <- diagn_numeric %>%
    filter(zero > 0) %>%
    select(variables, zero) %>%
    arrange(desc(zero))
  
  if (nrow(warn_zero) > 0) {
    idx <- seq(nrow(warn_zero)) + idx_last
    
    tab_warning$status[idx]     <- "zero"
    tab_warning$variables[idx]  <- warn_zero$variables
    tab_warning$types[idx]      <- NA
    tab_warning$indicator[idx]  <- warn_zero$zero
    tab_warning$ratio[idx]      <- warn_zero$zero / N
    tab_warning$warnings[idx]   <- sprintf(
      "%s has %s (%s%%) zeros", warn_zero$variables,
      format(warn_zero$zero, big.mark = ","), round(warn_zero$zero / N * 100, 2))
    tab_warning$recommand[idx]  <- "check"
  } else {
    idx <- NULL
  }
  
  # cardinally: negative -------------------------------------------------------
  idx_last <- idx_last + length(idx)
  
  warn_minus <- diagn_numeric %>%
    filter(minus > 0) %>%
    select(variables, minus) %>%
    arrange(desc(minus))
  
  if (nrow(warn_minus) > 0) {
    idx <- seq(nrow(warn_minus)) + idx_last
    
    tab_warning$status[idx]     <- "negative"
    tab_warning$variables[idx]  <- warn_minus$variables
    tab_warning$types[idx]      <- NA
    tab_warning$indicator[idx]  <- warn_minus$minus
    tab_warning$ratio[idx]      <- warn_minus$minus / N
    tab_warning$warnings[idx]   <- sprintf(
      "%s has %s (%s%%) negatives",
      warn_minus$variables, format(warn_minus$minus, big.mark = ","),
      round(warn_minus$minus / N * 100, 2))
    tab_warning$recommand[idx]  <- "check"
  } else {
    idx <- NULL
  }
  
  # outlier --------------------------------------------------------------------
  idx_last <- idx_last + length(idx)
  
  warn_outlier <- diagn_numeric %>%
    filter(outlier > 0) %>%
    select(variables, outlier) %>%
    arrange(desc(outlier))
  
  if (nrow(warn_outlier) > 0) {
    idx <- seq(nrow(warn_outlier)) + idx_last
    
    tab_warning$status[idx]     <- "outlier"
    tab_warning$variables[idx]  <- warn_outlier$variables
    tab_warning$types[idx]      <- NA
    tab_warning$indicator[idx]  <- warn_outlier$outlier
    tab_warning$ratio[idx]      <- warn_outlier$outlier / N
    tab_warning$warnings[idx]   <- sprintf(
      "%s has %s (%s%%) outliers",
      warn_outlier$variables, format(warn_outlier$outlier, big.mark = ","),
      round(warn_outlier$outlier / N * 100, 2))
    tab_warning$recommand[idx]  <- "judgement"
  } else {
    idx <- NULL
  }
  
  tab_warning %>%
    filter(status != "")
}

list_diagnose_warning <- function(tab_warning) {
  if (NROW(tab_warning) < 1) {
    html_cat("No warnings")
  } else {
    tab_warning %>%
      count(recommand) %>%
      right_join(data.frame(recommand = c("check", "judgement", "remove")),
                 by = "recommand") %>%
      tidyr::spread(recommand, n) %>%
      mutate_all(function(x) ifelse(is.na(x), 0, x)) %>%
      reactable(
        defaultColDef = colDef(style = "font-size: 14px;
                               color: hsl(0, 0%, 40%);",
                               minWidth = 120),
        columns = list(
          check = colDef(
            name = "Checks",
            style = function(value) {
              list(color = "#007000", fontWeight = "bold")
            }
          ),
          judgement = colDef(
            name = "Judgements",
            style = function(value) {
              list(color = "#fdb368", fontWeight = "bold")
            }
          ),
          remove = colDef(
            name = "Removes",
            style = function(value) {
              list(color = "#e00000", fontWeight = "bold")
            }
          )
        ),
        fullWidth = FALSE
      )
  }
}


detail_diagnose_warning <- function(tab_warning) {
  style <- "display: inline-block;
  padding: 2px 12px;
  border-radius: 5px;
  font-weight: 600;
  font-size: 12px;"
  
  check <- paste0(style, "background: hsl(116, 60%, 90%);
                  color: hsl(116, 30%, 25%);")
  judgement <- paste0(style, "background: hsl(43, 82%, 68%);
                      color: hsl(230, 45%, 30%);")
  remove <- paste0(style, "background: hsl(25, 93%, 63%);
                   color: hsl(176, 93%, 97%);")
  
  if (NROW(tab_warning) > 0) {
    tab_warning %>%
      select(warnings, status, recommand) %>%
      reactable(
        defaultColDef = colDef(style = "font-size: 14px;
                               color: hsl(0, 0%, 40%);"),
        columns = list(
          warnings = colDef(
            name = "Warnings",
            cell = function(value, index) {
              variable_name <- strsplit(value, " ") %>%
                unlist() %>% "["(1)
              
              msg <- strsplit(value, " ") %>%
                unlist() %>%
                "["(-1) %>%
                paste(collapse = " ")
              msg <- paste("", msg)
              
              if (tab_warning$status[index] %in% "duplicate") {
                variable <- a(class = "anchor", href = "#ID-h2-duplicate",
                              variable_name)
              } else if (tab_warning$status[index] %in% "missing") {
                variable <- a(class = "anchor", href = "#ID-h1-missing",
                              variable_name)
              } else if (tab_warning$status[index] %in% "cardinality") {
                if (tab_warning$types[index] %in%
                    c("character", "factor", "ordered", "Date", "POSIXct"))
                  variable <- a(class = "anchor",
                                href = "#ID-h2-uniq-categorical", variable_name)
                else
                  variable <- a(class = "anchor",
                                href = "#ID-h2-uniq-numerical", variable_name)
              } else if (tab_warning$status[index] %in% "outlier") {
                variable <- a(class = "anchor",
                              href = "#ID-h1-outlier", variable_name)
              } else if (tab_warning$status[index] %in% c("zero", "negative")) {
                variable <- a(class = "anchor",
                              href = "#ID-h2-variables", variable_name)
              } else {
                variable <- div(style = list(color = "red"), variable_name)
              }
              
              tagList(
                div(style = list(display = "inline-block"), variable),
                msg
              )
            }
          ),
          status = colDef(name = "Types", width = 100),
          recommand = colDef(
            name = "Recommands",
            width = 130,
            cell = function(value) {
              class <- paste0("tag recommand-", tolower(value))
              div(class = class, value, style = get(value))
            }
          )
        )
      )
  }
}

