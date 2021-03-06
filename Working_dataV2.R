### PAPER ###

.First <- function() { 
  Sys.setlocale("LC_TIME", "English")
}


library(data.table)
library(ggplot2)
library(lubridate)
library(dyn)
library(reshape2)
library(zoo)


# Loading data and fixing a problem with column name
mydata  <- read.csv2("C:/Users/Oegaard/Desktop/aau/Paper/Forecasting/Data/annual2016.csv", 
                     na.strings="NaN", stringsAsFactors=FALSE)

mydata  <- as.data.table(mydata)
names(mydata)[1]<-"Dato"
mydata <- mydata[, Dato := ydm(Dato)]


# Constructing time series of various lenghts.
tsindex <- zoo(mydata$Index,mydata$Dato)
plot(tsindex, xlab="Year", ylab="Price", col = "blue")

tsdiv <- zoo(mydata$D12, mydata$Dato)
plot(tsdiv, xlab="Year", ylab="Dividend", col = "blue")

plot.zoo(cbind((tsindex),(tsdiv)), plot.type = "multiple", col = c("red","blue"),main = "", xlab ="Year",
         ylab = c("Stock Index", "Dividend"))

plot.zoo(cbind(log(tsindex),log(tsdiv)), plot.type = "multiple", col = c("red","blue"),main = "", xlab ="Year",
         ylab = c("Stock Index", "Dividend"))

         
         
tsindex1990 <- zoo(mydata$Index[120:nrow(mydata)],mydata$Dato[120:nrow(mydata)])
plot(tsindex1990, xlab="Year", ylab="Price", col = "blue", ylim = c(0,max(tsindex1990)))

tsindex2000 <- zoo(mydata$Index[130:nrow(mydata)],mydata$Dato[130:nrow(mydata)])
plot(tsindex2000, xlab="Year", ylab="Price", col = "blue", ylim = c(0,max(tsindex1990)))





mydata <- mydata[, IndexDiv := Index + D12]
mydata <- mydata[, dp := log(D12) - log(Index)]
mydata <- mydata[, ep := log(E12) - log(Index)]


vec_dy <- c(NA, mydata[2:nrow(mydata), log(D12)] - mydata[1:(nrow(mydata)-1), log(Index)])
mydata <- mydata[, dy := vec_dy]

mydata <- mydata[, logret   :=c(NA,diff(log(Index)))]
vec_logretdiv <- c(NA, mydata[2:nrow(mydata), log(IndexDiv)] - mydata[1:(nrow(mydata)-1), log(Index)])

vec_logretdiv <- c(NA, log(mydata[2:nrow(mydata), IndexDiv]/mydata[1:(nrow(mydata)-1), Index]))

mydata <- mydata[, logretdiv:=vec_logretdiv]
mydata <- mydata[, logRfree := log(Rfree + 1)]
mydata <- mydata[, rp_div   := logretdiv - logRfree]


summary(mydata[c(56:132),logretdiv*100])
sd(mydata[c(56:132),Index])
skew(mydata[c(56:132),logretdiv*100])
kurtosis(mydata[c(56:132),logretdiv*100])

summary(mydata[c(56:132),dy])

summary(mydata[c(56:132),dp])

summary(mydata[c(56:132),rp_div*100])
sd(mydata[c(56:132),rp_div*100])


plot(mydata$logretdiv[56:132], type="l")


#Put it in time series (is needed in function get_statistics)
ts_annual <- ts(mydata, start=mydata[1, Dato], end=mydata[nrow(mydata), Dato])

plot(ts.mydata[, c("rp_div", "dp", "dy")])


plot(ts.mydata[,"Index"], ylab ="Stock Index")


#####################################################################################################



get_statistics <- function(ts.mydata, indep, dep, start=1926, end=2016, est_periods_OOS = 20) {
  
  # IS ANALYSIS
  # 1. Historical mean model
  IS_error_N <- (window(ts.mydata, start, end)[, dep] - mean(window(ts.mydata, start, end)[, dep], na.rm=TRUE))
  
  # 2. OLS model
  reg <- dyn$lm(eval(parse(text=dep)) ~ lag(eval(parse(text=indep)), -1), data=window(ts.mydata, start, end))
  IS_error_A <- reg$residuals
   
  
  # OOS ANALYSIS
  OOS_error_N <- numeric(end - start - est_periods_OOS)
  OOS_error_A <- numeric(end - start - est_periods_OOS)
  
  # Only use information that is available up to the time at which the forecast is made
  j <- 0
  for (i in (start + est_periods_OOS):(end-1)) {
    j <- j + 1
    
    # Get the actual ERP that you want to predict
    actual_EPR <- as.numeric(window(ts.mydata, i+1, i+1)[, dep])
    
    # 1. Historical mean model
    OOS_error_N[j] <- actual_EPR - mean(window(ts.mydata, start, i)[, dep], na.rm=TRUE)
    
    # 2. OLS model
    reg_OOS <- dyn$lm(eval(parse(text=dep)) ~ lag(eval(parse(text=indep)), -1), 
                      data=window(ts.mydata, start, i))
    
    # Compute_error
    df <- data.frame(x=as.numeric(window(ts.mydata, i, i)[, indep]))
    names(df) <- indep
    pred_EPR   <- predict.lm(reg_OOS, newdata=df)
    OOS_error_A[j] <-  pred_EPR - actual_EPR
  }
  
  # Compute statistics 
  MSE_N <- mean(OOS_error_N^2)
  MSE_A <- mean(OOS_error_A^2)
  T <- length(!is.na(ts.mydata[, dep]))
  OOS_R2  <- 1 - MSE_A/MSE_N
  OOS_oR2 <- OOS_R2 - (1-OOS_R2)*(reg$df.residual)/(T - 1) 
  dRMSE <- sqrt(MSE_N) - sqrt(MSE_A)
  
  
  # CREATE PLOT
  IS  <- cumsum(IS_error_N[2:length(IS_error_N)]^2)-cumsum(IS_error_A^2)
  OOS <- cumsum(OOS_error_N^2)-cumsum(OOS_error_A^2)
  df  <- data.frame(x=seq.int(from=start + 1 + est_periods_OOS, to=end), 
                    IS=IS[(1 + est_periods_OOS):length(IS)], 
                    OOS=OOS) 
  
  
  df$IS <- df$IS - df$IS[1] 
  df  <- melt(df, id.var="x") 
  plotGG <- ggplot(df) + 
    geom_line(aes(x=x, y=value,color=variable)) + 
    geom_rect(data=data.frame(),                              
              aes(xmin=1973, xmax=1975,ymin=-0.2,ymax=0.2), 
              fill='red',
              alpha=0.1) + 
    scale_y_continuous('Cumulative SSE Difference', limits=c(-0.2, 0.2)) + 
    scale_x_continuous('Year')
  
  
  return(list(IS_error_N = IS_error_N,
              IS_error_A = reg$residuals,
              OOS_error_N = OOS_error_N,
              OOS_error_A = OOS_error_A,
              IS_R2 = summary(reg)$r.squared, 
              IS_aR2 = summary(reg)$adj.r.squared, 
              OOS_R2  = OOS_R2,
              OOS_oR2 = OOS_oR2,
              dRMSE = dRMSE,
              plotGG = plotGG))
}


########################################################################################################

dy_stat <- get_statistics(ts.mydata, "dy", "rp_div", start=1926, end=2016)
dp_stat$plotGG

dp_stat <- get_statistics(ts.mydata, "dp", "rp_div", start=1926, end=2016)
dp_stat$plotGG

ep_stat <- get_statistics(ts.mydata, "ep", "rp_div", start=1926, end=2016)
dp_stat$plotGG


dy_stat$IS_R2*100
dy_stat$IS_aR2*100
dy_stat$OOS_R2*100
dy_stat$OOS_oR2*100
dy_stat$dRMSE*100


dp_stat$IS_R2*100
dp_stat$IS_aR2*100
dp_stat$OOS_R2*100
dp_stat$OOS_oR2*100
dp_stat$dRMSE*100


ep_stat$IS_R2*100
ep_stat$IS_aR2*100
ep_stat$OOS_R2*100
ep_stat$OOS_oR2*100
ep_stat$dRMSE*100

#######################################################################################################
