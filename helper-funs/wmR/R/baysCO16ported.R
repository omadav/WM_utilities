# This is a ported version of Paul Bays' Matlab code published at http://www.paulbays.com/code/CO16/
# This code is released under a GNU General Public License:
# feel free to use and adapt these functions as you like, but credit should be given to Paul Bays if they contribute to your work, by citing:
# Schneegans S & Bays PM. No fixed item limit in visuospatial working memory. Cortex 83: 181-193 (2016)

##########################################################################
#  Copyright 2018 Wanja Moessing. This program is free software: you can #
#  redistribute it and/or modify it under the terms of the GNU General   #
#  Public License as published by the Free Software Foundation.          #
##########################################################################

# ported version by Wanja Moessing, moessing@wwu.de
# % CO16_FIT (X, T, NT)
# %   Returns maximum likelihood parameters B for a mixture model describing
# %   recall responses X in terms of target T, non-target NT, and uniform
# %   responses. Inputs should be in radians, -PI <= X < PI. Fitting is based
# %   on an EM algorithm with multiple starting parameters.
# %
# %   B = CO16_FIT (X, T, NT) returns a vector [K pT pN pU], where K is
# %   the concentration parameter of a Von Mises distribution capturing
# %   response variability, pT is the probability of responding with the
# %   target value, pN the probability of responding with a non-target
# %   value, and pU the probability of responding "randomly".
# %
# %   [B LL] = CO16_FIT (X, T, NT) additionally returns the log likelihood LL.
# %
# %   [B LL W] = CO16_FIT (X, T, NT) additionally returns a weight matrix of
# %   trial-by-trial posterior probabilities that responses come from each of
# %   the three mixture components. Each row of W corresponds to a separate
# %   trial and is of the form [wT wN wU], corresponding to the probability
# %   the response comes from the target, non-target or uniform response
# %   distributions, respectively.
# %
# %   Refs:
#   %   Schneegans S & Bays PM. No fixed item limit in visuospatial working
# %   memory. Cortex 83: 181-193 (2016)
# %
# %   Bays PM, Catalao RFG & Husain M. The precision of visual working
# %   memory is set by allocation of a shared resource. Journal of Vision
# %   9(10): 7, 1-11 (2009)
# %
# %   --> www.paulbays.com

CO16_fit <- function(X, TT = NULL, NT=NULL) {
  require(pracma) # size, repmat etc
  # X = vector of responses
  # TT = vector of Target orientations
  # NT = (n×m) matrix of non-target values
  n = size(X, 1)

  if (is.null(TT)) { TT = zeros(n, 1)}

  if  (is.null(TT) || size(X, 2) > 1 || size(TT, 2) > 1 ||
       size(X, 1) != size(TT, 1) || is.null(NT) && (size(NT, 1) != size(X, 1) ||
                                                    size(NT, 1) != size(TT, 1))) {
    stop('Input is not correctly dimensioned.\n',
         'Did you use row instead of column vectors?\n',
         'Try X = matrix(X,length(X),1)')
  }

  if (is.null(NT)) {
    NT = zeros(n, 0)
    nn = 0
  } else {
    nn = size(NT, 2)
  }

  # Starting parameters
  K = c(1,    10,  100)
  N = c(0.01, 0.1, 0.4)
  U = c(0.01, 0.1, 0.4)

  if (nn == 0) {N = 0}

  LL = -Inf; B = c(NaN, NaN, NaN, NaN); W = NaN;

  #warning('off','JV10_function:MaxIter');

  # Parameter estimates
  for (i in 1:length(K)) {
    for (j in 1:length(N)) {
      for (k in 1:length(U)) {
        res <- CO16_function(X, TT, NT, c(K[i], 1 - N[j] - U[k], N[j], U[k]))
        b <- res[1][[1]]; ll <- res[2][[1]]; w <- res[3][[1]]; res <- NULL
        if (ll > LL) {
          LL = ll; B = b; W = w;
        }
      }
    }
  }
  #warning('on','JV10_function:MaxIter');
  return(list(B, LL, W))
}



CO16_function <- function(X, TT=NULL, NT=NULL, B_start=NULL) {
  require(pracma) #for repmat, size, ones, zeros
  # --> www.paulbays.com | R-port github.com/wanjam
  if  (is.null(TT) || size(X, 2) > 1 || size(TT, 2) > 1 ||
       size(X, 1) != size(TT, 1) || is.null(NT) && (size(NT, 1) != size(X, 1) ||
                                                    size(NT, 1) != size(TT, 1))) {
    stop('Input is not correctly dimensioned')
  }

  if (is.null(B_start) &&
      (B_start[1] < 0 || any(B_start[2:4] < 0) || any(B_start[2:4] > 1) ||
       abs(sum(B_start[2:4]) - 1) > 10^-6)) {
    stop('Invalid model parameters')
  }

  MaxIter = 10^4; MaxdLL = 10^-4

  n = size(X, 1)

  if (is.null(NT)) {
    NT = rep(0, n)
    nn = 0
  } else {
    nn = ncol(NT)
  }

  # Default starting parameters
  if (is.null(B_start)) {
    K = 5
    Pt = 0.5
    Pn = ifelse(nn > 0, 0.3, 0)
    Pu = 1 - Pt - Pn
  } else {
    K = B_start[1]
    Pt = B_start[2]
    Pn = B_start[3]
    Pu = B_start[4]
  }

  E  = X - TT
  E = ((E + pi) %% (2 * pi)) - pi
  NE = repmat(X, 1, nn) - NT
  NE = ((NE + pi) %% (2 * pi)) - pi

  LL = NaN; dLL = NaN; iter = 0

  while (TRUE) {
    iter = iter + 1
    Wt = Pt * vonmisespdf(E, 0, K)
    Wg = Pu * ones(n, 1) / (2 * pi)

    if (nn == 0) {
      Wn = zeros(size(NE))
    } else {
      Wn = Pn / nn * vonmisespdf(NE, 0, K)
    }

    W = t(t(rowSums(cbind(Wt, Wn, Wg))))

    dLL = LL - sum(log(W))
    LL = sum(log(W))

    # had to split that up, as in Matlab NaN<float is TRUE, in R is NA
    if (!is.nan(dLL)) {
      if (abs(dLL) < MaxdLL) {break}
    }
    if (iter > MaxIter) {break}


    Pt = sum(Wt / W) / n
    Pn = sum(rowSums(Wn) / W) / n
    Pu = sum(Wg / W) / n

    rw = cbind((Wt / W), (Wn / repmat(W, 1, nn)))

    S = cbind(sin(E), sin(NE))
    C = cbind(cos(E), cos(NE))
    r = cbind(sum(sum(S * rw)), sum(sum(C * rw)))

    if (sum(sum(rw)) == 0) {
      K = 0
    } else {
      R = sqrt(sum(r^2)) / sum(sum(rw))
      K = A1inv(R)
    }

    if (n <= 15) {
      if (K < 2) {
        K = max(K - 2 / (n * K), 0)
      } else {
        K = K * (n - 1)^3 / (n^3 + n)
      }
    }
  }
  if (iter > MaxIter) {
    warning('JV10_function:MaxIter: ','Maximum iteration limit exceeded.')
    B = c(NaN, NaN, NaN, NaN)
    LL = NaN
    W = NaN
  } else {
    B = c(K, Pt, Pn, Pu)
    W <- cbind(Wt / W, t(t(rowSums(Wn, 2))) / W, Wg / W)
  }
  return(list(B, LL, W))
}



#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%   Copyright 2017 Paul Bays. This program is free software: you can     %
#%   redistribute it and/or modify it under the terms of the GNU General  %
#%   Public License as published by the Free Software Foundation.         %
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

vonmisespdf <- function(x, mu, K) {
  # VONMISESPDF Von Mises probability density function (pdf)
  #   Y = VONMISESPDF(THETA,MU,K) returns the pdf of the Von Mises
  #   distribution with mean MU and concentration parameter K,
  #   evaluated at the values in THETA (given in radians).
  #
  #   --> www.paulbays.com
  p = exp( K * cos( x - mu) - log(2 * pi) * besseliln(0, K));
  return(p)
}

besseliln <- function(nu,z){
  w = log(besselI(z, nu, 1)) + abs(Re(z))
  return(w)
}


# A1inv <- function(R) {
#   if (0 <= R & R < 0.53) {
#     K = 2 * R + R^3 + (5 * R^5) / 6
#   } else if (R < 0.85) {
#     K = -0.4 + 1.39 * R + 0.43 / (1 - R)
#   } else {
#     K = 1 / (R^3 - 4 * R^2 + 3 * R)
#   }
#   return(K)
# }