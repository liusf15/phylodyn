#' Unique encoding of ranked tree shapes
#'
#' @description  This function generates a F-matrix, a matrix that encodes
#' a ranked tree shape of an input tree.
#' Works for both isochronous and heterochronous trees.
#'
#' @param tr An object of class \code{phylo}. Can be either isochronous or heterochronous.
#' @param tol Numerical tolerance.
#'
#' @return F-matrix of the input tree.
#'
#' @details The time starts from zero at the first sampling event \eqn{u_{n+m-1}}.
#' An F-matrix that encodes the ranked tree shape of the input \code{tr} is
#' a lower triangular matrix of integers with elements \eqn{F_{i,j}=0} for all
#' \eqn{i < j}, and for \eqn{1 \le j \le i}, \eqn{F_{i,j}} is the number of
#' extant lineages in \eqn{(u_{j+1}, u_{j})} that do not bifurcate or become
#' extinct during the entire time internval \eqn{(u_{i+1}, u_{j})}.
#'
#' \code{tol} is introduced to fix the issue that nodes sampled at the same time
#' are treated as samples from different sampling times due to numerical error.
#' Here, if the samples are sampled at times within \code{tol}, they're treated
#' as sampled at the same time.
#'
#' @examples
#' # Generate a sample tree
#' tr <- ape::rcoal(5)
#' Fmat <- gen_Fmat(tr)
#'
#' @author Jaehee Kim, Julia Palacios
#'
#' @references Kim J, Rosenberg NA, Palacios JA, 2019.
#' \emph{A Metric Space of Ranked Tree Shapes and Ranked Genealogies}.

gen_Fmat <- function(tr, tol=13) {

    if (class(tr) != 'phylo') {
        stop('The input tree must be a phylo object')
    }

    edge.mat <- tr$edge
    n.sample <- tr$Nnode + 1

    t.tot <- max(ape::node.depth.edgelength(tr))
    n.t <-  t.tot - ape::node.depth.edgelength(tr)

    edge.mat <- tr$edge
    t.dat <- data.frame(lab.1=edge.mat[,1], lab.2=edge.mat[,2],
                        t.end=n.t[edge.mat[,1]], t.start=n.t[edge.mat[,2]])
    t.dat <- t.dat[order(t.dat$lab.2), ]

    # coalescent times
    coal.t <- sort(n.t[(n.sample+1) : length(n.t)])
    n.c.event <- length(coal.t) #number of coalescent event

    # sampling times
    # correct for numerical issue in sampling time
    tmp.s.t <- round(n.t[1 : n.sample], digits=tol)
    for (i in 1:n.sample) {
        tmp.ind <- which(tmp.s.t == tmp.s.t[i])
        if (length(tmp.ind) > 1) {
            group.t <- min(n.t[tmp.ind]) # replace with min of grouped sampling time
            n.t[tmp.ind] <- group.t
            t.dat[tmp.ind, 4] <- group.t
        }
    }
    sample.t <- sort(unique(n.t[1 : n.sample]))
    n.s.event <- length(sample.t) # number of sampling events
    stopifnot(n.s.event == length(unique(tmp.s.t)))


    # combined time points for F-matrix
    u.t <- data.frame(t=c(coal.t, sample.t),
                      type=c(rep('c', n.c.event), rep('s', n.s.event)),
                      c.id=c(seq(n.c.event), rep(-9, n.s.event)),
                      s.id=c(rep(-9, n.c.event), seq(n.s.event)),
                      stringsAsFactors=FALSE)
    u.t <- u.t[order(u.t$t, decreasing=TRUE),]
    rownames(u.t) <- paste('u', 1:(n.c.event+n.s.event), sep='.')

    ## Construct F matrix
    # n.col = n.row = (# sampling event) + (# of coalescent event) - 1
    # F(i,j) = # of lineages that exist and do not coalesce in (u_j, u_{j-1}).

    f.dim <- n.s.event + n.c.event
    Fmat <- matrix(0, nrow=f.dim, ncol=f.dim)

    for (i in 2:f.dim) {
        for (j in 2:i) {
            u.start <- u.t$t[i]
            u.end <- u.t$t[j-1]
            Fmat[i,j] <- sum((t.dat$t.end >= u.end) & (t.dat$t.start <= u.start))
        }
    }

    Fmat <- Fmat[2:f.dim, 2:f.dim]

    return(Fmat)
}


gen.tr.data <- function(tr, tol=13) {
    ## ================================================================
    # Get depth of each coalescent node and relabel
    # The time starts from zero at the first sampling event (u_{n+m-1}).
    # This is a revised version to correct for the sampling time numerical issue.
    # Instead of rounding up all edge and branch lengths, it clusters
    # sampling events occuring within tol into one sampling event.
    #
    ## Input:
    #   tr: phylo object tree.
    #   tol: numerical precision to round up time at each node to avoid
    #           the nodes sampled at the same time is treated as sampled
    #           at different times due to numerical error.
    #
    ## Output:
    #   list object containing the following
    #   Fmat: F-matrix of the input tr
    #   u.info: data.frame with time, event type, and other info of the tree
    #
    # Note that the tip labels are always labled with 1:n.tip and
    # the internal nodes are (n.tip+1):(2*n.tip-1) in phylo.

    if (class(tr) != 'phylo') {
        stop('The input tree must be a phylo object')
    }

    edge.mat <- tr$edge
    n.sample <- tr$Nnode + 1

    t.tot <- max(ape::node.depth.edgelength(tr))
    n.t <-  t.tot - ape::node.depth.edgelength(tr)

    edge.mat <- tr$edge
    t.dat <- data.frame(lab.1=edge.mat[,1], lab.2=edge.mat[,2],
                        t.end=n.t[edge.mat[,1]], t.start=n.t[edge.mat[,2]])
    t.dat <- t.dat[order(t.dat$lab.2), ]

    # coalescent times
    coal.t <- sort(n.t[(n.sample+1) : length(n.t)])
    n.c.event <- length(coal.t) #number of coalescent event

    if (any(diff(coal.t) == 0)) {
        stop('more than one coalescent event at a given time.')
    }

    # sampling times
    # correct for numerical issue in sampling time
    tmp.s.t <- round(n.t[1 : n.sample], digits=tol)
    for (i in 1:n.sample) {
        tmp.ind <- which(tmp.s.t == tmp.s.t[i])
        if (length(tmp.ind) > 1) {
            group.t <- min(n.t[tmp.ind]) # replace with min of grouped sampling time
            n.t[tmp.ind] <- group.t
            t.dat[tmp.ind, 4] <- group.t
        }
    }
    sample.t <- sort(unique(n.t[1 : n.sample]))
    n.s.event <- length(sample.t) # number of sampling events
    stopifnot(n.s.event == length(unique(tmp.s.t)))


    # combined time points for F-matrix
    u.t <- data.frame(t=c(coal.t, sample.t),
                      type=c(rep('c', n.c.event), rep('s', n.s.event)),
                      c.id=c(seq(n.c.event), rep(-9, n.s.event)),
                      s.id=c(rep(-9, n.c.event), seq(n.s.event)),
                      stringsAsFactors=FALSE)
    u.t <- u.t[order(u.t$t, decreasing=TRUE),]
    rownames(u.t) <- paste('u', 1:(n.c.event+n.s.event), sep='.')

    ## Construct F matrix
    # n.col = n.row = (# sampling event) + (# of coalescent event) - 1
    # F(i,j) = # of lineages that exist and do not coalesce in (u_j, u_{j-1}).

    f.dim <- n.s.event + n.c.event
    Fmat <- matrix(0, nrow=f.dim, ncol=f.dim)

    for (i in 2:f.dim) {
        for (j in 2:i) {
            u.start <- u.t$t[i]
            u.end <- u.t$t[j-1]
            Fmat[i,j] <- sum((t.dat$t.end >= u.end) & (t.dat$t.start <= u.start))
        }
    }

    return(list(Fmat=Fmat, u.info=u.t))
}


insert.event <- function(e.vec, t.vec, n.a.vec) {
    ## This function inserts fake sampling events after each coalescent events.
    #  The number of inserted fake s event can be zero. This function is a
    #  helper function to compure distance between two trees when two trees
    #  have the same number of taxa (and thus the same number of coalsecent events)
    #  but with different sampling events.
    #
    ## Input:
    #   e.vec: Event vector, coalescent event is coded with "c" and
    #          the sampling event is coded with "s".
    #   t.vec: time vector corresponding to e.vec
    #   n.a.vec: A vector of number of "fake" sampling events to be added
    #            to each intercoalescent interval (coded with "a").
    ## Output:
    #   ind.map: map of indices. original event vector (with "c" and "s")
    #            to new event vector with "a" inserted.
    #   fake.ind: a vector of indices of "a" in the new event vector.
    #   comb.event: new event vector with "a" inserted to original e.vec
    #               according to n.a.vec
    #   comb.t: new event vector with the time with "a" event interpolated
    #           between times of the nearest non-"a" events.

    coal.loc <- which(e.vec == 'c')
    samp.loc <- seq(length(e.vec))[-coal.loc]
    n.coal <- length(coal.loc)
    n.samp <- length(samp.loc)
    n.event <- length(e.vec)
    cum.n.add <- cumsum(n.a.vec)

    stopifnot(n.coal == length(n.a.vec))
    combF.dim <- n.event + sum(n.a.vec)

    ind.map <- matrix(NA, nrow=length(e.vec), ncol=2)
    ind.map[,1] <- 1:length(e.vec)

    ind.map[1, 2] <- 1
    ind.map[n.event, 2] <- ind.map[n.event, 1] + cum.n.add[n.coal]
    ind.map[coal.loc[-1], 2] <- coal.loc[-1] + cum.n.add[-n.coal]

    tmp.ind <- intersect(samp.loc, coal.loc-1) #s event before c
    ind.map[tmp.ind, 2] <- ind.map[tmp.ind+1, 2] - 1
    tmp.ind.2 <- sort(setdiff(samp.loc, coal.loc-1), decreasing=TRUE)

    for (j in tmp.ind.2[-1]) {
        ind.map[j, 2] <- ind.map[j+1, 2] - 1
    }

    comb.event <- rep(NA, combF.dim)
    comb.event[ind.map[coal.loc, 2]] <- 'c'
    comb.event[ind.map[samp.loc, 2]] <- 's'
    fake.ind <- which(is.na(comb.event))
    comb.event[fake.ind] <- 'a'

    comb.t <- rep(NA, combF.dim)
    comb.t[ind.map[,2]] <- t.vec
    coal.loc.comb <- ind.map[coal.loc, 2]

    for (i in which(n.a.vec > 0)) {
        t.2.ind <- coal.loc.comb[i]
        n.dummy <- n.a.vec[i]
        t.1.ind <- t.2.ind + n.dummy + 1

        t.2 <- comb.t[t.2.ind]
        t.1 <- comb.t[t.1.ind]
        comb.t[(t.2.ind+1):(t.1.ind-1)] <- seq(t.2, t.1,
                                               length.out=n.dummy+2)[-c(1, n.dummy+2)]
    }

    sort(intersect(which(comb.event == 'c'), which(n.a.vec > 0)))

    return(list(ind.map=ind.map, fake.ind=fake.ind,
                comb.event=comb.event, comb.t=comb.t))
}


create.weight.mat.hetero <- function(u.t) {
    # This function creates a matrix, W, for the branch length weight
    # to be multiplied (element-wise) to the F-matrix in distance metric
    # computation.
    # Input:
    #   u.t: vector of times for each event
    #        (in decreasing order with current sampling time being 0)
    # Output:
    #    For a tree with n taxa, W is a n x n matrix with entries:
    #   upper tri: all zeroes
    #   first col: all zeroes
    #   W_{ij}: u[j-1] - u[i] (2 <= i,j <= n)

    n.dim <- length(u.t)
    col.vec <- c(0, u.t[-n.dim])
    row.vec <- c(0, u.t[-1])

    w.mat <- matrix(rep(col.vec, each=n.dim), nrow=n.dim)
    w.mat <- w.mat - matrix(rep(row.vec, times=n.dim), nrow=n.dim)
    w.mat[upper.tri(w.mat)] <- 0
    w.mat[,1] <- 0

    return(w.mat)
}


#' Distance between two ranked tree shapes or ranked genealogies
#'
#' @param tr.1 An object of class \code{phylo}. Can be either isochronous or heterochronous.
#' @param tr.2 An object of class \code{phylo}. Can be either isochronous or heterochronous.
#' @param dist.method "l1" or "l2".
#' @param weighted A logical value; if \code{TRUE}, weighted distance is computed.
#'
#' @return Distance between the input trees \code{tr.1} and \code{tr.2}.
#'
#' @details The input trees, tr.1 and tr.2 must have the same number of taxa.
#' The number of sampling events, however, can differ between two trees.
#'
#' \code{dist.method="l1"} option computes Manhattan distance between
#' F-matrices (flattened as vectors) of tr.1 and tr.2.
#'
#' \code{dist.method="l2"} option computes Frobenius distance between
#' F-matrices (flattened as vectors) of tr.1 and tr.2.
#'
#' If \code{weighted=TRUE}, the F-matrix elements are weighted by
#' the corresponding time intervals.
#'
#' If \code{weighted=FALSE}, the F-matrix elements are not weighted by
#' the corresponding time intervals, i.e., distance is computed using
#' ranked tree shapes only.
#'
#' @examples
#' # Generate a sample tree
#' set.seed(1); tr.1 <- ape::rcoal(5)
#' set.seed(2); tr.2 <- ape::rcoal(5)
#' dist_pairwise(tr.1, tr.2, dist.method='l1', weighted=TRUE)
#'
#' @author Jaehee Kim, Julia Palacios
#'
#' @references Kim J, Rosenberg NA, Palacios JA, 2019.
#' \emph{A Metric Space of Ranked Tree Shapes and Ranked Genealogies}.
#'
dist_pairwise <- function(tr.1, tr.2, dist.method='l1', weighted=FALSE) {

    ## ======= check input format ======
    if (!(dist.method == 'l1' | dist.method == 'l2')) {
        stop('dist.method should be either "l1" or "l2"')
    }

    if (tr.1$Nnode != tr.2$Nnode) {
        stop('Two trees must have the same number of taxa.')
    }

    ## ======= convert tr.1 and tr.2 to tree data =======
    tr.dat.1 <- gen.tr.data(tr.1)
    tr.dat.2 <- gen.tr.data(tr.2)

    ## ======= Process tree.1 and tree.2 to merge =======
    tmp.info.1 <- tr.dat.1$u.info
    tmp.info.2 <- tr.dat.2$u.info
    tmp.fmat.1 <- tr.dat.1$Fmat
    tmp.fmat.2 <- tr.dat.2$Fmat
    n.coal <- max(tr.dat.1$u.info$c.id)
    stopifnot(n.coal == max(tr.dat.2$u.info$c.id))
    n.event.1 <- dim(tmp.info.1)[1]
    n.event.2 <- dim(tmp.info.2)[1]

    c.match.ind.1 <- match(seq(n.coal,1), tmp.info.1$c.id)
    c.match.ind.2 <- match(seq(n.coal,1), tmp.info.2$c.id)

    # number of sampling events intercoalescent intervals
    n.s.1 <- c(diff(c.match.ind.1) - 1, n.event.1 - c.match.ind.1[n.coal])
    n.s.2 <- c(diff(c.match.ind.2) - 1, n.event.2 - c.match.ind.2[n.coal])
    n.s.comb <- pmax(n.s.1, n.s.2)

    # number of "a"'s added to each intercoalescent event
    n.a.1 <- n.s.comb - n.s.1
    n.a.2 <- n.s.comb - n.s.2

    stopifnot((n.event.1 + sum(n.a.1)) == (n.event.2 + sum(n.a.2)))

    ## ============================
    ## Create Fmat starts from here
    ## ============================
    fmat.dim <- n.event.1 + sum(n.a.1)

    comb.Fmat.1 <- matrix(0, nrow=fmat.dim, ncol=fmat.dim)
    comb.Fmat.2 <- matrix(0, nrow=fmat.dim, ncol=fmat.dim)

    insert.info.1 <- insert.event(e.vec=tmp.info.1$type,
                                  t.vec=tmp.info.1$t,
                                  n.a.vec=n.a.1)
    insert.info.2 <- insert.event(e.vec=tmp.info.2$type,
                                  t.vec=tmp.info.2$t,
                                  n.a.vec=n.a.2)

    # === Construct Fmat for tree 1 ===
    a.rind.1 <- sort(insert.info.1$fake.ind, decreasing=TRUE)
    a.cind.1 <- insert.info.1$fake.ind + 1

    # Populate pre-existing values from the original fmat
    for (rind in dim(tmp.fmat.1)[1]:2) {
        for (cind in rind:2) {
            rind.new <- insert.info.1$ind.map[rind, 2]
            cind.new <- insert.info.1$ind.map[cind-1, 2] + 1
            comb.Fmat.1[rind.new, cind.new] <- tmp.fmat.1[rind, cind]
        }
    }
    # Fill out new rows and columns
    for (rind in a.rind.1) {
        comb.Fmat.1[rind, 2:rind] <- comb.Fmat.1[rind+1, 2:rind]
    }
    for (cind in a.cind.1) {
        comb.Fmat.1[cind:fmat.dim, cind] <- comb.Fmat.1[cind:fmat.dim, cind-1]
    }

    stopifnot(all(comb.Fmat.1[upper.tri(comb.Fmat.1)] == 0))

    # === Construct Fmat for tree 2 ===
    a.rind.2 <- sort(insert.info.2$fake.ind, decreasing=TRUE)
    a.cind.2 <- insert.info.2$fake.ind + 1

    # Populate pre-existing values from the original fmat
    for (rind in dim(tmp.fmat.2)[1]:2) {
        for (cind in rind:2) {
            rind.new <- insert.info.2$ind.map[rind, 2]
            cind.new <- insert.info.2$ind.map[cind-1, 2] + 1
            comb.Fmat.2[rind.new, cind.new] <- tmp.fmat.2[rind, cind]
        }
    }
    # Fill out new rows and columns
    for (rind in a.rind.2) {
        comb.Fmat.2[rind, 2:rind] <- comb.Fmat.2[rind+1, 2:rind]
    }
    for (cind in a.cind.2) {
        comb.Fmat.2[cind:fmat.dim, cind] <- comb.Fmat.2[cind:fmat.dim, cind-1]
    }

    stopifnot(all(comb.Fmat.2[upper.tri(comb.Fmat.2)] == 0))

    if (weighted) {
        # construct weight-matrix
        w.mat.1 <- create.weight.mat.hetero(insert.info.1$comb.t)
        w.mat.2 <- create.weight.mat.hetero(insert.info.2$comb.t)

        if (dist.method == 'l1') {
            # L1,1 norm
            dist <- sum(abs(comb.Fmat.1*w.mat.1 - comb.Fmat.2*w.mat.2))
        } else if (dist.method == 'l2') {
            # Frobenius norm
            dist <- sqrt(sum((comb.Fmat.1*w.mat.1 - comb.Fmat.2*w.mat.2)^2))
        } else {
            stop('unsupported dist.method')
        }
    } else {
        if (dist.method == 'l1') {
            # L1,1 norm
            dist <- sum(abs(comb.Fmat.1 - comb.Fmat.2))
        } else if (dist.method == 'l2') {
            # Frobenius norm
            dist <- sqrt(sum((comb.Fmat.1 - comb.Fmat.2)^2))
        } else {
            stop('unsupported dist.method')
        }
    }

    return(dist)
}

##Auxiliary##
consolidateF<-function(Fju){
    ##generates an F matrix consistent with paper notation
    newF<-matrix(0,nrow=nrow(Fju),ncol=nrow(Fju))
    for (j in 1:nrow(newF)){
        newF[nrow(Fju)-j+1,]<-rev(Fju[,j])
    }
    newF2<-matrix(0,nrow=Fju[1,1],ncol=Fju[1,1])
    newF2[2:Fju[1,1],2:Fju[1,1]]<-newF
    return(newF2)
}




