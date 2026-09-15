*! _dagy_mata.ado 0.5.0 2026-08-27
*! Thomas Grund
*! Low-level Mata graph engine for the `dagy` command suite.
*! Not meant to be called directly by users - see `help dagy`.
*! Run once per session (dagy.ado does this automatically) so that the
*! functions below stay resident in Mata for the rest of the session,
*! the same way a compiled .mlib would.

*! not a callable command - `run` directly by dagy.ado (once per session);
*! see the $DAGY_MATA_LOADED guard there. All that follows is Mata code.

mata:
mata set matastrict off

// ---------------------------------------------------------------------
// read a dagy's storage frames (nodes: node/latent; edges: n1/n2) into
// plain Mata objects: a node-name vector, an n x n 0/1 adjacency
// matrix (rows/cols in node-frame order) and a 0/1 latent indicator.
// ---------------------------------------------------------------------
void dagy_m_readfr(string scalar nfrm, string scalar efrm,
	string colvector nodes, real matrix A, real colvector latent)
{
	string scalar curf
	string colvector ef, et
	real scalar nn, ne, i
	transmorphic idxmap

	curf = st_framecurrent()

	st_framecurrent(nfrm)
	nodes  = st_sdata(., "node")
	latent = st_data(., "latent")

	st_framecurrent(efrm)
	ne = st_nobs()
	if (ne) {
		ef = st_sdata(., "n1")
		et = st_sdata(., "n2")
	}
	else {
		ef = J(0,1,"")
		et = J(0,1,"")
	}

	st_framecurrent(curf)

	nn = rows(nodes)
	A  = J(nn,nn,0)
	idxmap = asarray_create("string")
	for (i=1; i<=nn; i++) asarray(idxmap, nodes[i], i)
	for (i=1; i<=ne; i++) {
		A[asarray(idxmap,ef[i]), asarray(idxmap,et[i])] = 1
	}
}

// ---------------------------------------------------------------------
// does A (a 0/1 directed adjacency matrix) contain a cycle?
// Kahn's algorithm: repeatedly strip nodes with in-degree 0; a cycle
// exists iff some nodes are never stripped.
// ---------------------------------------------------------------------
real scalar dagy_m_hascycle(real matrix A)
{
	real scalar n, i, j, removed, progress
	real colvector indeg, gone

	n = rows(A)
	indeg = J(n,1,0)
	for (j=1; j<=n; j++) indeg[j] = colsum(A[.,j])
	gone = J(n,1,0)
	removed = 0
	progress = 1
	while (progress & removed < n) {
		progress = 0
		for (i=1; i<=n; i++) {
			if (gone[i]) continue
			if (indeg[i] == 0) {
				gone[i] = 1
				removed++
				progress = 1
				for (j=1; j<=n; j++) {
					if (!gone[j] & A[i,j]) indeg[j] = indeg[j] - 1
				}
			}
		}
	}
	return(removed < n)
}

// ---------------------------------------------------------------------
// 0/1 indicator vector (length = rows(nodes)) marking which nodes are
// named in the space-separated Stata namelist `list'.
// ---------------------------------------------------------------------
real colvector dagy_m_indicator(string colvector nodes, string scalar list)
{
	real scalar n, i
	string rowvector toks
	real colvector r

	n = rows(nodes)
	r = J(n,1,0)
	toks = tokens(list)
	for (i=1; i<=n; i++) {
		if (anyof(toks, nodes[i])) r[i] = 1
	}
	return(r)
}

// ---------------------------------------------------------------------
// classify every node's role relative to an (optional) exposure/
// outcome/adjustment set, for dagy draw's node coloring. xname/yname/
// adjlist may be "" (not specified); latent overrides everything else.
// ---------------------------------------------------------------------
string colvector dagy_m_roles(real matrix A, string colvector nodes,
	real colvector latent, string scalar xname, string scalar yname,
	string scalar adjlist)
{
	real scalar n, i
	real colvector X, Y, Adj, AncX, AncY, DescX
	string colvector role

	n = rows(nodes)
	X     = dagy_m_indicator(nodes, xname)
	Y     = dagy_m_indicator(nodes, yname)
	Adj   = dagy_m_indicator(nodes, adjlist)
	AncX  = dagy_m_anc(A, X)
	AncY  = dagy_m_anc(A, Y)
	DescX = dagy_m_desc(A, X)

	role = J(n,1,"other")
	for (i=1; i<=n; i++) {
		if (latent[i])            role[i] = "unobserved"
		else if (X[i])            role[i] = "exposure"
		else if (Y[i])            role[i] = "outcome"
		else if (Adj[i])          role[i] = "adjusted"
		else if (DescX[i] & AncY[i]) role[i] = "mediator"
		else if (AncX[i] & AncY[i])  role[i] = "ancestor of both"
		else if (AncX[i])         role[i] = "ancestor of exposure"
		else if (AncY[i])         role[i] = "ancestor of outcome"
		else                      role[i] = "other"
	}
	return(role)
}

// ---------------------------------------------------------------------
// index of a node name in a node-name vector; errors if not found
// ---------------------------------------------------------------------
real scalar dagy_m_idx(string colvector nodes, string scalar name)
{
	real scalar i, n
	n = rows(nodes)
	for (i=1; i<=n; i++) {
		if (nodes[i] == name) return(i)
	}
	errprintf("{err}%s is not a node of this DAG\n", name)
	exit(198)
}

// ---------------------------------------------------------------------
// ancestors-or-self of a 0/1 seed vector (follows edges backwards)
// ---------------------------------------------------------------------
real colvector dagy_m_anc(real matrix A, real colvector seed)
{
	real scalar n, i, j, changed
	real colvector r
	n = rows(A)
	r = seed
	changed = 1
	while (changed) {
		changed = 0
		for (i=1; i<=n; i++) {
			if (r[i]) continue
			for (j=1; j<=n; j++) {
				if (A[i,j] & r[j]) {
					r[i] = 1
					changed = 1
					break
				}
			}
		}
	}
	return(r)
}

// ---------------------------------------------------------------------
// descendants-or-self of a 0/1 seed vector (follows edges forwards)
// ---------------------------------------------------------------------
real colvector dagy_m_desc(real matrix A, real colvector seed)
{
	real scalar n, i, j, changed
	real colvector r
	n = rows(A)
	r = seed
	changed = 1
	while (changed) {
		changed = 0
		for (i=1; i<=n; i++) {
			if (!r[i]) continue
			for (j=1; j<=n; j++) {
				if (A[i,j] & !r[j]) {
					r[j] = 1
					changed = 1
				}
			}
		}
	}
	return(r)
}

// ---------------------------------------------------------------------
// moralize the subgraph induced by include==1: marry parents sharing a
// child, drop arrowheads. Returns a symmetric 0/1 matrix over all n
// nodes (rows/cols for excluded nodes are left at 0).
// ---------------------------------------------------------------------
real matrix dagy_m_moralize(real matrix A, real colvector include)
{
	real scalar n, i, j, k, p, q
	real matrix M
	real colvector parents
	n = rows(A)
	M = J(n,n,0)
	for (i=1; i<=n; i++) {
		if (!include[i]) continue
		for (j=1; j<=n; j++) {
			if (!include[j]) continue
			if (A[i,j]) {
				M[i,j] = 1
				M[j,i] = 1
			}
		}
	}
	for (k=1; k<=n; k++) {
		if (!include[k]) continue
		parents = J(0,1,.)
		for (i=1; i<=n; i++) {
			if (include[i] & A[i,k]) parents = parents \ i
		}
		for (p=1; p<=rows(parents); p++) {
			for (q=p+1; q<=rows(parents); q++) {
				M[parents[p],parents[q]] = 1
				M[parents[q],parents[p]] = 1
			}
		}
	}
	return(M)
}

// ---------------------------------------------------------------------
// read a dagy's stored layout frame (node/x/y) into plain Mata vectors -
// same spirit as dagy_m_readfr, for the dagy_<name>_xy frame written by
// _dagy_layout_compute.ado.
// ---------------------------------------------------------------------
void dagy_m_readxy(string scalar xyfrm, string colvector xynodes,
	real colvector xyx, real colvector xyy)
{
	string scalar curf
	curf = st_framecurrent()
	st_framecurrent(xyfrm)
	xynodes = st_sdata(., "node")
	xyx     = st_data(., "x")
	xyy     = st_data(., "y")
	st_framecurrent(curf)
}

// ---------------------------------------------------------------------
// A with outgoing edges removed from every node in the 0/1 indicator S
// ("cut from" S) - the standard graph-mutilation trick for testing
// backdoor-only association (used already, inline, in dagy_m_adjust; the
// front-door and instrumental-variable criteria need the same trick
// applied to sets other than just the exposure, hence a reusable
// function).
// ---------------------------------------------------------------------
real matrix dagy_m_cutfrom(real matrix A, real colvector S)
{
	real scalar n, i
	real matrix Ax
	n = rows(A)
	Ax = A
	for (i=1; i<=n; i++) {
		if (S[i]) Ax[i,.] = J(1,n,0)
	}
	return(Ax)
}

// ---------------------------------------------------------------------
// A with every node in the 0/1 indicator S deleted entirely (both its
// outgoing and incoming edges removed). Used by the front-door
// criterion's "M intercepts every causal path from X to Y" test: delete
// M and check whether Y is still reachable from X.
// ---------------------------------------------------------------------
real matrix dagy_m_delnodes(real matrix A, real colvector S)
{
	real scalar n, i
	real matrix Ax
	n = rows(A)
	Ax = A
	for (i=1; i<=n; i++) {
		if (S[i]) {
			Ax[i,.] = J(1,n,0)
			Ax[.,i] = J(n,1,0)
		}
	}
	return(Ax)
}

// ---------------------------------------------------------------------
// d-separation test: are X and Y d-separated given Z?
// X, Y, Z are 0/1 indicator column vectors of length n (disjoint).
// Returns 1 if d-separated (independent), 0 if not (dependent).
// Implements the standard moralize-the-ancestral-graph algorithm.
// ---------------------------------------------------------------------
real scalar dagy_m_dsep(real matrix A, real colvector X, real colvector Y, real colvector Z)
{
	real scalar n, i, j, changed
	real colvector anc, reach
	real matrix M
	n = rows(A)
	anc = dagy_m_anc(A, (X :| Y :| Z))
	M = dagy_m_moralize(A, anc)
	reach = X
	changed = 1
	while (changed) {
		changed = 0
		for (i=1; i<=n; i++) {
			if (!reach[i] | Z[i]) continue
			for (j=1; j<=n; j++) {
				if (Z[j] | !anc[j] | reach[j]) continue
				if (M[i,j]) {
					reach[j] = 1
					changed = 1
				}
			}
		}
	}
	if (sum(reach :* Y) > 0) return(0)
	return(1)
}

// ---------------------------------------------------------------------
// enumerate simple paths (in the skeleton) between x and y, classified
// as causal (directed x->...->y), backdoor (starts x<-...) or other
// (starts x->... but is not a directed path to y, i.e. runs through a
// collider). Writes fully-formatted strings straight away so the ado
// layer only has to group and print them.
// ---------------------------------------------------------------------
void dagy_m_dfs(real matrix A, real matrix S, string colvector nodes,
	real scalar cur, real scalar target, real colvector visited,
	real colvector pathidx, real scalar depth, string colvector results,
	real colvector kinds, real scalar maxpaths, real colvector count)
{
	real scalar n, j, k, a, b, allfwd, firstin
	string scalar s

	if (count[1] >= maxpaths) return

	if (cur == target) {
		s = nodes[pathidx[1]]
		allfwd = 1
		firstin = 0
		for (k=2; k<=depth; k++) {
			a = pathidx[k-1]
			b = pathidx[k]
			if (A[a,b]==1 & A[b,a]==0) {
				s = s + " -> " + nodes[b]
			}
			else if (A[b,a]==1 & A[a,b]==0) {
				s = s + " <- " + nodes[b]
				allfwd = 0
				if (k==2) firstin = 1
			}
			else {
				s = s + " -- " + nodes[b]
				allfwd = 0
			}
		}
		results = results \ s
		if (allfwd) kinds = kinds \ 1
		else if (firstin) kinds = kinds \ 2
		else kinds = kinds \ 3
		count[1] = count[1] + 1
		return
	}

	n = rows(A)
	for (j=1; j<=n; j++) {
		if (count[1] >= maxpaths) return
		if (visited[j]) continue
		if (S[cur,j]==0) continue
		visited[j] = 1
		pathidx[depth+1] = j
		dagy_m_dfs(A, S, nodes, j, target, visited, pathidx, depth+1, results, kinds, maxpaths, count)
		visited[j] = 0
	}
}

void dagy_m_paths(real matrix A, string colvector nodes, string scalar xname,
	string scalar yname, real scalar maxpaths, string colvector results,
	real colvector kinds, real scalar truncated)
{
	real scalar n, xi, yi
	real matrix S
	real colvector visited, pathidx, count

	n  = rows(A)
	S  = (A :| A')
	xi = dagy_m_idx(nodes, xname)
	yi = dagy_m_idx(nodes, yname)

	results = J(0,1,"")
	kinds   = J(0,1,.)
	visited = J(n,1,0)
	pathidx = J(n,1,.)
	visited[xi] = 1
	pathidx[1]  = xi
	count = J(1,1,0)

	dagy_m_dfs(A, S, nodes, xi, yi, visited, pathidx, 1, results, kinds, maxpaths, count)
	truncated = (count[1] >= maxpaths)
}

// ---------------------------------------------------------------------
// back-door adjustment sets between x and y.
// forced: 0/1 vector, variables the caller insists on including in
//         every candidate set (dagy adjust ..., given()).
// maxcand: refuse (toolarge=1) rather than enumerate 2^k sets when the
//          number of *free* candidates k exceeds this.
// ---------------------------------------------------------------------
void dagy_m_adjust(real matrix A, string colvector nodes, string scalar xname,
	string scalar yname, real colvector forced, real colvector exclude,
	real scalar maxcand, string colvector suffsets, string colvector minsets,
	real scalar toolarge)
{
	real scalar n, xi, yi, i, k, ncand, m, nmask, bit, sub, val, hval
	real colvector X, Y, descX, cand, candidx, allsuff, g, h, minimal
	real matrix Ax
	string colvector allsets
	string scalar znames

	n  = rows(A)
	xi = dagy_m_idx(nodes, xname)
	yi = dagy_m_idx(nodes, yname)
	X  = J(n,1,0); X[xi] = 1
	Y  = J(n,1,0); Y[yi] = 1

	descX = dagy_m_desc(A, X)

	cand = J(n,1,0)
	for (i=1; i<=n; i++) {
		if (X[i] | Y[i] | descX[i] | forced[i] | exclude[i]) continue
		cand[i] = 1
	}
	ncand = sum(cand)

	if (ncand > maxcand) {
		toolarge = 1
		suffsets = J(0,1,"")
		minsets  = J(0,1,"")
		return
	}
	toolarge = 0
	candidx = select((1::n), cand)

	Ax = A
	for (i=1; i<=n; i++) Ax[xi,i] = 0

	nmask = 2^ncand
	allsets = J(nmask,1,"")
	allsuff = J(nmask,1,0)
	g = J(nmask,1,0)
	h = J(nmask,1,0)

	for (m=0; m<=nmask-1; m++) {
		real colvector Z
		Z = forced
		znames = ""
		for (k=1; k<=ncand; k++) {
			bit = 2^(k-1)
			if (mod(floor(m/bit),2)) {
				Z[candidx[k]] = 1
				znames = znames + (znames=="" ? "" : " ") + nodes[candidx[k]]
			}
		}
		allsets[m+1] = znames
		allsuff[m+1] = dagy_m_dsep(Ax, X, Y, Z)

		val  = allsuff[m+1]
		hval = 0
		for (k=1; k<=ncand; k++) {
			bit = 2^(k-1)
			if (mod(floor(m/bit),2)) {
				sub = m - bit
				if (g[sub+1]) {
					val  = 1
					hval = 1
				}
			}
		}
		g[m+1] = val
		h[m+1] = hval
	}

	suffsets = select(allsets, allsuff)
	minimal  = allsuff :& (1 :- h)
	minsets  = select(allsets, minimal)
}

// ---------------------------------------------------------------------
// front-door adjustment sets between x and y: sets of mediators M such
// that (1) M intercepts every directed path from x to y, (2) there is
// no unblocked back-door path from x to M, and (3) x blocks every
// back-door path from M to y. Candidates are restricted to nodes that
// lie on some directed path from x to y (descendants of x that are also
// ancestors of y); forced/exclude/maxcand work exactly as in
// dagy_m_adjust (forced nodes are always in M, excluded - normally the
// latent nodes, since M must be observed - are never candidates).
// ---------------------------------------------------------------------
void dagy_m_frontdoor(real matrix A, string colvector nodes, string scalar xname,
	string scalar yname, real colvector forced, real colvector exclude,
	real scalar maxcand, string colvector suffsets, string colvector minsets,
	real scalar toolarge)
{
	real scalar n, xi, yi, i, k, ncand, m, nmask, bit, sub, val, hval
	real colvector X, Y, descX, ancY, cand, candidx, allsuff, g, h, minimal
	real matrix Ax
	string colvector allsets
	string scalar znames

	n  = rows(A)
	xi = dagy_m_idx(nodes, xname)
	yi = dagy_m_idx(nodes, yname)
	X  = J(n,1,0); X[xi] = 1
	Y  = J(n,1,0); Y[yi] = 1

	descX = dagy_m_desc(A, X)
	ancY  = dagy_m_anc(A, Y)

	cand = J(n,1,0)
	for (i=1; i<=n; i++) {
		if (X[i] | Y[i] | forced[i] | exclude[i]) continue
		if (descX[i] & ancY[i]) cand[i] = 1
	}
	ncand = sum(cand)

	if (ncand > maxcand) {
		toolarge = 1
		suffsets = J(0,1,"")
		minsets  = J(0,1,"")
		return
	}
	toolarge = 0
	candidx = select((1::n), cand)

	nmask = 2^ncand
	allsets = J(nmask,1,"")
	allsuff = J(nmask,1,0)
	g = J(nmask,1,0)
	h = J(nmask,1,0)

	for (m=0; m<=nmask-1; m++) {
		real colvector M
		real scalar ok1, ok2, ok3
		real matrix Adel, AxX, AxM

		M = forced
		znames = ""
		for (k=1; k<=ncand; k++) {
			bit = 2^(k-1)
			if (mod(floor(m/bit),2)) {
				M[candidx[k]] = 1
				znames = znames + (znames=="" ? "" : " ") + nodes[candidx[k]]
			}
		}
		allsets[m+1] = znames

		if (sum(M) == 0) {
			allsuff[m+1] = 0
		}
		else {
			real colvector descXdel
			Adel = dagy_m_delnodes(A, M)
			descXdel = dagy_m_desc(Adel, X)
			ok1  = !descXdel[yi]

			AxX = dagy_m_cutfrom(A, X)
			ok2 = dagy_m_dsep(AxX, X, M, J(n,1,0))

			AxM = dagy_m_cutfrom(A, M)
			ok3 = dagy_m_dsep(AxM, M, Y, X)

			allsuff[m+1] = (ok1 & ok2 & ok3)
		}

		val  = allsuff[m+1]
		hval = 0
		for (k=1; k<=ncand; k++) {
			bit = 2^(k-1)
			if (mod(floor(m/bit),2)) {
				sub = m - bit
				if (g[sub+1]) {
					val  = 1
					hval = 1
				}
			}
		}
		g[m+1] = val
		h[m+1] = hval
	}

	suffsets = select(allsets, allsuff)
	minimal  = allsuff :& (1 :- h)
	minsets  = select(allsets, minimal)
}

// ---------------------------------------------------------------------
// graphical instrumental-variable criterion for a single candidate z:
// relevant   = z is not d-separated from x given `given' (z is
//              associated with the exposure);
// exclrestr  = z is d-separated from y given `given', in the graph with
//              x's outgoing edges cut (z's only association with y runs
//              through x - the exclusion restriction plus "no direct
//              confounding of z and y" combined, as in the standard
//              mutilated-graph IV test, e.g. dagitty's
//              instrumentalVariables()).
// Returns a 1x2 vector (relevant, exclrestr); both must be 1 for z to be
// a valid instrument.
// ---------------------------------------------------------------------
real rowvector dagy_m_ivcheck(real matrix A, real colvector X, real colvector Y,
	real colvector Zc, real colvector given)
{
	real scalar relevant, exclrestr
	real matrix AxX

	relevant  = !dagy_m_dsep(A, Zc, X, given)
	AxX       = dagy_m_cutfrom(A, X)
	exclrestr = dagy_m_dsep(AxX, Zc, Y, given)
	return((relevant, exclrestr))
}

// ---------------------------------------------------------------------
// search every eligible node as an instrument candidate for x -> y:
// candidates exclude x, y, descendants of x (an instrument cannot be
// caused by the exposure), and `exclude' (normally the latent nodes,
// since an instrument must be observed). Returns parallel vectors:
// candidates (names), relevant, exclrestr (both 0/1 per candidate, so
// the ado layer can report *why* a candidate fails, not just that it
// does).
// ---------------------------------------------------------------------
void dagy_m_ivsearch(real matrix A, string colvector nodes, string scalar xname,
	string scalar yname, real colvector exclude, real colvector given,
	string colvector candidates, real colvector relevant, real colvector exclrestr)
{
	real scalar n, xi, yi, i
	real colvector X, Y, descX, Zc
	real rowvector res

	n  = rows(A)
	xi = dagy_m_idx(nodes, xname)
	yi = dagy_m_idx(nodes, yname)
	X  = J(n,1,0); X[xi] = 1
	Y  = J(n,1,0); Y[yi] = 1
	descX = dagy_m_desc(A, X)

	candidates = J(0,1,"")
	relevant   = J(0,1,.)
	exclrestr  = J(0,1,.)
	for (i=1; i<=n; i++) {
		if (X[i] | Y[i] | descX[i] | exclude[i] | given[i]) continue
		Zc = J(n,1,0); Zc[i] = 1
		res = dagy_m_ivcheck(A, X, Y, Zc, given)
		candidates = candidates \ nodes[i]
		relevant   = relevant   \ res[1]
		exclrestr  = exclrestr  \ res[2]
	}
}

// ---------------------------------------------------------------------
// testable implications entailed by the DAG: the local Markov
// generating set. For every node v with a non-empty "vanishing set"
// (its non-descendants that are not already its parents), report
//     v _||_ {vanishing set} | {parents}
// This is the standard minimal set of conditional-independence
// statements that, via the semigraphoid axioms, entails every other
// d-separation implied by the graph (it is not the same as dagitty's
// pairwise-minimal-separator basis, which is a larger computation).
// testableflag[i] is 0 if v, or any node in its vanishing/parent set,
// is latent (marked so callers can flag statements that are not
// directly checkable against observed data).
// ---------------------------------------------------------------------
void dagy_m_testable(real matrix A, string colvector nodes, real colvector latent,
	string colvector stmts, real colvector testableflag,
	string colvector varnode, string colvector vanishset, string colvector parentset)
{
	real scalar n, v, i, involveslatent
	real colvector seed, desc, nondesc, pa, vanish
	string scalar vn, pn

	n = rows(A)
	stmts = J(0,1,"")
	testableflag = J(0,1,.)
	varnode = J(0,1,"")
	vanishset = J(0,1,"")
	parentset = J(0,1,"")

	for (v=1; v<=n; v++) {
		seed = J(n,1,0); seed[v] = 1
		desc = dagy_m_desc(A, seed)
		nondesc = 1 :- desc
		pa = A[.,v]
		vanish = nondesc :& (1 :- pa)

		if (sum(vanish) == 0) continue

		vn = ""
		for (i=1; i<=n; i++) {
			if (vanish[i]) vn = vn + (vn=="" ? "" : " ") + nodes[i]
		}
		pn = ""
		for (i=1; i<=n; i++) {
			if (pa[i]) pn = pn + (pn=="" ? "" : " ") + nodes[i]
		}

		involveslatent = latent[v]
		for (i=1; i<=n; i++) {
			if ((vanish[i] | pa[i]) & latent[i]) involveslatent = 1
		}

		if (pn == "") {
			stmts = stmts \ (nodes[v] + " _||_ {" + vn + "}")
		}
		else {
			stmts = stmts \ (nodes[v] + " _||_ {" + vn + "} | {" + pn + "}")
		}
		testableflag = testableflag \ (!involveslatent)
		varnode   = varnode   \ nodes[v]
		vanishset = vanishset \ vn
		parentset = parentset \ pn
	}
}

// ---------------------------------------------------------------------
// layered (Sugiyama-style) layout: (1) rank every node by longest path
// from a source (Kahn's-algorithm removal order, propagating the max
// rank along each edge rather than just marking removal - well-defined
// because dagy define already refuses cyclic graphs); (1b) a named
// outcome with no outgoing edges is pinned to the final rank (safe: it
// has no children to stay left of, so this cannot violate any edge's
// rank[parent] < rank[child]), so a lone terminal outcome always lands
// on the right of the picture; (2) edges spanning more than one rank are
// routed through a chain of dummy nodes at the intermediate ranks (the
// standard full-Sugiyama device) so such "skip" edges are represented in
// the ranks they pass through, not invisible to them; (3) within each
// rank (real nodes and dummy pass-through points together), reorder by a
// barycenter heuristic over a few down/up sweeps to reduce (not
// guarantee-minimize) edge crossings against the adjacent,
// already-ordered rank; (4) turn (rank, position-within-rank) into
// (x,y), centering each rank so it's symmetric around the main axis (a
// real node sharing a rank with a dummy pass-through point is offset
// away from it rather than sitting on top of it - dummy nodes are then
// dropped, since they have no coordinate of their own to report); the
// named outcome, if any, is additionally forced to the exact centerline
// of its rank. orient("horizontal") (default) reads rank->x (causal flow
// left-to-right); orient("vertical") reads rank->-y (top-to-bottom).
// ---------------------------------------------------------------------
void dagy_m_layout(real matrix A, string colvector nodes, string scalar orient,
	string scalar outcomename, real colvector x, real colvector y)
{
	real scalar n, i, j, r, maxrank, removed, progress, sweepnum, cnt, k
	real colvector indeg, rank, gone, pos, idx
	real scalar rankspacing, posspacing
	real colvector bary, keysecondary, ord
	real scalar ii, jj, sump, cntn
	real scalar oi, outdeg, ntot, nextra, span, s, prevnode, nextidx
	real colvector rankE
	real matrix AE
	real scalar realcnt, realk, spanr, kk, xa, ya, xb, yb, xk, yk, t, ylinev, nudgesign

	n = rows(A)
	indeg = J(n,1,0)
	for (j=1; j<=n; j++) indeg[j] = colsum(A[.,j])
	rank = J(n,1,0)
	gone = J(n,1,0)
	removed = 0
	progress = 1
	while (progress & removed < n) {
		progress = 0
		for (i=1; i<=n; i++) {
			if (gone[i]) continue
			if (indeg[i] == 0) {
				gone[i] = 1
				removed++
				progress = 1
				for (j=1; j<=n; j++) {
					if (gone[j] | !A[i,j]) continue
					if (rank[i]+1 > rank[j]) rank[j] = rank[i]+1
					indeg[j] = indeg[j] - 1
				}
			}
		}
	}
	maxrank = max(rank)

	oi = 0
	if (outcomename != "") {
		for (i=1; i<=n; i++) if (nodes[i]==outcomename) oi = i
		if (oi) {
			outdeg = sum(A[oi,.])
			if (outdeg==0) rank[oi] = maxrank
		}
	}

	// expand the graph with a chain of dummy nodes for every edge that
	// spans more than one rank: without this, the crossing-reduction
	// sweeps below (which only look at immediate neighbouring ranks) are
	// completely blind to such "skip" edges, and a rank they pass through
	// can end up positioned so the skip edge cuts across an unrelated
	// edge - confirmed as a real defect this way (an "age -> education"
	// edge crossing an unrelated "ability -> earnings" skip edge, because
	// the skip edge played no part at all in deciding where "education"
	// or "earnings" sat within their ranks).
	nextra = 0
	for (i=1; i<=n; i++) {
		for (j=1; j<=n; j++) {
			if (A[i,j] & rank[j]-rank[i] > 1) nextra = nextra + (rank[j]-rank[i]-1)
		}
	}
	ntot = n + nextra
	rankE = J(ntot,1,0)
	for (i=1; i<=n; i++) rankE[i] = rank[i]
	AE = J(ntot,ntot,0)
	nextidx = n
	for (i=1; i<=n; i++) {
		for (j=1; j<=n; j++) {
			if (!A[i,j]) continue
			span = rank[j] - rank[i]
			if (span==1) {
				AE[i,j] = 1
				continue
			}
			prevnode = i
			for (s=1; s<=span-1; s++) {
				nextidx++
				rankE[nextidx] = rank[i] + s
				AE[prevnode,nextidx] = 1
				prevnode = nextidx
			}
			AE[prevnode,j] = 1
		}
	}

	// initial within-rank order: original node index (dummy nodes sort
	// after all real nodes, harmlessly - the barycenter sweeps below
	// reorder everything anyway)
	pos = J(ntot,1,0)
	for (r=0; r<=maxrank; r++) {
		idx = J(0,1,.)
		for (i=1; i<=ntot; i++) if (rankE[i]==r) idx = idx \ i
		cnt = rows(idx)
		for (k=1; k<=cnt; k++) pos[idx[k]] = k-1
	}

	// barycenter sweeps: down (parents), up (children), twice each
	for (sweepnum=1; sweepnum<=4; sweepnum++) {
		if (mod(sweepnum,2)==1) {
			for (r=1; r<=maxrank; r++) {
				idx = J(0,1,.)
				for (i=1; i<=ntot; i++) if (rankE[i]==r) idx = idx \ i
				cnt = rows(idx)
				if (cnt==0) continue
				bary = J(cnt,1,.)
				for (k=1; k<=cnt; k++) {
					ii = idx[k]
					sump = 0
					cntn = 0
					for (jj=1; jj<=ntot; jj++) {
						if (AE[jj,ii] & rankE[jj]==r-1) {
							sump = sump + pos[jj]
							cntn++
						}
					}
					bary[k] = (cntn>0 ? sump/cntn : pos[ii])
				}
				keysecondary = J(cnt,1,.)
				for (k=1; k<=cnt; k++) keysecondary[k] = pos[idx[k]]
				ord = order((bary,keysecondary), (1,2))
				for (k=1; k<=cnt; k++) pos[idx[ord[k]]] = k-1
			}
		}
		else {
			for (r=maxrank-1; r>=0; r--) {
				idx = J(0,1,.)
				for (i=1; i<=ntot; i++) if (rankE[i]==r) idx = idx \ i
				cnt = rows(idx)
				if (cnt==0) continue
				bary = J(cnt,1,.)
				for (k=1; k<=cnt; k++) {
					ii = idx[k]
					sump = 0
					cntn = 0
					for (jj=1; jj<=ntot; jj++) {
						if (AE[ii,jj] & rankE[jj]==r+1) {
							sump = sump + pos[jj]
							cntn++
						}
					}
					bary[k] = (cntn>0 ? sump/cntn : pos[ii])
				}
				keysecondary = J(cnt,1,.)
				for (k=1; k<=cnt; k++) keysecondary[k] = pos[idx[k]]
				ord = order((bary,keysecondary), (1,2))
				for (k=1; k<=cnt; k++) pos[idx[ord[k]]] = k-1
			}
		}
	}

	// coordinates: center each rank around 0 using only the REAL nodes'
	// relative order - dummy pass-through points inform that order (via
	// the sweeps above, e.g. deciding which of two same-rank real nodes
	// sorts top or bottom) but do not themselves consume spacing or push
	// a real node off its natural symmetric position. Forcing every real
	// node sharing a rank with a dummy off-center (an earlier version of
	// this layout) was confirmed as overkill this way: a mediator with
	// two rank-0 parents no longer sat exactly halfway between them, even
	// though nothing in the picture needed it displaced. The named
	// outcome (see above) is forced to the exact centerline of its rank
	// regardless of what else shares it.
	rankspacing = 20
	posspacing  = 15
	x = J(n,1,.)
	y = J(n,1,.)
	for (r=0; r<=maxrank; r++) {
		real scalar centered
		idx = J(0,1,.)
		for (i=1; i<=ntot; i++) if (rankE[i]==r) idx = idx \ i
		cnt = rows(idx)
		realcnt = 0
		for (k=1; k<=cnt; k++) if (idx[k]<=n) realcnt++
		realk = 0
		for (k=1; k<=cnt; k++) {
			if (idx[k] > n) continue
			realk++
			centered = (realk-1) - (realcnt-1)/2
			if (idx[k]==oi) centered = 0
			if (orient=="vertical") {
				x[idx[k]] = centered * posspacing
				y[idx[k]] = -r * rankspacing
			}
			else {
				x[idx[k]] = r * rankspacing
				y[idx[k]] = centered * posspacing
			}
		}
	}

	// a real node positioned as above can still, in principle, land
	// almost exactly on a skip edge's own straight line (rendered
	// directly from its two real endpoints, regardless of dummies) - the
	// degenerate case being a run of single-real-node ranks with nothing
	// else to disambiguate them, which would otherwise be perfectly
	// collinear with a skip edge spanning the whole run and vanish
	// underneath it. Checked directly against each skip edge's rendered
	// line (not against the dummy's own position, so a real node is only
	// disturbed when there is a genuine visual risk) and nudged off it by
	// a small, fixed amount; the named outcome is never nudged, since its
	// centering is a stronger guarantee than crossing/overlap avoidance.
	for (i=1; i<=n; i++) {
		for (j=1; j<=n; j++) {
			if (!A[i,j]) continue
			spanr = rank[j] - rank[i]
			if (spanr <= 1) continue
			xa = x[i]; ya = y[i]
			xb = x[j]; yb = y[j]
			for (kk=1; kk<=n; kk++) {
				if (kk==oi) continue
				if (rank[kk] <= rank[i] | rank[kk] >= rank[j]) continue
				xk = x[kk]; yk = y[kk]
				if (orient=="vertical") {
					if (yb==ya) continue
					t = (yk-ya)/(yb-ya)
					ylinev = xa + t*(xb-xa)
					if (abs(x[kk]-ylinev) < posspacing*0.15) {
						nudgesign = (ylinev >= x[kk] ? -1 : 1)
						x[kk] = x[kk] + nudgesign*posspacing*0.35
					}
				}
				else {
					if (xb==xa) continue
					t = (xk-xa)/(xb-xa)
					ylinev = ya + t*(yb-ya)
					if (abs(y[kk]-ylinev) < posspacing*0.15) {
						nudgesign = (ylinev >= y[kk] ? -1 : 1)
						y[kk] = y[kk] + nudgesign*posspacing*0.35
					}
				}
			}
		}
	}
}

// ---------------------------------------------------------------------
// a valid topological order of the nodes (Kahn's-algorithm removal
// order - the same style as dagy_m_hascycle/dagy_m_layout, just recording
// the sequence rather than a boolean or a rank). Used by
// dagy_m_toporder's caller (dagy simulate) to generate each node's structural-equation
// value only after all of its parents already have theirs.
// ---------------------------------------------------------------------
real colvector dagy_m_toporder(real matrix A)
{
	real scalar n, i, j, removed, progress
	real colvector indeg, gone, order

	n = rows(A)
	indeg = J(n,1,0)
	for (j=1; j<=n; j++) indeg[j] = colsum(A[.,j])
	gone = J(n,1,0)
	order = J(0,1,.)
	removed = 0
	progress = 1
	while (progress & removed < n) {
		progress = 0
		for (i=1; i<=n; i++) {
			if (gone[i]) continue
			if (indeg[i] == 0) {
				gone[i] = 1
				removed++
				progress = 1
				order = order \ i
				for (j=1; j<=n; j++) {
					if (!gone[j] & A[i,j]) indeg[j] = indeg[j] - 1
				}
			}
		}
	}
	return(order)
}

// ---------------------------------------------------------------------
// linear structural-equation expression for node k: "b1*parent1 +
// b2*parent2 + ..." from a coefficient matrix (0 where there is no
// edge), or "" if k has no parents. Used by dagy simulate to build each
// node's `gen' expression in topological order.
// ---------------------------------------------------------------------
string scalar dagy_m_simexpr(real matrix coef, string colvector nodes, real scalar k)
{
	real scalar n, i
	string scalar expr

	n = rows(coef)
	expr = ""
	for (i=1; i<=n; i++) {
		if (coef[i,k] == 0) continue
		if (expr != "") expr = expr + " + "
		expr = expr + strofreal(coef[i,k]) + "*" + nodes[i]
	}
	return(expr)
}

// ---------------------------------------------------------------------
// A with a new latent node U appended (index n+1), with edges U->ai and
// U->bi. Used by dagy sensitivity to test whether a hypothetical
// unmeasured confounder between two named nodes would break a given
// back-door adjustment set's sufficiency.
// ---------------------------------------------------------------------
real matrix dagy_m_augment2(real matrix A, real scalar ai, real scalar bi)
{
	real scalar n, i, j
	real matrix Aaug

	n = rows(A)
	Aaug = J(n+1,n+1,0)
	for (i=1; i<=n; i++) {
		for (j=1; j<=n; j++) {
			Aaug[i,j] = A[i,j]
		}
	}
	Aaug[n+1,ai] = 1
	Aaug[n+1,bi] = 1
	return(Aaug)
}

// ---------------------------------------------------------------------
// robustness check for dagy sensitivity: augment A with a latent U->ai,
// U->bi, and test whether X and Y remain d-separated given Z in the
// exposure-mutilated augmented graph - i.e. whether a hypothetical
// unmeasured confounder between nodes ai and bi would break Z's
// sufficiency as a back-door adjustment set for X on Y.
// ---------------------------------------------------------------------
real scalar dagy_m_sensitivity_check(real matrix A, real colvector X,
	real colvector Y, real colvector Z, real scalar ai, real scalar bi)
{
	real matrix Aaug, AxXaug
	real colvector Xaug, Yaug, Zaug

	Aaug = dagy_m_augment2(A, ai, bi)
	Xaug = X \ 0
	Yaug = Y \ 0
	Zaug = Z \ 0
	AxXaug = dagy_m_cutfrom(Aaug, Xaug)
	return(dagy_m_dsep(AxXaug, Xaug, Yaug, Zaug))
}

// ---------------------------------------------------------------------
// the DAG's Markov-equivalence class (CPDAG): which edges are compelled
// to a specific direction by the independence structure alone, and
// which could go either way. (1) skeleton = A treated as undirected;
// (2) every unshielded collider a->c<-b (parents of c that are NOT
// themselves adjacent) compels those two edges' direction; (3) Meek's
// rules R1-R2 propagate further forced orientations to a fixpoint:
//   R1: a->b directed, b-c undirected, a,c not adjacent => b->c
//       (else a->b<-c would be a new, spurious unshielded collider)
//   R2: a->b->c directed, a-c undirected => a->c
//       (else c->a would close a directed cycle)
// R3/R4 (rarer 4-node patterns) are not implemented - the result is
// correct but occasionally more conservative than a complete
// implementation (an edge a complete version would also orient may be
// left undirected here). `background' (n x n, 0/1) optionally seeds
// caller-asserted directed edges (background knowledge, mirroring
// dagitty's orientPDAG) before v-structure detection runs, so Meek's
// rules propagate from a strictly larger starting set than
// v-structures alone would give; pass J(n,n,0) for the plain case.
// ---------------------------------------------------------------------
void dagy_m_cpdag(real matrix A, string colvector nodes,
	real matrix background, string colvector directed, string colvector undirected)
{
	real scalar n, a, b, c, changed
	real matrix S, Dir, Und

	n = rows(A)
	S = (A :| A')

	Dir = J(n,n,0)
	Und = S

	for (a=1; a<=n; a++) {
		for (b=1; b<=n; b++) {
			if (!background[a,b]) continue
			Dir[a,b] = 1
			Und[a,b] = 0; Und[b,a] = 0
		}
	}

	for (c=1; c<=n; c++) {
		for (a=1; a<=n; a++) {
			if (!A[a,c]) continue
			for (b=a+1; b<=n; b++) {
				if (!A[b,c]) continue
				if (S[a,b]) continue
				Dir[a,c] = 1
				Und[a,c] = 0; Und[c,a] = 0
				Dir[b,c] = 1
				Und[b,c] = 0; Und[c,b] = 0
			}
		}
	}

	changed = 1
	while (changed) {
		changed = 0
		for (a=1; a<=n; a++) {
			for (b=1; b<=n; b++) {
				if (!Dir[a,b]) continue
				for (c=1; c<=n; c++) {
					if (c==a) continue
					if (!Und[b,c]) continue
					if (S[a,c]) continue
					Dir[b,c] = 1
					Und[b,c] = 0; Und[c,b] = 0
					changed = 1
				}
			}
		}
		for (a=1; a<=n; a++) {
			for (b=1; b<=n; b++) {
				if (!Dir[a,b]) continue
				for (c=1; c<=n; c++) {
					if (!Dir[b,c]) continue
					if (c==a) continue
					if (!Und[a,c]) continue
					Dir[a,c] = 1
					Und[a,c] = 0; Und[c,a] = 0
					changed = 1
				}
			}
		}
	}

	directed = J(0,1,"")
	for (a=1; a<=n; a++) {
		for (b=1; b<=n; b++) {
			if (Dir[a,b]) directed = directed \ (nodes[a] + " -> " + nodes[b])
		}
	}
	undirected = J(0,1,"")
	for (a=1; a<=n; a++) {
		for (b=a+1; b<=n; b++) {
			if (Und[a,b]) undirected = undirected \ (nodes[a] + " -- " + nodes[b])
		}
	}
}

// ---------------------------------------------------------------------
// the optimal (asymptotic-variance-minimizing) valid back-door
// adjustment set, DAG-only case of Perkovic et al. / Henckel-Perkovic-
// Maathuis: cn(X,Y) = nodes on a proper causal path from X to Y
// (descendants of X that are also ancestors of Y, excluding X itself);
// O = pa(cn u {Y}) \ (cn u {Y} u {X}). Among all valid back-door sets,
// this is the one that minimizes estimator variance - not just the
// smallest by cardinality. feasible=0 if O contains a latent node (the
// optimal set is well-defined graphically but can't actually be used).
// ---------------------------------------------------------------------
void dagy_m_optadjust(real matrix A, string colvector nodes, string scalar xname,
	string scalar yname, real colvector latent, string scalar optset, real scalar feasible)
{
	real scalar n, xi, yi, i, j
	real colvector X, Y, descX, ancY, cn, paunion, O

	n = rows(A)
	xi = dagy_m_idx(nodes, xname)
	yi = dagy_m_idx(nodes, yname)
	X = J(n,1,0); X[xi] = 1
	Y = J(n,1,0); Y[yi] = 1

	descX = dagy_m_desc(A, X)
	ancY  = dagy_m_anc(A, Y)

	cn = J(n,1,0)
	for (i=1; i<=n; i++) {
		if (i==xi) continue
		if (descX[i] & ancY[i]) cn[i] = 1
	}
	cn[yi] = 1

	paunion = J(n,1,0)
	for (i=1; i<=n; i++) {
		if (!cn[i]) continue
		for (j=1; j<=n; j++) {
			if (A[j,i]) paunion[j] = 1
		}
	}

	O = paunion :& (1 :- cn)
	O[xi] = 0

	optset = ""
	feasible = 1
	for (i=1; i<=n; i++) {
		if (!O[i]) continue
		optset = optset + (optset=="" ? "" : " ") + nodes[i]
		if (latent[i]) feasible = 0
	}
}

// ---------------------------------------------------------------------
// comprehensive pairwise testable implications: for every pair of
// non-adjacent nodes (a,b), search (bounded by maxcand, same 2^k
// enumeration style as dagy_m_adjust) for ANY separating set - the first
// one found, not necessarily the minimal one (dagitty's own localTests
// reports one valid separator per pair too, not a minimality
// guarantee). This is the "pairwise minimal-separator basis" deferred
// when dagy testable was first scoped to the (cheaper) local-Markov
// generating set instead; the two commands complement each other.
// pairA/pairB/pairsep are the raw components (for feeding into a
// regress-based test); pairstmt is the formatted display string.
// ---------------------------------------------------------------------
void dagy_m_localtests(real matrix A, string colvector nodes, real colvector latent,
	real scalar maxcand, string colvector pairstmt, string colvector pairA,
	string colvector pairB, string colvector pairsep, real colvector pairtestable,
	real scalar toolarge)
{
	real scalar n, i, a, b, k, ncand, m, nmask, bit, found, involveslatent
	real matrix S
	real colvector cand, candidx, Xa, Yb, Zsep

	n = rows(A)
	S = (A :| A')

	pairstmt = J(0,1,"")
	pairA = J(0,1,"")
	pairB = J(0,1,"")
	pairsep = J(0,1,"")
	pairtestable = J(0,1,.)
	toolarge = 0

	for (a=1; a<=n; a++) {
		for (b=a+1; b<=n; b++) {
			if (S[a,b]) continue

			cand = J(n,1,0)
			for (i=1; i<=n; i++) {
				if (i==a | i==b) continue
				cand[i] = 1
			}
			ncand = sum(cand)
			if (ncand > maxcand) {
				toolarge = 1
				continue
			}
			candidx = select((1::n), cand)

			Xa = J(n,1,0); Xa[a] = 1
			Yb = J(n,1,0); Yb[b] = 1

			found = 0
			nmask = 2^ncand
			for (m=0; m<=nmask-1; m++) {
				if (found) break
				Zsep = J(n,1,0)
				for (k=1; k<=ncand; k++) {
					bit = 2^(k-1)
					if (mod(floor(m/bit),2)) Zsep[candidx[k]] = 1
				}
				if (!dagy_m_dsep(A, Xa, Yb, Zsep)) continue

				found = 1
				string scalar zn
				zn = ""
				involveslatent = latent[a] | latent[b]
				for (i=1; i<=n; i++) {
					if (!Zsep[i]) continue
					zn = zn + (zn=="" ? "" : " ") + nodes[i]
					if (latent[i]) involveslatent = 1
				}
				pairA = pairA \ nodes[a]
				pairB = pairB \ nodes[b]
				pairsep = pairsep \ zn
				pairtestable = pairtestable \ (!involveslatent)
				if (zn == "") {
					pairstmt = pairstmt \ (nodes[a] + " _||_ " + nodes[b])
				}
				else {
					pairstmt = pairstmt \ (nodes[a] + " _||_ " + nodes[b] + " | {" + zn + "}")
				}
			}
		}
	}
}

// ---------------------------------------------------------------------
// latent projection of a DAG (observed + latent nodes) onto a MAG over
// only the observed nodes (no selection variables / no undirected `--'
// edges - out of scope). Two observed nodes a,b are MAG-adjacent iff no
// subset of the OTHER observed nodes d-separates them in the full
// original graph (latents included) - the standard characterization,
// tested directly with the existing d-separation primitive rather than
// needing new m-separation machinery, bounded the same 2^k way
// dagy_m_adjust bounds its own search (here over observed-variable
// count). If adjacent: a->b if a is an ancestor of b in the full graph,
// b->a symmetric, a<->b if neither (the unmeasured confounding
// "survives" projection and shows up as a bidirected edge).
// ---------------------------------------------------------------------
void dagy_m_mag(real matrix A, string colvector nodes, real colvector latent,
	real scalar maxcand, string colvector edges, real scalar toolarge)
{
	real scalar n, i, a, b, k, ncand, m, nmask, bit, sepfound
	real colvector obs, cand, candidx, Xa, Yb, Z, AncA, DescA

	n = rows(A)
	obs = 1 :- latent

	edges = J(0,1,"")
	toolarge = 0

	for (a=1; a<=n; a++) {
		if (latent[a]) continue
		for (b=a+1; b<=n; b++) {
			if (latent[b]) continue

			cand = J(n,1,0)
			for (i=1; i<=n; i++) {
				if (i==a | i==b) continue
				if (!obs[i]) continue
				cand[i] = 1
			}
			ncand = sum(cand)
			if (ncand > maxcand) {
				toolarge = 1
				continue
			}
			candidx = select((1::n), cand)

			Xa = J(n,1,0); Xa[a] = 1
			Yb = J(n,1,0); Yb[b] = 1

			sepfound = 0
			nmask = 2^ncand
			for (m=0; m<=nmask-1; m++) {
				if (sepfound) break
				Z = J(n,1,0)
				for (k=1; k<=ncand; k++) {
					bit = 2^(k-1)
					if (mod(floor(m/bit),2)) Z[candidx[k]] = 1
				}
				if (dagy_m_dsep(A, Xa, Yb, Z)) sepfound = 1
			}
			if (sepfound) continue

			AncA = dagy_m_anc(A, Xa)
			DescA = dagy_m_desc(A, Xa)
			if (DescA[b]) {
				edges = edges \ (nodes[a] + " -> " + nodes[b])
			}
			else if (AncA[b]) {
				edges = edges \ (nodes[b] + " -> " + nodes[a])
			}
			else {
				edges = edges \ (nodes[a] + " <-> " + nodes[b])
			}
		}
	}
}

// ---------------------------------------------------------------------
// standard base64 decode (RFC 4648 alphabet), implemented from scratch
// since Mata has no native base64 support. Used by `dagy import`'s
// live dagitty.net fetch, whose API returns the model text base64-
// encoded (verified directly from the dagitty R package's own source,
// function downloadGraph in r/R/dagitty.R). Whitespace/newlines and the
// `=' padding character are skipped; any other stray non-alphabet
// character is likewise skipped rather than raising an error.
// ---------------------------------------------------------------------
string scalar dagy_m_base64decode(string scalar s)
{
	string scalar alphabet, out, c
	real scalar i, n, val, bits, nbits, b

	alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

	out = ""
	bits = 0
	nbits = 0
	n = strlen(s)
	for (i=1; i<=n; i++) {
		c = substr(s,i,1)
		if (c == "=" | c == " " | c == char(10) | c == char(13) | c == char(9)) continue
		val = strpos(alphabet, c) - 1
		if (val < 0) continue
		bits = bits * 64 + val
		nbits = nbits + 6
		if (nbits >= 8) {
			nbits = nbits - 8
			b = floor(bits / (2^nbits))
			bits = mod(bits, 2^nbits)
			out = out + char(b)
		}
	}
	return(out)
}
end
