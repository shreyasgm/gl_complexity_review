# Purpose: Basics of linear algebra in R
#-------------------------------------------------------------------
# HOUSEKEEPING
rm(list = ls())

# Load packages
packages <-
  c("tidyverse",
    "here",
    "Matrix")
sapply(packages, library, character.only = T)

# Set working directory appropriately
# setwd(
#   "/Users/shg309/Dropbox (Personal)/Education/hks_cid_growth_lab/misc/gl_complexity_review"
# )
here::i_am("proj/api_313m/linear_algebra.R")
#---------------------

# Vectors
vec <- c(1, 2, 3, 4)
vec <- 1:4

# Matrices
A <- matrix(
  data = 1:20,
  nrow = 4,
  ncol = 5,
  byrow = TRUE
)

B <- matrix(
  data = 21:40,
  nrow = 4,
  ncol = 5,
  byrow = FALSE
)

# Element-wise operations
A + B
A - B
A * B
A / B

# Basic transformations
# Transpose
t(A)

# Matrix multiplication (dot product)
C <- A %*% t(B)
dim(C)

# Diagonal of matrix?
diag(C)

# What is diag(A) for non-square matrices?

# Concatenate matrices along rows or columns
rbind(A, B)
cbind(A, B)

# Common transformations
A[1, 2] <- NA
rowSums(A, na.rm=TRUE)
colSums(A)

# What if I have NA's in the matrix?

# Eigen decomposition
eigen(C)

# Inverse of a matrix
D <- Matrix(data = c(5, 1, 1, 3), nrow = 2)
solve(D)
