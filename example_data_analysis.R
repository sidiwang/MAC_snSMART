
source("simulation_function.R")

mu <- c(-2.99, -3.44, -2.41) # set true mean and true sd for simulation purpose
sd_ij <- c(0.7713192, 0.65, 0.67, 0.64, 0.67, 0.64) # first value is obtained from natural history data
k <- 1 # number of external control data points
mu_l <- mu[2]
mu_p <- mu[1]
mu_h <- mu[3]

mu_co <- -1.04 # mean treatment effect obtained from natural history data

sigma_1p <- sd_ij[k + 1]
sigma_1l <- sd_ij[k + 2]
sigma_1h <- sd_ij[k + 3]
sigma_2l <- sd_ij[k + 4]
sigma_2h <- sd_ij[k + 5]

sigma_pl <- sigma_ph <- sigma_ll <- sigma_lh <- sigma_hl <- sigma_hh <- 100

SIMULATION_N <- 30000 # set the number of simulations

# prepare NULL vectors for for loops
trad_mathod_final_mean  <- trad_mathod_PL_CI <- trad_mathod_PH_CI  <- RMS_final_mean <- RMS_PL_CI <- RMS_PH_CI <- REX_INV_final_mean <- REX_INV_PL_CI <- REX_INV_PH_CI  <- BJSM_final_mean <- BJSM_PL_CI <- BJSM_PH_CI <- NULL
trad_mathod_response_rate_posterior_mean  <- RMS_response_rate_posterior_mean <- BJSM_response_rate_posterior_mean <- NULL
trueeffect <- NULL
trad_mathod_response_rate_hdi_coverage_rate <- RMS_response_rate_hdi_coverage_rate <- BJSM_response_rate_hdi_coverage_rate <- NULL
trad_mathod_response_rate_hdi_length <- RMS_response_rate_hdi_length <- BJSM_response_rate_hdi_length <- NULL
trad_mathod_P_CI <- trad_mathod_L_CI <- trad_mathod_H_CI <- RMS_P_CI <- RMS_L_CI <- RMS_H_CI <- BJSM_P_CI <- BJSM_L_CI <- BJSM_H_CI <- NULL
ESS_tmp <- NULL

COVERAGE_RATE <- 0.95 # coverage rate for Bayesian credible intervals

# do simulation in parallel
require("foreach")
require("doParallel")
parallel::detectCores()
n.cores <- parallel::detectCores()
my.cluster <- parallel::makeCluster(
  n.cores,
  type = "PSOCK"
)

# check cluster definition (optional)
print(my.cluster)
# register it to be used by %dopar%
doParallel::registerDoParallel(cl = my.cluster)

# check if it is registered (optional)
foreach::getDoParRegistered()
foreach::getDoParWorkers()

comb <- function(x, ...) {
  mapply(rbind, x, ..., SIMPLIFY = FALSE)
}

result <- foreach(
  i = 1:SIMULATION_N,
  .combine = comb,
  .multicombine = TRUE
) %dopar% {
  print(i)

  # simulate correlation
  while (matrixcalc::is.positive.definite(matrix(c(sigma_1p^2, sigma_pl * sigma_1p * sigma_2l, sigma_pl * sigma_1p * sigma_2l, sigma_2l^2), 2, 2)) == FALSE) {
    sigma_pl <- runif(1, -1, 1)
  }

  while (matrixcalc::is.positive.definite(matrix(c(sigma_1p^2, sigma_ph * sigma_1p * sigma_2h, sigma_ph * sigma_1p * sigma_2h, sigma_2h^2), 2, 2)) == FALSE) {
    sigma_ph <- runif(1, -1, 1)
  }

  while (matrixcalc::is.positive.definite(matrix(c(sigma_1l^2, sigma_ll * sigma_1l * sigma_2l, sigma_ll * sigma_1l * sigma_2l, sigma_2l^2), 2, 2)) == FALSE) {
    sigma_ll <- runif(1, -1, 1)
  }

  while (matrixcalc::is.positive.definite(matrix(c(sigma_1l^2, sigma_lh * sigma_1l * sigma_2h, sigma_lh * sigma_1l * sigma_2h, sigma_2h^2), 2, 2)) == FALSE) {
    sigma_lh <- runif(1, -1, 1)
  }

  while (matrixcalc::is.positive.definite(matrix(c(sigma_1h^2, sigma_hl * sigma_1h * sigma_2l, sigma_hl * sigma_1h * sigma_2l, sigma_2l^2), 2, 2)) == FALSE) {
    sigma_hl <- runif(1, -1, 1)
  }

  while (matrixcalc::is.positive.definite(matrix(c(sigma_1h^2, sigma_hh * sigma_1h * sigma_2h, sigma_hh * sigma_1h * sigma_2h, sigma_2h^2), 2, 2)) == FALSE) {
    sigma_hh <- runif(1, -1, 1)
  }

  # calculate covariance
  cov_jj <- matrix(c(sigma_pl * sigma_1p * sigma_2l, sigma_ph * sigma_1p * sigma_2h, sigma_ll * sigma_1l * sigma_2l, sigma_lh * sigma_1l * sigma_2h, sigma_hl * sigma_1h * sigma_2l, sigma_hh * sigma_1h * sigma_2h), 3, 2, byrow = TRUE)
  n <- c(30, 29, 33, k) # set up the number of participants on each arm
  p <- 0.5 # MAC-snSMART mixture component p

  flag <- TRUE

  # simulate trial datasets
  while (flag == TRUE) {
    trial.data <- dataGen_bivaraite(mu, mu_co, sd_ij, cov_jj, n, p = p_simu)
    if ((length(which(trial.data$trial.data$trt1 == 3 & trial.data$trial.data$trt2 == 2)) >= 2 &
      length(which(trial.data$trial.data$trt1 == 3 & trial.data$trial.data$trt2 == 3)) >= 2 &
      length(which(trial.data$trial.data$trt1 == 2 & trial.data$trial.data$trt2 == 2)) >= 2) == FALSE) {
      flag <- TRUE
    } else {
      flag <- FALSE
    }
  }

  # true value
  theta_p_true <- mu[1]
  theta_1l_true <- mu[2]
  theta_1h_true <- mu[3]

  trueeffect_tmp <- c(theta_p_true, theta_1l_true, theta_1h_true)
  trueeffect <- rbind(trueeffect, trueeffect_tmp)

  # prepare simulated information for model fitting purpose
  n_c <- 1
  new_trial_data <- trial.data$trial.data
  historical_data <- cbind(trial.data$Y_k, sd_ij[1:n_c])
  n_MCMC_chain <- 2
  n.adapt <- 4000
  MCMC_SAMPLE <- 10000
  mu_guess <- c(-3.5, -3.5, -3.5)
  COVERAGE_RATE <- 0.95
  p_model <- 0.5

  trialData <- new_trial_data

  NUM_ARMS <- length(unique(trialData$trt1[!is.na(trialData$trt1)]))

  Y_k <- historical_data[, 1]
  s_k <- historical_data[, 2]

  Y_1p <- mean(trialData$Y_1[which(trialData$trt1 == 1)])
  s_1p <- sd(trialData$Y_1[which(trialData$trt1 == 1)]) / sqrt(length(which(trialData$trt1 == 1)))
  s_1p_patient <- sd(trialData$Y_1[which(trialData$trt1 == 1)])

  Y_l <- mean(c(trialData$Y_1[which(trialData$trt1 == 2)], trialData$Y_2[which(trialData$trt2 == 2)]))
  s_l <- sd(c(trialData$Y_1[which(trialData$trt1 == 2)], trialData$Y_2[which(trialData$trt2 == 2)]))

  Y_1l <- mean(trialData$Y_1[which(trialData$trt1 == 2)])
  s_1l <- sd(trialData$Y_1[which(trialData$trt1 == 2)]) / sqrt(length(which(trialData$trt1 == 2)))
  s_1l_patient <- sd(trialData$Y_1[which(trialData$trt1 == 2)])
  Y_2l <- mean(trialData$Y_2[which(trialData$trt2 == 2)])
  s_2l <- sd(trialData$Y_2[which(trialData$trt2 == 2)]) / sqrt(length(which(trialData$trt2 == 2)))


  Y_h <- mean(c(trialData$Y_1[which(trialData$trt1 == 3)], trialData$Y_2[which(trialData$trt2 == 3)]))
  s_h <- sd(c(trialData$Y_1[which(trialData$trt1 == 3)], trialData$Y_2[which(trialData$trt2 == 3)]))

  Y_1h <- mean(trialData$Y_1[which(trialData$trt1 == 3)])
  s_1h_r_patient <- sd(trialData$Y_1[which(trialData$trt1 == 3 & !is.na(trialData$trt2))])
  s_1h_r <- sd(trialData$Y_1[which(trialData$trt1 == 3 & !is.na(trialData$trt2))]) / sqrt(length(which(trialData$trt1 == 3 & !is.na(trialData$trt2))))
  s_1h <- sd(trialData$Y_1[which(trialData$trt1 == 3)]) / sqrt(length(which(trialData$trt1 == 3)))
  s_1h_patient <- sd(trialData$Y_1[which(trialData$trt1 == 3)])
  Y_2h <- mean(trialData$Y_2[which(trialData$trt2 == 3)])
  s_2h <- sd(trialData$Y_2[which(trialData$trt2 == 3)]) / sqrt(length(which(trialData$trt2 == 3)))

  cov_data <- na.omit(trialData)
  for (i in c(1:3)) {
    for (j in c(1:2)) {
      index <- intersect(which(cov_data$trt1 == i), which(cov_data$trt2 == j + 1))
      assign(paste0("Y_", i, j + 1), c(mean(cov_data$Y_1[index]), mean(cov_data$Y_2[index])))
      assign(paste0("s_", i, j + 1), c(sd(cov_data$Y_1[index]), sd(cov_data$Y_2[index])) / sqrt(length(index)))
      assign(paste0("n_", i, j + 1), length(index))
    }
  }

  threshold_l <- -3.1
  bias_h <- mean(trialData$Y_1[intersect(which(!is.na(trialData$trt2)), which(trialData$trt1 == 3))]) - Y_1h
  bias_l_low <- Y_1l - mean(trialData$Y_1[intersect(which(trialData$trt2 == 3), which(trialData$trt1 == 2))])
  bias_l_high <- mean(trialData$Y_1[intersect(which(trialData$trt2 == 2), which(trialData$trt1 == 2))]) - Y_1l

  Y_ij <- rbind(Y_12, Y_13, Y_22, Y_23, Y_32, Y_33)
  s_ij <- rbind(s_12, s_13, s_22, s_23, s_32, s_33)
  n_ij <- rbind(n_12, n_13, n_22, n_23, n_32, n_33)

  if (length(p) == 1) {
    p.exch <- rep(p, nrow(historical_data) + 1)
  } else {
    p.exch <- p
  }


  y <- c(mu_co, Y_1p)


  ############################ Traditional Method ################################

  cat("traditional.bugs\n")
  jag <- rjags::jags.model(
    file = "traditional.bugs",
    data = list(
      s_new = c(s_1p, s_1l, s_1h, s_2l, s_2h),
      y_new = c(Y_1p, Y_1l, Y_1h, Y_2l, Y_2h),
      Nmu = 3,
      tau_new = 10000,
      mu = mu
    ),
    n.chains = n_MCMC_chain, n.adapt = n.adapt
  )

  posterior_sample <- rjags::coda.samples(
    jag,
    c("mu", "theta_new", "s_new"),
    MCMC_SAMPLE
  )

  trad_mathod <- as.data.frame(posterior_sample[[1]])
  trad_mathod$PL <- trad_mathod$`theta_new[2]` - trad_mathod$`theta_new[1]`
  trad_mathod$PH <- trad_mathod$`theta_new[3]` - trad_mathod$`theta_new[1]`
  trad_mathod_mean_estimate <- apply(trad_mathod, 2, mean)
  trad_mathod_tmp_mean <- c(trad_mathod_mean_estimate["theta_new[1]"], trad_mathod_mean_estimate["theta_new[2]"], trad_mathod_mean_estimate["theta_new[3]"], trad_mathod_mean_estimate["PL"], trad_mathod_mean_estimate["PH"])
  trad_mathod_final_mean <- rbind(trad_mathod_final_mean, trad_mathod_tmp_mean)
  trad_mathod_tmp_response_rate_posterior_mean <- colMeans(trad_mathod[, c("mu[1]", "mu[2]", "mu[3]", "theta_new[1]", "theta_new[2]", "theta_new[3]", "theta_new[4]", "theta_new[5]")])
  trad_mathod_tmp_hdi <- HDInterval::hdi(trad_mathod, COVERAGE_RATE)
  trad_mathod_P_CI_tmp <- trad_mathod_tmp_hdi[, "theta_new[1]"]
  trad_mathod_P_CI <- rbind(trad_mathod_P_CI, trad_mathod_P_CI_tmp)
  trad_mathod_L_CI_tmp <- trad_mathod_tmp_hdi[, "theta_new[2]"]
  trad_mathod_L_CI <- rbind(trad_mathod_L_CI, trad_mathod_L_CI_tmp)
  trad_mathod_H_CI_tmp <- trad_mathod_tmp_hdi[, "theta_new[3]"]
  trad_mathod_H_CI <- rbind(trad_mathod_H_CI, trad_mathod_H_CI_tmp)
  trad_mathod_PL_CI_tmp <- trad_mathod_tmp_hdi[, "PL"]
  trad_mathod_PL_CI <- rbind(trad_mathod_PL_CI, trad_mathod_PL_CI_tmp)
  trad_mathod_PH_CI_tmp <- trad_mathod_tmp_hdi[, "PH"]
  trad_mathod_PH_CI <- rbind(trad_mathod_PH_CI, trad_mathod_PH_CI_tmp)
  trad_mathod_tmp_response_rate_hdi_coverage_rate_theta_p <- as.numeric(trad_mathod_tmp_hdi["lower", "theta_new[1]"] <= theta_p_true & trad_mathod_tmp_hdi["upper", "theta_new[1]"] >= theta_p_true)
  trad_mathod_tmp_response_rate_hdi_coverage_rate_theta_l <- as.numeric(trad_mathod_tmp_hdi["lower", "theta_new[2]"] <= theta_1l_true & trad_mathod_tmp_hdi["upper", "theta_new[2]"] >= theta_1l_true)
  trad_mathod_tmp_response_rate_hdi_coverage_rate_theta_h <- as.numeric(trad_mathod_tmp_hdi["lower", "theta_new[3]"] <= theta_1h_true & trad_mathod_tmp_hdi["upper", "theta_new[3]"] >= theta_1h_true)
  trad_mathod_tmp_response_rate_hdi_coverage_rate_pl <- as.numeric(trad_mathod_tmp_hdi["lower", "PL"] <= 0 & trad_mathod_tmp_hdi["upper", "PL"] >= 0)
  trad_mathod_tmp_response_rate_hdi_coverage_rate_ph <- as.numeric(trad_mathod_tmp_hdi["lower", "PH"] <= 0 & trad_mathod_tmp_hdi["upper", "PH"] >= 0)
  trad_mathod_tmp_response_rate_hdi_coverage_rate <- cbind(
    trad_mathod_tmp_response_rate_hdi_coverage_rate_theta_p, trad_mathod_tmp_response_rate_hdi_coverage_rate_theta_l,
    trad_mathod_tmp_response_rate_hdi_coverage_rate_theta_h, trad_mathod_tmp_response_rate_hdi_coverage_rate_pl,
    trad_mathod_tmp_response_rate_hdi_coverage_rate_ph
  )
  trad_mathod_response_rate_hdi_coverage_rate <- rbind(trad_mathod_response_rate_hdi_coverage_rate, trad_mathod_tmp_response_rate_hdi_coverage_rate)

  trad_mathod_tmp_response_rate_hdi_length_theta_p <- abs(trad_mathod_tmp_hdi["lower", "theta_new[1]"] - trad_mathod_tmp_hdi["upper", "theta_new[1]"])
  trad_mathod_tmp_response_rate_hdi_length_theta_l <- abs(trad_mathod_tmp_hdi["lower", "theta_new[2]"] - trad_mathod_tmp_hdi["upper", "theta_new[2]"])
  trad_mathod_tmp_response_rate_hdi_length_theta_h <- abs(trad_mathod_tmp_hdi["lower", "theta_new[3]"] - trad_mathod_tmp_hdi["upper", "theta_new[3]"])
  trad_mathod_tmp_response_rate_hdi_length_pl <- abs(trad_mathod_tmp_hdi["lower", "PL"] - trad_mathod_tmp_hdi["upper", "PL"])
  trad_mathod_tmp_response_rate_hdi_length_ph <- abs(trad_mathod_tmp_hdi["lower", "PH"] - trad_mathod_tmp_hdi["upper", "PH"])
  trad_mathod_tmp_response_rate_hdi_length <- cbind(
    trad_mathod_tmp_response_rate_hdi_length_theta_p, trad_mathod_tmp_response_rate_hdi_length_theta_l,
    trad_mathod_tmp_response_rate_hdi_length_theta_h, trad_mathod_tmp_response_rate_hdi_length_pl,
    trad_mathod_tmp_response_rate_hdi_length_ph
  )
  trad_mathod_response_rate_hdi_length <- rbind(trad_mathod_response_rate_hdi_length, trad_mathod_tmp_response_rate_hdi_length)
  trad_mathod_response_rate_posterior_mean <- rbind(trad_mathod_response_rate_posterior_mean, trad_mathod_tmp_response_rate_posterior_mean)



  ############################ RMS ################################

  cat("robust_MAC_snSMART.bugs\n")
  jag <- rjags::jags.model(
    file = "robust_MAC_snSMART.bugs",
    data = list(
      Ntrials = length(Y_k) + 1,
      NUM_ARMS = NUM_ARMS,
      y = y,
      s_new_norm = c(s_1p, s_1l, s_1h, s_2l, s_2h),
      s = c(s_k, s_1p),
      y_new = Y_ij,
      Prior.cov_ij = c(-1, 1),
      Nmu = length(mu),
      Ntau = length(y),
      bias_l_high = bias_l_high,
      bias_l_low = bias_l_low,
      bias_high = bias_h,
      Prior.bias_sd = c(s_1l, s_1l, s_1h) / 4,
      Prior.tau = matrix(c(rep(0, length(y)), rep(s_1p, length(y))), ncol = 2) / 2,
      Prior.tau_new = matrix(c(0, 0, s_1l, s_1h), ncol = 2) / 2,
      Prior.mu = matrix(c(mu[1], mu[2], mu[3], sd(trialData$Y_1[which(trialData$trt1 == 1)]), sd(trialData$Y_1[which(trialData$trt1 == 2)]), sd(trialData$Y_1[which(trialData$trt1 == 3)])), ncol = 2),
      p.exch = p.exch,
      Prior.nex = matrix(c(rep(-4, length(y)), rep(10, length(y))), ncol = 2)
    ),
    n.chains = n_MCMC_chain, n.adapt = n.adapt
  )
  posterior_sample_RMS <- rjags::coda.samples(
    jag,
    c("mu", "Z", "tau", "tau_new", "theta", "theta_new", "s", "s_new_norm"),
    MCMC_SAMPLE * 2
  )

  RMS <- as.data.frame(posterior_sample_RMS[[1]])
  RMS$PL <- RMS$`theta_new[1]` - RMS$`theta[2]`
  RMS$PH <- RMS$`theta_new[2]` - RMS$`theta[2]`

  RMS_mean_estimate <- summary(posterior_sample_RMS)$statistics[, 1] #apply(RMS, 2, mean)
  RMS_tmp_mean <- c(RMS_mean_estimate["theta[2]"], RMS_mean_estimate["theta_new[1]"], RMS_mean_estimate["theta_new[2]"], apply(RMS, 2, mean)["PL"], apply(RMS, 2, mean)["PH"])
  RMS_final_mean <- rbind(RMS_final_mean, RMS_tmp_mean)

  RMS_tmp_Z <- RMS_mean_estimate[c("Z[1]", "Z[2]", "Z[3]", "Z[4]", "Z[5]", "Z[6]")]
  RMS_tmp_response_rate_posterior_mean <- RMS_mean_estimate[c("mu[1]", "mu[2]", "mu[3]", "theta[2]", "theta_new[1]", "theta_new[2]", "theta_new[3]", "theta_new[4]")]
  RMS_tmp_hdi <- HDInterval::hdi(RMS, COVERAGE_RATE)
  RMS_P_CI_tmp <- RMS_tmp_hdi[, "theta[2]"]
  RMS_P_CI <- rbind(RMS_P_CI, RMS_P_CI_tmp)
  RMS_L_CI_tmp <- RMS_tmp_hdi[, "theta_new[1]"]
  RMS_L_CI <- rbind(RMS_L_CI, RMS_L_CI_tmp)
  RMS_H_CI_tmp <- RMS_tmp_hdi[, "theta_new[2]"]
  RMS_H_CI <- rbind(RMS_H_CI, RMS_H_CI_tmp)
  RMS_PL_CI_tmp <- RMS_tmp_hdi[, "PL"]
  RMS_PL_CI <- rbind(RMS_PL_CI, RMS_PL_CI_tmp)
  RMS_PH_CI_tmp <- RMS_tmp_hdi[, "PH"]
  RMS_PH_CI <- rbind(RMS_PH_CI, RMS_PH_CI_tmp)

  RMS_tmp_response_rate_hdi_coverage_rate_theta_p <- as.numeric(RMS_tmp_hdi["lower", "theta[2]"] <= theta_p_true & RMS_tmp_hdi["upper", "theta[2]"] >= theta_p_true)
  RMS_tmp_response_rate_hdi_coverage_rate_theta_l <- as.numeric(RMS_tmp_hdi["lower", "theta_new[1]"] <= theta_1l_true & RMS_tmp_hdi["upper", "theta_new[1]"] >= theta_1l_true)
  RMS_tmp_response_rate_hdi_coverage_rate_theta_h <- as.numeric(RMS_tmp_hdi["lower", "theta_new[2]"] <= theta_1h_true & RMS_tmp_hdi["upper", "theta_new[2]"] >= theta_1h_true)
  RMS_tmp_response_rate_hdi_coverage_rate_pl <- as.numeric(RMS_tmp_hdi["lower", "PL"] <= 0 & RMS_tmp_hdi["upper", "PL"] >= 0)
  RMS_tmp_response_rate_hdi_coverage_rate_ph <- as.numeric(RMS_tmp_hdi["lower", "PH"] <= 0 & RMS_tmp_hdi["upper", "PH"] >= 0)
  RMS_tmp_response_rate_hdi_coverage_rate <- cbind(
    RMS_tmp_response_rate_hdi_coverage_rate_theta_p, RMS_tmp_response_rate_hdi_coverage_rate_theta_l,
    RMS_tmp_response_rate_hdi_coverage_rate_theta_h, RMS_tmp_response_rate_hdi_coverage_rate_pl,
    RMS_tmp_response_rate_hdi_coverage_rate_ph
  )
  RMS_response_rate_hdi_coverage_rate <- rbind(RMS_response_rate_hdi_coverage_rate, RMS_tmp_response_rate_hdi_coverage_rate)

  RMS_tmp_response_rate_hdi_length_theta_p <- abs(RMS_tmp_hdi["lower", "theta[2]"] - RMS_tmp_hdi["upper", "theta[2]"])
  RMS_tmp_response_rate_hdi_length_theta_l <- abs(RMS_tmp_hdi["lower", "theta_new[1]"] - RMS_tmp_hdi["upper", "theta_new[1]"])
  RMS_tmp_response_rate_hdi_length_theta_h <- abs(RMS_tmp_hdi["lower", "theta_new[2]"] - RMS_tmp_hdi["upper", "theta_new[2]"])
  RMS_tmp_response_rate_hdi_length_pl <- abs(RMS_tmp_hdi["lower", "PL"] - RMS_tmp_hdi["upper", "PL"])
  RMS_tmp_response_rate_hdi_length_ph <- abs(RMS_tmp_hdi["lower", "PH"] - RMS_tmp_hdi["upper", "PH"])
  RMS_tmp_response_rate_hdi_length <- cbind(
    RMS_tmp_response_rate_hdi_length_theta_p, RMS_tmp_response_rate_hdi_length_theta_l,
    RMS_tmp_response_rate_hdi_length_theta_h, RMS_tmp_response_rate_hdi_length_pl,
    RMS_tmp_response_rate_hdi_length_ph
  )
  RMS_response_rate_hdi_length <- rbind(RMS_response_rate_hdi_length, RMS_tmp_response_rate_hdi_length)

  RMS_response_rate_posterior_mean <- rbind(RMS_response_rate_posterior_mean, RMS_tmp_response_rate_posterior_mean)




  ############################ BJSM ################################

  study <- c("NH")
  n_dat <- c(25)
  y_dat <- c(-1.04)
  y.se_dat <- c(0.7713192)
  dat <- data.frame("study" = study, "n" = n_dat, "y" = y_dat, "y.se" = y.se_dat)
  tau_sigma <- sd(trialData$Y_1[which(trialData$trt1 == 1)]) / sqrt(length(which(trialData$trt1 == 1)))
  p_sigma <- y.se_dat * sqrt(25) #sd(trialData$Y_1[which(trialData$trt1 == 1)])
  options(RBesT.MC.control=list(adapt_delta=0.999))
  map_mcmc <- RBesT::gMAP(cbind(y, y.se) ~ 1 | study,
    weights = n, data = dat,
    family = gaussian,
    beta.prior = cbind(-4, p_sigma),
    iter = 10000,
    tau.dist = "HalfNormal", tau.prior = cbind(0, p_sigma/2) #tau_sigma)
  )
  #print(map_mcmc)
  map <- RBesT::automixfit(map_mcmc)
  rnMix <- RBesT::robustify(map, weight = 1 - RMS_mean_estimate[1], mean = -4)
  ESS_final <- round(RBesT::ess(rnMix))
  ESS_tmp <- c(ESS_tmp, ESS_final)
  if (ESS_final != 0) {
    p_sd_prior <- sd(new_trial_data$Y_1[which(new_trial_data$trt1 == 1)]) / sqrt(ESS_final)
  } else {
    p_sd_prior <- sd(new_trial_data$Y_1[which(new_trial_data$trt1 == 1)])
  }


  tryCatch({
    jags <- rjags::jags.model(
      file = "JointStageBayes_mixture.bug",
      data = list(
        overall_sample_size = nrow(new_trial_data),
        stage2size = which(!is.na(new_trial_data$trt2)),
        data_effect_stageI = new_trial_data$Y_1,
        data_effect_stageII = new_trial_data$Y_2,
        treatment_stageI = new_trial_data$trt1,
        treatment_stageII = new_trial_data$trt2,
        mu_guess = c(-1.04, mu_guess[2:3]),
        var_prior = 1 / c((p_sd_prior)^2, 100, 100)
      ),
      n.chains = n_MCMC_chain, n.adapt = n.adapt
    )
    posterior_sample <- rjags::coda.samples(
      jags,
      c("mu", "alpha", "beta"),
      MCMC_SAMPLE
    )
  })

  BJSM <- as.data.frame(posterior_sample[[1]])
  BJSM$PL <- BJSM$`mu[2]` - BJSM$`mu[1]`
  BJSM$PH <- BJSM$`mu[3]` - BJSM$`mu[1]`

  BJSM_mean_estimate <- colMeans(BJSM)
  BJSM_tmp_mean <- c(BJSM_mean_estimate["mu[1]"], BJSM_mean_estimate["mu[2]"], BJSM_mean_estimate["mu[3]"], BJSM_mean_estimate["PL"], BJSM_mean_estimate["PH"])
  BJSM_final_mean <- rbind(BJSM_final_mean, BJSM_tmp_mean)
  BJSM_tmp_response_rate_posterior_mean <- colMeans(BJSM[, c("mu[1]", "mu[2]", "mu[3]")])
  BJSM_tmp_hdi <- HDInterval::hdi(BJSM, COVERAGE_RATE)
  BJSM_P_CI_tmp <- BJSM_tmp_hdi[, "mu[1]"]
  BJSM_P_CI <- rbind(BJSM_P_CI, BJSM_P_CI_tmp)
  BJSM_L_CI_tmp <- BJSM_tmp_hdi[, "mu[2]"]
  BJSM_L_CI <- rbind(BJSM_L_CI, BJSM_L_CI_tmp)
  BJSM_H_CI_tmp <- BJSM_tmp_hdi[, "mu[3]"]
  BJSM_H_CI <- rbind(BJSM_H_CI, BJSM_H_CI_tmp)
  BJSM_PL_CI_tmp <- BJSM_tmp_hdi[, "PL"]
  BJSM_PL_CI <- rbind(BJSM_PL_CI, BJSM_PL_CI_tmp)
  BJSM_PH_CI_tmp <- BJSM_tmp_hdi[, "PH"]
  BJSM_PH_CI <- rbind(BJSM_PH_CI, BJSM_PH_CI_tmp)

  BJSM_tmp_response_rate_hdi_coverage_rate_theta_p <- as.numeric(BJSM_tmp_hdi["lower", "mu[1]"] <= theta_p_true & BJSM_tmp_hdi["upper", "mu[1]"] >= theta_p_true)
  BJSM_tmp_response_rate_hdi_coverage_rate_theta_l <- as.numeric(BJSM_tmp_hdi["lower", "mu[2]"] <= theta_1l_true & BJSM_tmp_hdi["upper", "mu[2]"] >= theta_1l_true)
  BJSM_tmp_response_rate_hdi_coverage_rate_theta_h <- as.numeric(BJSM_tmp_hdi["lower", "mu[3]"] <= theta_1h_true & BJSM_tmp_hdi["upper", "mu[3]"] >= theta_1h_true)
  BJSM_tmp_response_rate_hdi_coverage_rate_pl <- as.numeric(BJSM_tmp_hdi["lower", "PL"] <= 0 & BJSM_tmp_hdi["upper", "PL"] >= 0)
  BJSM_tmp_response_rate_hdi_coverage_rate_ph <- as.numeric(BJSM_tmp_hdi["lower", "PH"] <= 0 & BJSM_tmp_hdi["upper", "PH"] >= 0)
  BJSM_tmp_response_rate_hdi_coverage_rate <- cbind(
    BJSM_tmp_response_rate_hdi_coverage_rate_theta_p, BJSM_tmp_response_rate_hdi_coverage_rate_theta_l,
    BJSM_tmp_response_rate_hdi_coverage_rate_theta_h, BJSM_tmp_response_rate_hdi_coverage_rate_pl,
    BJSM_tmp_response_rate_hdi_coverage_rate_ph
  )
  BJSM_response_rate_hdi_coverage_rate <- rbind(BJSM_response_rate_hdi_coverage_rate, BJSM_tmp_response_rate_hdi_coverage_rate)

  BJSM_tmp_response_rate_hdi_length_theta_p <- abs(BJSM_tmp_hdi["lower", "mu[1]"] - BJSM_tmp_hdi["upper", "mu[1]"])
  BJSM_tmp_response_rate_hdi_length_theta_l <- abs(BJSM_tmp_hdi["lower", "mu[2]"] - BJSM_tmp_hdi["upper", "mu[2]"])
  BJSM_tmp_response_rate_hdi_length_theta_h <- abs(BJSM_tmp_hdi["lower", "mu[3]"] - BJSM_tmp_hdi["upper", "mu[3]"])
  BJSM_tmp_response_rate_hdi_length_pl <- abs(BJSM_tmp_hdi["lower", "PL"] - BJSM_tmp_hdi["upper", "PL"])
  BJSM_tmp_response_rate_hdi_length_ph <- abs(BJSM_tmp_hdi["lower", "PH"] - BJSM_tmp_hdi["upper", "PH"])
  BJSM_tmp_response_rate_hdi_length <- cbind(
    BJSM_tmp_response_rate_hdi_length_theta_p, BJSM_tmp_response_rate_hdi_length_theta_l,
    BJSM_tmp_response_rate_hdi_length_theta_h, BJSM_tmp_response_rate_hdi_length_pl,
    BJSM_tmp_response_rate_hdi_length_ph
  )
  BJSM_response_rate_hdi_length <- rbind(BJSM_response_rate_hdi_length, BJSM_tmp_response_rate_hdi_length)

  BJSM_response_rate_posterior_mean <- rbind(BJSM_response_rate_posterior_mean, BJSM_tmp_response_rate_posterior_mean)


  return(list(
    "trad_mathod_response_rate_hdi_coverage_rate" = trad_mathod_tmp_response_rate_hdi_coverage_rate,
    "trad_mathod_response_rate_hdi_length" = trad_mathod_tmp_response_rate_hdi_length,
    "trad_mathod_response_rate_posterior_mean" = trad_mathod_tmp_response_rate_posterior_mean,
    "trad_mathod_final_mean" = trad_mathod_tmp_mean,
    "trad_mathod_P_CI" = trad_mathod_P_CI_tmp,
    "trad_mathod_L_CI" = trad_mathod_L_CI_tmp,
    "trad_mathod_H_CI" = trad_mathod_H_CI_tmp,
    "trad_mathod_PL_CI" = trad_mathod_PL_CI_tmp,
    "trad_mathod_PH_CI" = trad_mathod_PH_CI_tmp,
    "RMS_response_rate_hdi_coverage_rate" = RMS_tmp_response_rate_hdi_coverage_rate,
    "RMS_response_rate_hdi_length" = RMS_tmp_response_rate_hdi_length,
    "RMS_response_rate_posterior_mean" = RMS_tmp_response_rate_posterior_mean,
    "RMS_final_mean" = RMS_tmp_mean,
    "RMS_P_CI" = RMS_P_CI_tmp,
    "RMS_L_CI" = RMS_L_CI_tmp,
    "RMS_H_CI" = RMS_H_CI_tmp,
    "RMS_PL_CI" = RMS_PL_CI_tmp,
    "RMS_PH_CI" = RMS_PH_CI_tmp,
    "BJSM_response_rate_hdi_coverage_rate" = BJSM_tmp_response_rate_hdi_coverage_rate,
    "BJSM_response_rate_hdi_length" = BJSM_tmp_response_rate_hdi_length,
    "BJSM_response_rate_posterior_mean" = BJSM_tmp_response_rate_posterior_mean,
    "BJSM_final_mean" = BJSM_tmp_mean,
    "BJSM_P_CI" = BJSM_P_CI_tmp,
    "BJSM_L_CI" = BJSM_L_CI_tmp,
    "BJSM_H_CI" = BJSM_H_CI_tmp,
    "BJSM_PL_CI" = BJSM_PL_CI_tmp,
    "BJSM_PH_CI" = BJSM_PH_CI_tmp,
    "trueeffect" = trueeffect_tmp,
    "ESS_vector" = ESS_tmp
  ))
}

# combine result from parallel for loops
trad_mathod_response_rate_hdi_coverage_rate <- result$trad_mathod_response_rate_hdi_coverage_rate
trad_mathod_response_rate_hdi_length <- result$trad_mathod_response_rate_hdi_length
trad_mathod_response_rate_posterior_mean <- result$trad_mathod_response_rate_posterior_mean
trad_mathod_final_mean <- result$trad_mathod_final_mean
trad_mathod_P_CI <- result$trad_mathod_P_CI
trad_mathod_L_CI <- result$trad_mathod_L_CI
trad_mathod_H_CI <- result$trad_mathod_H_CI
trad_mathod_PL_CI <- result$trad_mathod_PL_CI
trad_mathod_PH_CI <- result$trad_mathod_PH_CI
RMS_response_rate_hdi_coverage_rate <- result$RMS_response_rate_hdi_coverage_rate
RMS_response_rate_hdi_length <- result$RMS_response_rate_hdi_length
RMS_response_rate_posterior_mean <- result$RMS_response_rate_posterior_mean
RMS_final_mean <- result$RMS_final_mean
RMS_P_CI <- result$RMS_P_CI
RMS_L_CI <- result$RMS_L_CI
RMS_H_CI <- result$RMS_H_CI
RMS_PL_CI <- result$RMS_PL_CI
RMS_PH_CI <- result$RMS_PH_CI
BJSM_response_rate_hdi_coverage_rate <- result$BJSM_response_rate_hdi_coverage_rate
BJSM_response_rate_hdi_length <- result$BJSM_response_rate_hdi_length
BJSM_response_rate_posterior_mean <- result$BJSM_response_rate_posterior_mean
BJSM_final_mean <- result$BJSM_final_mean
BJSM_P_CI <- result$BJSM_P_CI
BJSM_L_CI <- result$BJSM_L_CI
BJSM_H_CI <- result$BJSM_H_CI
BJSM_PL_CI <- result$BJSM_PL_CI
BJSM_PH_CI <- result$BJSM_PH_CI
trueeffect <- result$trueeffect
ESS_vector <- result$ESS_vector

stopCluster(my.cluster)

# check results
colMeans(trad_mathod_final_mean)
colMeans(trad_mathod_P_CI)
colMeans(trad_mathod_L_CI)
colMeans(trad_mathod_H_CI)
colMeans(trad_mathod_PL_CI)
colMeans(trad_mathod_PH_CI)

colMeans(RMS_final_mean)
colMeans(RMS_P_CI)
colMeans(RMS_L_CI)
colMeans(RMS_H_CI)
colMeans(RMS_PL_CI)
colMeans(RMS_PH_CI)

colMeans(BJSM_final_mean)
colMeans(BJSM_P_CI)
colMeans(BJSM_L_CI)
colMeans(BJSM_H_CI)
colMeans(BJSM_PL_CI)
colMeans(BJSM_PH_CI)


# save outcome
save.image(file = "patientSimuEXPOCT12_NSS.RData")
