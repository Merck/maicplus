#' helper function: makeup to get median survival time from a survival::survfit object
#'
#' extract and display median survival time with confidence interval
#'
#' @param km_fit returned object from \code{survival::survfit}
#' @param legend a character string, name used in 'type' column in returned data frame
#' @param time_scale a character string, 'year', 'month', 'week' or 'day', time unit of median survival time
#'
#' @return a data frame with a index column 'type', mdian survival time and confidence interval
#' @export
medSurv_makeup <- function(km_fit, legend = "before matching", time_scale) {
  timeUnit <- list("year" = 365.24, "month" = 30.4367, "week" = 7, "day" = 1)

  if (!time_scale %in% names(timeUnit)) stop("time_scale has to be 'year', 'month', 'week' or 'day'")

  # km_fit is the returned object from survival::survfit
  km_fit <- summary(km_fit)$table
  km_fit[, 5:ncol(km_fit)] <- km_fit[, 5:ncol(km_fit)] / timeUnit[[time_scale]]

  toyadd <- data.frame(
    treatment = gsub("treatment=", "", rownames(km_fit)),
    type = rep(legend, 2)
  )

  km_fit <- cbind(toyadd, km_fit)
  rownames(km_fit) <- NULL

  km_fit
}



#' helper function: makeup survival::survfit object for km plot
#'
#' @param km_fit returned object from \code{survival::survfit}
#'
#' @export
#'
#' @return a list of data frames, one element per treatment
survfit_makeup <- function(km_fit) {
  kmdat <- data.frame(
    time = km_fit$time,
    treatment = unlist(mapply(rep, 1:2, each = km_fit$strata)),
    n.risk = km_fit$n.risk,
    n.event = km_fit$n.event,
    censor = km_fit$n.censor,
    surv = km_fit$surv,
    lower = km_fit$lower,
    upper = km_fit$upper,
    cumhaz = km_fit$cumhaz
  )
  kmdat$treatment <- gsub("treatment=", "", attr(km_fit$strata, "names"))[kmdat$treatment]
  split(kmdat, f = kmdat$treatment)
}


#' helper function: KM plot with unadjusted and adjusted KM
#'
#' @param km_fit_before returned object from \code{survival::survfit} before adjustment
#' @param km_fit_after returned object from \code{survival::survfit} after adjustment
#' @param time_scale a character string, 'year', 'month', 'week' or 'day', time unit of median survival time
#' @param trt  a character string, name of the interested treatment in internal trial (real IPD)
#' @param trt_ext character string, name of the interested comparator in external trial used to subset \code{dat_ext} (pseudo IPD)
#' @param endpoint_name a character string, name of the endpoint
#'
#' @return a KM plot
km_makeup <- function(km_fit_before, km_fit_after = NULL, time_scale, trt, trt_ext, endpoint_name = "") {
  timeUnit <- list("year" = 365.24, "month" = 30.4367, "week" = 7, "day" = 1)

  if (!time_scale %in% names(timeUnit)) stop("time_scale has to be 'year', 'month', 'week' or 'day'")

  # prepare data for plot
  pd_be <- survfit_makeup(km_fit_before)
  if (!is.null(km_fit_after)) pd_af <- survfit_makeup(km_fit_after)

  # set up x axis (time)
  if (!is.null(km_fit_after)) {
    max_t <- max(km_fit_before$time, km_fit_after$time)
  } else {
    max_t <- max(km_fit_before$time)
  }
  t_range <- c(0, (max_t / timeUnit[[time_scale]]) * 1.07)

  # base plot
  par(mfrow = c(1, 1), bty = "n", tcl = -0.15, mgp = c(2.3, 0.5, 0))
  plot(0, 0,
    type = "n", xlab = paste0("Time in", time_scale), ylab = "Survival Probability",
    ylim = c(0, 1), xlim = t_range, yaxt = "n",
    main = paste0(
      "Kaplan-Meier Curves of Comparator ", ifelse(!is.null(km_fit_after), "(AgD) ", ""),
      "and Treatment ", ifelse(!is.null(km_fit_after), "(IPD)", ""),
      "\nEndpoint: ", endpoint_name
    )
  )
  axis(2, las = 1)

  # add km lines from external trail
  lines(
    y = pd_be[[trt_ext]]$surv,
    x = (pd_be[[trt_ext]]$time / timeUnit[[time_scale]]), col = "#5450E4",
    type = "s"
  )
  tmpid <- pd_be[[trt_ext]]$censor == 1
  points(
    y = pd_be[[trt_ext]]$surv[tmpid],
    x = (pd_be[[trt_ext]]$time[tmpid] / timeUnit[[time_scale]]),
    col = "#5450E4", pch = 3, cex = 0.7
  )

  # add km lines from internal trial before adjustment
  lines(
    y = pd_be[[trt]]$surv,
    x = (pd_be[[trt]]$time / timeUnit[[time_scale]]), col = "#00857C",
    type = "s"
  )
  tmpid <- pd_be[[trt]]$censor == 1
  points(
    y = pd_be[[trt]]$surv[tmpid],
    x = (pd_be[[trt]]$time[tmpid] / timeUnit[[time_scale]]),
    col = "#00857C", pch = 3, cex = 0.7
  )

  # add km lines from internal trial after adjustment
  if (!is.null(km_fit_after)) {
    lines(
      y = pd_af[[trt]]$surv,
      x = (pd_af[[trt]]$time / timeUnit[[time_scale]]), col = "#6ECEB2", lty = 2,
      type = "s"
    )
    tmpid <- pd_af[[trt]]$censor == 1
    points(
      y = pd_af[[trt]]$surv[tmpid],
      x = (pd_af[[trt]]$time[tmpid] / timeUnit[[time_scale]]),
      col = "#6ECEB2", pch = 3, cex = 0.7
    )
  }

  use_leg <- 1:ifelse(is.null(km_fit_after), 2, 3)
  # add legend
  legend("topright",
    bty = "n", lty = c(1, 1, 2)[use_leg], cex = 0.8, col = c("#5450E4", "#00857C", "#6ECEB2")[use_leg],
    legend = c(
      paste0("Comparator: ", trt_ext),
      paste0("Treatment: ", trt),
      paste0("Treatment: ", trt, "(with weights)")
    )[use_leg]
  )
}


#' Plot Log Cumulative Hazard Rate
#'
#' a diagnosis plot for proportional hazard assumption, versus log-time (default) or time
#'
#' @param clldat object returned from \code{\link{survfit_makeup}}
#' @param time_scale a character string, 'year', 'month', 'week' or 'day', time unit of median survival time
#' @param log_time logical, TRUE (default) or FALSE
#' @param endpoint_name a character string, name of the endpoint
#' @param subtitle a character string, subtitle of the plot
#' @param exclude_censor logical, should censored data point be plotted
#'
#' @return a plot
#' @export
log_cum_haz_plot <- function(clldat, time_scale, log_time = TRUE, endpoint_name = "", subtitle = "", exclude_censor = TRUE) {
  timeUnit <- list("year" = 365.24, "month" = 30.4367, "week" = 7, "day" = 1)
  if (!time_scale %in% names(timeUnit)) stop("time_scale has to be 'year', 'month', 'week' or 'day'")

  if (exclude_censor) {
    clldat <- lapply(clldat, function(xxt) xxt[xxt$censor == 0, , drop = FALSE])
  }

  all.times <- do.call(rbind, clldat)$time / timeUnit[[time_scale]]
  if (log_time) all.times <- log(all.times)
  t_range <- range(all.times)
  y_range <- range(log(do.call(rbind, clldat)$cumhaz))

  par(mfrow = c(1, 1), bty = "n", tcl = -0.15, mgp = c(2.3, 0.5, 0))
  plot(0, 0,
    type = "n", xlab = paste0(ifelse(log_time, "Log-", ""), "Time in ", time_scale),
    ylab = "Log-Cumulative Hazard Rate",
    ylim = y_range, xlim = t_range, yaxt = "n",
    main = paste0(
      "Diagnosis plot for Proportional Hazard assumption\nEndpoint: ", endpoint_name,
      ifelse(subtitle == "", "", "\n"), subtitle
    )
  )
  axis(2, las = 1)

  trts <- names(clldat)
  cols <- c("dodgerblue3", "firebrick3")
  pchs <- c(1, 4)
  for (i in seq_along(clldat)) {
    use_x <- (clldat[[i]]$time / timeUnit[[time_scale]])
    if (log_time) use_x <- log(use_x)

    lines(
      y = log(clldat[[i]]$cumhaz),
      x = use_x, col = cols[i]
    )
    points(
      y = log(clldat[[i]]$cumhaz),
      x = use_x,
      col = cols[i], pch = pchs[i], cex = 0.7
    )
  }
  legend("bottomright",
    bty = "n", lty = c(1, 1, 2), cex = 0.8,
    col = cols, pch = pchs, legend = paste0("Treatment: ", trts)
  )
}


#' Plot schoenfeld residual plot for a Cox model fit
#'
#' @param coxobj object returned from \code{\link[surival]{coxph}}
#' @param time_scale a character string, 'year', 'month', 'week' or 'day', time unit of median survival time
#' @param log_time logical, TRUE (default) or FALSE
#' @param endpoint_name a character string, name of the endpoint
#' @param subtitle a character string, subtitle of the plot
#'
#' @return a plot
#' @export

resid_plot <- function(coxobj, time_scale = "month", log_time = TRUE, endpoint_name = "", subtitle = "") {
  timeUnit <- list("year" = 365.24, "month" = 30.4367, "week" = 7, "day" = 1)
  if (!time_scale %in% names(timeUnit)) stop("time_scale has to be 'year', 'month', 'week' or 'day'")

  schresid <- residuals(coxobj, type = "schoenfeld")
  plotX <- as.numeric(names(schresid)) / timeUnit[[time_scale]]
  if (log_time) plotX <- log(plotX)
  par(mfrow = c(1, 1), bty = "n", tcl = -0.15, mgp = c(2.3, 0.5, 0))
  plot(schresid ~ plotX,
    cex = 0.9, col = "navyblue", yaxt = "n",
    ylab = "Unscaled Schoenfeld Residual", xlab = paste0(ifelse(log_time, "Log-", ""), "Time in ", time_scale),
    main = paste0(
      "Diagnosis Plot: Unscaled Schoefeld Residual\nEndpoint: ", endpoint_name,
      ifelse(subtitle == "", "", "\n"), subtitle
    )
  )
  axis(2, las = 1)
}
