
<!-- README.md is generated from README.Rmd. Please edit that file -->
metR
====

[![Build Status](https://travis-ci.org/eliocamp/meteoR.svg?branch=master)](https://travis-ci.org/eliocamp/meteoR)

meteR packages several functions and utilities that make R better for hadling meteorological data in the tidy data paradigm. It's not intended to be the be-all and end-all and is (at least for now) mostly a packaging of assorted wrapers and tricks that I wrote for my day to day work as a researcher in atmospheric sciences. Since it's grown organically and for my own needs, do not expect a heavy emphasis on consistency across functions and do expect functions written with specific use cases in mind.

Conceptually it's divided into *visualization tools* and *data tools*. The former are geoms, stats and scales that help with plotting using [ggplot2](http://ggplot2.tidyverse.org/index.html), such as `stat_contour_fill()` or `scale_y_level()`, while the later are functions for common data processing tools in the atmospheric sciences, such as `Derivate()` or `EOF()`; these are implemented to work in the [data.table](https://github.com/Rdatatable/data.table/wiki) paradigm, but also work with regular data frames.

Currently meteoR is in developement and should only be used carefully. Functions do not generaly check arguments and do not print error messages. There are also no tests, so coverage is exactly 0%.

Installation
------------

You can install meteoR from github with:

``` r
# install.packages("devtools")
devtools::install_github("eliocamp/metR")
```

Examples
--------

In this example we easily perform Principal Components Decomposition (EOF) on monthly geopotential height and plot it to get the Antarctic Oscillation.

``` r
library(meteoR)
library(data.table)
library(ggplot2)

# Use Empirical Orthogonal Functions to compute the Antarctic Oscillation
aao <- copy(aao)
aao[, gh.t.w := Anomaly(gh)*sqrt(cos(lat*pi/180)),
      by = .(lon, lat, month(date))]
aao.svd <- EOF(aao, lat + lon ~ date, value.var = "gh.t.w", n = 1)

# AAO field
ggplot(aao.svd$left, aes(lon, lat, z = value)) +
    stat_contour_fill() +    # filled contours!
    scale_x_longitude() +
    scale_y_latitude(limits = c(-90, -20)) +
    scale_fill_divergent(name = "AAO pattern") +
    coord_polar()
```

![](README-example-1.png)

``` r
# AAO signal
g <- ggplot(aao.svd$right, aes(date, value)) +
    geom_line() +
    geom_smooth(span = 0.4)

DivideTimeseries(g, aao.svd$right$date, xlab = "Date", ylab = "AAO signal")
#> `geom_smooth()` using method = 'loess' and formula 'y ~ x'
#> `geom_smooth()` using method = 'loess' and formula 'y ~ x'
#> `geom_smooth()` using method = 'loess' and formula 'y ~ x'
```

![](README-unnamed-chunk-2-1.png)

You can read more in the vignettes (comming soon).
