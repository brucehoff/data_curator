suppressPackageStartupMessages({
  library(shiny)
  library(httr)
  library(rjson)
  library(yaml)
  library(shinyjs)
  library(dplyr)
  library(shinythemes)
  library(shinydashboard)
  library(stringr)
  library(DT)
  library(jsonlite)
  library(reticulate)
  library(ggplot2)
  library(purrr)
  library(plotly)
  library(shinypop)
  library(waiter)
  library(readr)
  library(sass)
  library(shinydashboardPlus)
})

message("In global.R")

has_auth_code <- function(params) {
  # params is a list object containing the parsed URL parameters. Return TRUE if
  # based on these parameters, it looks like auth code is present that we can
  # use to get an access token. If not, it means we need to go through the OAuth
  # flow.
  return(!is.null(params$code))
}

oauth_client <- yaml.load_file("config.yaml")

client_id <- toString(oauth_client$CLIENT_ID)
client_secret <- toString(oauth_client$CLIENT_SECRET)

if (interactive()) {
  # for local development
  options(shiny.port = 8100)
  app_url <- "http://localhost:8100/"
} else {
  # deployed url
  app_url <- toString(oauth_client$APP_URL)
}

conda_name <- toString(oauth_client$CONDA_ENV_NAME)

message(sprintf("In global.R.  conda_name: %s", conda_name))

if (is.null(client_id)) stop("config.yaml is missing CLIENT_ID")
if (is.null(client_secret)) stop("config.yaml is missing CLIENT_SECRET")
if (is.null(app_url)) stop("config.yaml is missing APP_URL")
if (is.null(conda_name)) stop("config.yaml is missing CONDA_ENV_NAME")

app <- oauth_app("shinysynapse",
  key = client_id,
  secret = client_secret,
  redirect_uri = app_url
)

# These are the user info details ('claims') requested from Synapse:
claims <- list(
  family_name = NULL,
  given_name = NULL,
  email = NULL,
  email_verified = NULL,
  userid = NULL,
  orcid = NULL,
  is_certified = NULL,
  is_validated = NULL,
  validated_given_name = NULL,
  validated_family_name = NULL,
  validated_location = NULL,
  validated_email = NULL,
  validated_company = NULL,
  validated_at = NULL,
  validated_orcid = NULL,
  company = NULL
)

claimsParam <- toJSON(list(id_token = claims, userinfo = claims))
api <- oauth_endpoint(
  authorize = paste0("https://signin.synapse.org?claims=", claimsParam),
  access = "https://repo-prod.prod.sagebase.org/auth/v1/oauth2/token"
)

# The 'openid' scope is required by the protocol for retrieving user information.
scope <- "openid view download modify"

# Activate conda env
# Don't necessarily have to set `RETICULATE_PYTHON` env variable
message(sprintf("In global.R. about to call use_virtualenv( %s )", conda_name))
#reticulate::use_condaenv(conda_name) #  <<<< this line breaks
# From 
# https://community.rstudio.com/t/how-to-use-conda-environment-in-shinyapps-io/18630/2
# "conda is not available on shinyapps.io You should be able to use use_virtualenv though."
use_virtualenv(conda_name)
message(sprintf("In global.R. Done calling use_virtualenv( %s )", conda_name))

# Import functions/modules
source_files <- list.files(c("functions", "modules"), pattern = "*\\.R$", recursive = TRUE, full.names = TRUE)
sapply(source_files, FUN = source)

# Global variables
datatypes <- c("project", "folder", "template")
options(sass.cache = FALSE)
