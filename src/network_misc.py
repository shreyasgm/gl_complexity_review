def available_node_attributes(g):
    """List available node attributes"""
    return set([k for n in g.nodes for k in g.nodes[n].keys()])


def available_edge_attributes(g):
    """List available edge attributes"""
    return set([k for n in g.edges for k in g.edges[n].keys()])
