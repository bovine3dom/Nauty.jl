#include <nauty.h>
#include <nautinv.h>

optionblk defaultoptions_graph() {
	DEFAULTOPTIONS_GRAPH(options);
	return options;
}

optionblk defaultoptions_digraph() {
	DEFAULTOPTIONS_DIGRAPH(options);
	return options;
}

long wordsize() {
	return WORDSIZE;
}

void baked_options(graph *g, int *canonical_labelling, int *partition, int *orbits,
		   statsblk *stats, int num_setwords, int num_vertices, graph *canonical_graph) {
	/* statsblk stats; */
	DEFAULTOPTIONS_GRAPH(options);
	options.getcanon = 1;
	options.digraph = 1;

	return densenauty(g, canonical_labelling, partition, orbits, &options, stats, num_setwords, num_vertices, canonical_graph);
}

void baked_options_color(graph *g, int *canonical_labelling, int *partition, int *orbits,
		   statsblk *stats, int num_setwords, int num_vertices, graph *canonical_graph) {
	/* statsblk stats; */
	DEFAULTOPTIONS_GRAPH(options);
	options.getcanon = 1;
	options.digraph = 1;
	options.defaultptn = 0;

	return densenauty(g, canonical_labelling, partition, orbits, &options, stats, num_setwords, num_vertices, canonical_graph);
}

void baked_options_and_stats(graph *g, int *canonical_labelling, int *partition, int *orbits,
		   int num_setwords, int num_vertices, graph *canonical_graph) {
	statsblk stats;
	DEFAULTOPTIONS_GRAPH(options);
	options.getcanon = 1;
	options.digraph = 1;

	return densenauty(g, canonical_labelling, partition, orbits, &options, &stats, num_setwords, num_vertices, canonical_graph);
}
