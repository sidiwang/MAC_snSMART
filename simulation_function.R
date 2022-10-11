# use this function to simulate trial data

dataGen_bivaraite = function(mu, mu_co, sd_ij, cov_jj, n, p){
  
  # p is the probability in mixture model (exchangeability - nonexchangeability)
  
  mu_p = mu[1]
  mu_l = mu[2]
  mu_h = mu[3]
  
  n_c = n[4]
  n_p = n[1]
  n_l = n[2]
  n_h = n[3]
  
  sigma_k = sd_ij[1 : n_c]
  
  # simulate historical Y_k
  # Y_k = rep(NA, n_c)
  # for (i in c(1 : n_c)){
  #   z = rbinom(1, 1, p)
  #   Y_k[i] = z * rnorm(1, mean = mu_p, sd = sigma_k[i]) + (1 - z) * rnorm(1, mean = 0, sd = 3)
  # }
  
  Y_k = rep(NA, n_c)
  Y_k = rnorm(n_c, mean = mu_co, sd = sigma_k[1])
  #Y_k[sample(c(1:n_c), 0)] = rnorm(2, mean = mu_p, sd = sigma_k[1])
  
  # simulate stage 1 outcome Y_1
  Y_1 = c()
  for(i in 1 : length(mu)){
    Y_1 = c(Y_1, rnorm(n[i], mean = mu[i], sd = sd_ij[n_c + i] * sqrt(n[i])))
  }
  
  
  # stage 1 assignment
  trt1 = c()
  for (i in 1 : length(mu)){
    trt1 = c(trt1, rep(i, n[i]))
  }
  
  # flag of whether treatment is effective or not
  threshold = -3.1
  stage_I_outcome_binary = Y_1 >= threshold
  
  # stage 2 assignment
  flag = TRUE
  while (flag == TRUE){
    trt2 = c()
    trt2 = c(trt2, rbinom(n_p, 1, 0.5))
    if (sum(trt2) <= 1 | sum(trt2) >= n_p - 1){
      flag = TRUE
    } else {
      flag = FALSE
    }
  }
  trt2 = c(trt2, ifelse(stage_I_outcome_binary[(n_p + 1) : (n_p + n_l)] == 1, 0, 1))
  trt2 = c(trt2, ifelse(stage_I_outcome_binary[(n_p + n_l + 1) : length(Y_1)] == 1, rbinom(sum(stage_I_outcome_binary[(n_p + n_l + 1) : length(Y_1)] == 1), 1, 0.5), NA))
  trt2 = trt2 + 1
  
  
  counts = table(trt1, trt2)
  
  # stage II outcome Y_2
  Y_2 = c()
  for (i in 1 : sum(n_p, n_l, n_h)){
    if (is.na(trt2[i])){
      Y_2 = c(Y_2, NA)
    } else {
      stage2outcomeDistn = condMVNorm::condMVN(mean = c(mu[trt1[i]], mu[trt2[i] + 1]), sigma = matrix(c((sd_ij[n_c + trt1[i]])^2, cov_jj[trt1[i], trt2[i]], cov_jj[trt1[i], trt2[i]], (sd_ij[n_c + trt2[i] + 3])^2), 2, 2) * counts[trt1[i], trt2[i]],
                                               dependent.ind = 2,
                                               given.ind = 1,
                                               X.given = Y_1[i])
      Y_2 = c(Y_2, rnorm(1, stage2outcomeDistn$condMean, sd = sqrt(stage2outcomeDistn$condVar)))
    }
  }
  id = seq(1:sum(n_p, n_l, n_h))
  trt2 = trt2 + 1
  stay = as.numeric(trt2 == trt1)
  trial.data = data.frame(id, trt1, Y_1, stay, trt2, Y_2)
  
  result = list("trial.data" = trial.data, "Y_k" = Y_k)
  
  return(result)
}