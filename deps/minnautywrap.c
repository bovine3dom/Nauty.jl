#include <nauty.h>

optionblk defaultoptions_graph() {
	DEFAULTOPTIONS_GRAPH(options);
	return options;
}

long wordsize() {
	return WORDSIZE;
}

/*
void selftest() {
	graph g[4] = {0, 0, 0, 0};
	graph outg[4];
	int labelling[4];
	int partition[4];
	int orbits[4];
	canonical_form(g, 1, 4, labelling, partition, orbits, outg);
}

// Proof of concept C function that receives and performs some work on a graph.
setword graph_receiver(graph *g, int len) {
	setword acc = 0;
	for (int i=0; i<len; i++) {
		acc += g[i] >> 32;
	}
	return acc;
}

/* nauty(g->matrix, g->lab, g->ptn, NULL, g->orbits, */
/*         g->options, g->stats,  g->workspace, g->worksize, */
/*         g->no_setwords, g->no_vertices, NULL); */
