#include <nauty.h>

// TODO: learn how you're supposed to use the macro in nauty.h
#define DEFAULTOPTIONS_GRAPH optionblk options = \
 {0,FALSE,FALSE,FALSE,TRUE,FALSE,CONSOLWIDTH, \
  NULL,NULL,NULL,NULL,NULL,NULL,NULL,100,0,1,0,&dispatch_graph,FALSE,NULL}

// Simplify calling from julia by removing the need to understand statsblk or optionblk.
//
// Could return a results struct to simplify signature, but then memory allocation is by C. Much better to have Julia handle that.
void canonical_form(graph *g, int num_setwords, int num_vertices,
		    int *canonical_labelling, int *partition, int *orbits,
		    graph *canonical_graph) {
	DEFAULTOPTIONS_GRAPH;
	options.getcanon = 1;
	options.digraph = 1;

	// Ignore whatever we get given
	statsblk stats;

	densenauty(g, canonical_labelling, partition, orbits, &options, &stats, num_setwords, num_vertices, canonical_graph);
}

void densenauty_defaults_wrap(
		graph *g, int *labelling, int *partition,
	        int *orbits, int num_vertices, int num_setwords,
	        graph *canonical_graph
		) {
	DEFAULTOPTIONS_GRAPH;

	// Ignore whatever we get given
	statsblk stats;

	densenauty(g, labelling, partition, orbits, &options, &stats, num_setwords, num_vertices, canonical_graph);
}


// Wrapper that sets and ignores a statsblk object.
void densenauty_wrap(graph *g, int *labelling, int *partition,
		     int *orbits, optionblk *options,
		     int num_vertices, int num_setwords,
		     graph *canonical_graph) {
	// Give nauty a statsblk, but ignore the contents of it.
	statsblk stats;

	// Call nauty
	densenauty(g, labelling, partition, orbits, options, &stats, num_setwords, num_vertices, canonical_graph);
}

optionblk defaultoptions_graph() {
	DEFAULTOPTIONS_GRAPH;
	return options;
}

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

void int_fiddler(int *foo) {
	*foo = 8;
}

/* nauty(g->matrix, g->lab, g->ptn, NULL, g->orbits, */
/*         g->options, g->stats,  g->workspace, g->worksize, */
/*         g->no_setwords, g->no_vertices, NULL); */
