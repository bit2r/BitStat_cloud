################################################################################
## 01. Prepare Resources
################################################################################

##==============================================================================
## 01.01. Load Packages
##==============================================================================

##------------------------------------------------------------------------------
## 01.01.01. Set the library paths
##------------------------------------------------------------------------------

##------------------------------------------------------------------------------
## 01.01.02. Load packages that are related shiny & html
##------------------------------------------------------------------------------
library(shiny)
library(shinyjs)
library(shinyWidgets)
library(shinydashboard)
library(shinydashboardPlus)
library(shinybusy)
library(colourpicker)
library(htmltools)
library(flextable)

##------------------------------------------------------------------------------
## 01.01.03. Load packages that are tidyverse families
##------------------------------------------------------------------------------
library(dplyr)
library(readr)
library(vroom)
library(reactable)
library(glue)
library(dlookr)
library(openxlsx)
library(ggridges)  # for shinyio environments

##==============================================================================
## 01.02. Loading Sources
##==============================================================================
source("R/data.R")
source("R/display.R")
source("R/html_css.R")
source("R/html_tag.R")
source("R/translation.R")

.BitStatEnv <- new.env()
assign("language", "kr", envir = .BitStatEnv)

trans_file <- "translation.csv"
trans_csv <- file.path(glue::glue("translation/{trans_file}"))

translation <- readr::read_csv(
  trans_csv,
  comment = "#",
  col_types = "cc",
  locale = readr::locale(encoding = "UTF-8")
) %>%
  suppressWarnings()

if (max(table(translation$kr)) > 1) {
  message("translate meta file is invalied")
}

assign("translation", translation, envir = .BitStatEnv)

assign(".BitStatEnv", .BitStatEnv, envir = .GlobalEnv)



################################################################################
## 02. Prepare Data and Meta
################################################################################
##==============================================================================
## 02.01. Global Options
##==============================================================================
## for upload file
options(shiny.maxRequestSize = 30 * 1024 ^ 2)
## for trace, if want.
options(shiny.trace = FALSE)
## for progress
options(spinner.color="#0275D8", spinner.color.background="#ffffff",
        spinner.size=2)


##==============================================================================
## 02.02. Meta data
##==============================================================================
assign("import_rds", NULL, envir = .BitStatEnv)
assign("list_datasets", readRDS(paste("www", "meta", "list_datasets.rds",
                                      sep = "/")), envir = .BitStatEnv)
assign("choosed_dataset", NULL, envir = .BitStatEnv)
assign("trans", NULL, envir = .BitStatEnv)


##==============================================================================
## 02.03. Translation meta
##==============================================================================
## set language
# i18n <- Translator$new(translation_csvs_path = "www/meta/translation")
# i18n$set_translation_language(get("language", envir = .BitStatEnv))


##==============================================================================
## 02.04. Widget meta
##==============================================================================
element_sep <- c(",", ";", "\t")
names(element_sep) <- c(translate("??????"), translate("????????????"), translate("???"))

element_quote <- c("", '"', "'")
names(element_quote) <- c(translate("??????"), translate("??? ?????????"), 
                          translate("?????? ?????????"))

element_diag <- list("1", "2", "3")
names(element_diag) <- c(translate("?????????"), translate("?????????"), translate("0???"))

element_manipulate_variables <- list("Rename", "Change type", "Remove",
                                     "Reorder levels", "Reorganize levels", 
                                     "Transform", "Bin")
names(element_manipulate_variables) <- c(translate("?????? ??????"), 
                                         translate("??? ??????"), 
                                         translate("?????? ??????"),
                                         translate("?????? ?????? ????????????"),
                                         translate("?????? ?????? ??????/??????"),
                                         translate("????????????"),
                                         translate("??????"))

element_change_type <- list("as_factor", "as_numeric", "as_integer", 
                            "as_character", "as_date")
names(element_change_type) <- c(translate("???????????????"), translate("???????????????"), 
                                translate("???????????????"), translate("???????????????"), 
                                translate("??????(Y-M-D)???"))

## ????????? ??????
element_statistics <- list(
  "n", "na", "mean", "sd", "se_mean", "IQR", "skewness", "kurtosis"
)
names(element_statistics) <- c(
  translate("????????????"),
  translate("????????????"), 
  translate("????????????"),
  translate("????????????"),
  translate("????????????"),
  translate("??????????????????"),
  translate("??????"),
  translate("??????")
)

## ????????? ??????
element_quantiles <- list(
  "p00", "p01", "p05", "p10", "p20", "p25", "p30", "p40", "p50", 
  "p60", "p70", "p75", "p80", "p90", "p95", "p99", "p100"
)
names(element_quantiles) <- c(
  translate("?????????"), translate("1%??????"), translate("5%??????"), 
  translate("10%??????"), translate("20%??????"), translate("1/4??????"), 
  translate("30%??????"), translate("40%??????"), translate("?????????"), 
  translate("60%??????"), translate("70%??????"), translate("3/4??????"), 
  translate("80%??????"), translate("90%??????"), translate("95%??????"), 
  translate("99%??????"), translate("?????????")
)

## ???????????? ?????? ??????
element_method_choose_variables <- list("all", "user")
names(element_method_choose_variables) <- c(
  translate("??????"), 
  translate("????????? ??????")
)

## ?????? ??? ??????
element_marginal_type <- list("sum", "pct_row", "pct_col", "pct_tot")
names(element_marginal_type) <- c(
  translate("?????? ???"), 
  translate("??? ?????????"),
  translate("??? ?????????"), 
  translate("?????? ?????????")
)

## ???????????? ??????
element_corr_method <- list(
  "pearson", "kendall","spearman"
)
names(element_corr_method) <- c(
  translate("???????????? ?????? ????????????"), 
  translate("????????? ?????? ????????????"),
  translate("??????????????? ?????? ????????????")
)

## ??????????????? ????????????
element_alternative_test <- list(
  "two.sided", "less", "greater"
)
names(element_alternative_test) <- c(
  translate("???????????? ??? 0"), 
  translate("???????????? < 0"),
  translate("???????????? > 0")
)

## load source for tools
for (file in list.files(c("tools"), pattern = "\\.(r|R)$", full.names = TRUE)) {
  source(file, local = TRUE)
}



################################################################################
## 06. Shiny Rendering for CentOS
################################################################################
##==============================================================================
## 06.01. Shiny visualization functions
##==============================================================================

##------------------------------------------------------------------------------
## 06.01.01. Plot vis to PNG file for shiny server
##------------------------------------------------------------------------------
plotPNG <- function (func, filename = tempfile(fileext = ".png"), width = 400,
                     height = 400, res = 72, ...)  {
  if (capabilities("aqua")) {
    pngfun <- grDevices::png
  }
  else if (FALSE && nchar(system.file(package = "Cairo"))) {
    pngfun <- Cairo::CairoPNG
  }
  else {
    pngfun <- grDevices::png
  }
  
  pngfun(filename = filename, width = width, height = height, res = res, ...)
  
  op <- graphics::par(mar = rep(0, 4))
  
  tryCatch(graphics::plot.new(), finally = graphics::par(op))
  
  dv <- grDevices::dev.cur()
  
  on.exit(grDevices::dev.off(dv), add = TRUE)
  
  func()
  
  filename
}

##------------------------------------------------------------------------------
## 06.01.02. Rendering for shiny server
##------------------------------------------------------------------------------
renderPlot <- function (expr, width = "auto", height = "auto", res = 72, ...,
                        env = parent.frame(), quoted = FALSE, func = NULL)  {
  installExprFunction(expr, "func", env, quoted, ..stacktraceon = TRUE)
  
  args <- list(...)
  
  if (is.function(width))
    widthWrapper <- reactive({
      width()
    })
  else widthWrapper <- NULL
  
  if (is.function(height))
    heightWrapper <- reactive({
      height()
    })
  else heightWrapper <- NULL
  
  outputFunc <- plotOutput
  
  if (!identical(height, "auto"))
    formals(outputFunc)["height"] <- list(NULL)
  
  return(markRenderFunction(outputFunc, function(shinysession,
                                                 name, ...) {
    if (!is.null(widthWrapper)) width <- widthWrapper()
    if (!is.null(heightWrapper)) height <- heightWrapper()
    
    prefix <- "output_"
    
    if (width == "auto")
      width <- shinysession$clientData[[paste(prefix, name,
                                              "_width", sep = "")]]
    if (height == "auto")
      height <- shinysession$clientData[[paste(prefix, name,
                                               "_height", sep = "")]]
    if (is.null(width) || is.null(height) || width <= 0 || height <= 0)
      return(NULL)
    pixelratio <- shinysession$clientData$pixelratio
    if (is.null(pixelratio))
      pixelratio <- 1
    
    coordmap <- NULL
    
    plotFunc <- function() {
      result <- withVisible(func())
      coordmap <<- NULL
      if (result$visible) {
        if (inherits(result$value, "ggplot")) {
          utils::capture.output(coordmap <<- getGgplotCoordmap(result$value,
                                                               pixelratio))
        } else {
          utils::capture.output(..stacktraceon..(print(result$value)))
        }
      }
      if (is.null(coordmap)) {
        coordmap <<- shiny:::getPrevPlotCoordmap(width, height)
      }
    }
    
    outfile <- ..stacktraceoff..(
      do.call(
        plotPNG,
        c(plotFunc, width = width * pixelratio, height = height * pixelratio,
          res = res * pixelratio, args)
      )
    )
    
    on.exit(unlink(outfile))
    res <- list(src = shinysession$fileUrl(name, outfile,
                                           contentType = "image/png"),
                width = width, height = height,
                coordmap = coordmap)
    error <- attr(coordmap, "error", exact = TRUE)
    if (!is.null(error)) {
      res$error <- error
    }
    
    res
  }))
}
