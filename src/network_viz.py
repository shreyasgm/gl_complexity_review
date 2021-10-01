def draw_network(
    nw,
    node_pos=None,
    node_color=None,
    node_size=None,
    edge_color=(0, 0, 0, 0.1),
    ax=None,
    figsize=(15, 15),
    **kwargs
):
    """
    Draw network using networkx

    Args:
        nw: networkx graph
        node_pos: node positions dictionary keyed by node
        node_color: "attr" indicates "color" node attribute holds colors
        node_size: "attr" indicates "size" node attribute holds sizes
        edge_color: edge colors, default is black

    """
    if node_color == "attr":
        node_color = nx.get_node_attributes(nw, "color")
    if node_size == "attr":
        node_size = nx.get_node_attributes(nw, "size")
    if ax is None:
        f, ax = plt.subplots(figsize=figsize)
    # Draw network
    ax = nx.draw_networkx(
        nw,
        pos=node_pos,
        with_labels=False,
        node_size=node_size,
        node_color=node_color,
        edge_color=edge_color,
        ax=ax,
        **kwargs
    )
    return ax