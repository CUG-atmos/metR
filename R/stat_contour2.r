#' @inheritParams ggplot2::stat_identity
#' @param breaks One of:
#'   - A numeric vector of breaks
#'   - A function that takes the range of the data and binwidth as input
#'   and returns breaks as output
#' @param bins Number of evenly spaced breaks.
#' @param binwidth Distance between breaks.
#' @param circular either NULL, "x" or "y" indicating which dimension is circular,
#' if any.
#' @export
#' @section Computed variables:
#' \describe{
#'  \item{level}{height of contour}
#' }
#' @rdname geom_contour2
#' @family ggplot2 helpers
stat_contour2 <- function(mapping = NULL, data = NULL,
                         geom = "contour", position = "identity",
                         ...,
                         breaks = scales::fullseq,
                         bins = NULL,
                         binwidth = NULL,
                         na.rm = FALSE,
                         circular = NULL,
                         show.legend = NA,
                         inherit.aes = TRUE) {
  layer(
    data = data,
    mapping = mapping,
    stat = StatContour2,
    geom = geom,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = list(
      na.rm = na.rm,
      breaks = breaks,
      bins = bins,
      binwidth = binwidth,
      circular = circular,
      ...
    )
  )
}

#' @rdname geom_contour2
#' @usage NULL
#' @format NULL
StatContour2 <- ggplot2::ggproto("StatContour2", Stat,
  required_aes = c("x", "y", "z"),
  default_aes = ggplot2::aes(order = ..level..),

  compute_group = function(data, scales, bins = NULL, binwidth = NULL,
                           breaks = scales::fullseq, complete = FALSE,
                           na.rm = FALSE, circular = NULL) {

      # Check is.null(breaks) for backwards compatibility
      if (is.null(breaks)) {
          breaks <- scales::fullseq
      }

      if (is.function(breaks)) {
          # If no parameters set, use pretty bins to calculate binwidth
          if (is.null(bins) && is.null(binwidth)) {
              binwidth <- diff(pretty(range(data$z), 10))[1]
          }
          # If provided, use bins to calculate binwidth
          if (!is.null(bins)) {
              binwidth <- diff(range(data$z)) / bins
          }

          breaks <- breaks(range(data$z), binwidth)
      }

      if (!is.null(circular)) {
          # M <- max(data[[circular]]) + resolution(data[[circular]])
          data <- RepeatCircular(data, circular)
      }
      contours <- as.data.table(.contour_lines(data, breaks, complete = complete))

      if (length(contours) == 0) {
          warning("Not possible to generate contour data", call. = FALSE)
          return(data.frame())
      }
      contours <- .order_contour(contours, setDT(data))

      return(contours)
    }
)



.order_contour <- function(contours, data) {
    x.data <- unique(data$x)
    x.data <- x.data[order(x.data)]
    x.N <- length(x.data)
    y.data <- unique(data$y)
    y.data <- y.data[order(y.data)]
    y.N <- length(y.data)

    contours[, c("dx", "dy") := .(c(diff(x), NA), c(diff(y), NA)), by = group]

    segments <- contours[dx != 0 & dy != 0]

    segments[, c("x.axis", "y.axis") := .(x %in% x.data, y %in% y.data), by = group]

    # x axis
    x.axis <- segments[x.axis == TRUE]
    x.axis[, x.axis := NULL]   # remove annoying column
    x.axis[, y.d := .second(y.data, y), by = .(group, y)]  # select 2nd closest data point
    x.axis[, m := y - y.d]

    x.axis <- data[, .(x, y.d = y, z)][x.axis, on = c("x", "y.d")]  # get z column
    x.axis <- x.axis[level != z]
    x.axis <- x.axis[x.axis[, .I[1], by = group]$V1]   # select the first one.

    # Rotation...
    x.axis[, rotate := FALSE]
    x.axis[dx > 0, rotate := (sign(level - z) == sign(m))]
    x.axis[dx < 0, rotate := (sign(level - z) != sign(m))]

    # x axisd
    y.axis <- segments[y.axis == TRUE]
    y.axis[, y.axis := NULL]
    y.axis[, x.d := .second(x.data, x), by = .(x, group)]
    y.axis[, m := x - x.d]

    y.axis <- data[, .(x.d = x, y, z)][y.axis, on = c("x.d", "y")]
    y.axis <- y.axis[level != z]
    y.axis <- y.axis[y.axis[, .I[1], by = group]$V1]

    y.axis[, rotate := FALSE]
    y.axis[dy > 0, rotate := (sign(level - z) != sign(m))]
    y.axis[dy < 0, rotate := (sign(level - z) == sign(m))]

    rot.groups <- c(y.axis[rotate == TRUE]$group,
                                 x.axis[rotate == TRUE]$group)

    # rot.groups <- c(as.character(y.axis$group), as.character(x.axis$group))

    contours[, rotate := as.numeric(group[1]) %in% rot.groups, by = group]
    contours <- contours[contours[, ifelse(rotate == TRUE, .I[.N:1], .I), by = group]$V1]

    # Congratulations, your contours all have the same direction.
    return(contours)
}

.second <- function(x, target) {
    tmp <- (x - target)
    x[order(abs(tmp))][2]
}

.contour_lines <- function(data, breaks, complete = FALSE) {
  z <- tapply(data$z, data[c("x", "y")], identity)

  if (is.list(z)) {
    stop("Contour requires single `z` at each combination of `x` and `y`.",
         call. = FALSE)
  }

  cl <- grDevices::contourLines(
    x = sort(unique(data$x)), y = sort(unique(data$y)), z = z,
    levels = breaks)

  if (length(cl) == 0) {
    warning("Not possible to generate contour data", call. = FALSE)
    return(data.frame())
  }

  # Convert list of lists into single data frame
  lengths <- vapply(cl, function(x) length(x$x), integer(1))
  levels <- vapply(cl, "[[", "level", FUN.VALUE = double(1))
  xs <- unlist(lapply(cl, "[[", "x"), use.names = FALSE)
  ys <- unlist(lapply(cl, "[[", "y"), use.names = FALSE)
  pieces <- rep(seq_along(cl), lengths)
  # Add leading zeros so that groups can be properly sorted later
  groups <- paste(data$group[1], sprintf("%03d", pieces), sep = "-")

  data.frame(
    level = rep(levels, lengths),
    x = xs,
    y = ys,
    piece = pieces,
    group = groups
  )
}

#' @rdname geom_text_contour
#' @usage NULL
#' @format NULL
StatTextContour <- ggplot2::ggproto("StatTextContour", StatContour2,
  required_aes = c("x", "y", "z"),
  default_aes = ggplot2::aes(order = ..level.., label = ..level..)
)

