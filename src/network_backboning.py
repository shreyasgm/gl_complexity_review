# Network backboning - filtering out non-significant edges from a noisy network
# Coscia & Neffke “Network Backboning with Noisy Data”, ICDE 2017
# https://www.michelecoscia.com/wp-content/uploads/2017/01/20170124backboning.pdf

import pandas as pd
import numpy as np
import scipy
from scipy.stats import binom
import networkx as nx


def get_edge_significance(
    table,
    undirected=True,
    return_self_loops=False,
    calculate_p_value=False,
):
    """
    Get significance scores
    Args:
        table: dataframe containing edgelist, with columns src, trg, and other cols
            are edgeweights, with at least one called nij

    """
    table = table.copy()
    original_cols = table.columns
    src_sum = table.groupby(by="src").sum()[["nij"]]
    table = table.merge(
        src_sum, left_on="src", right_index=True, suffixes=("", "_src_sum")
    )
    trg_sum = table.groupby(by="trg").sum()[["nij"]]
    table = table.merge(
        trg_sum, left_on="trg", right_index=True, suffixes=("", "_trg_sum")
    )
    table = table.rename(columns={"nij_src_sum": "ni.", "nij_trg_sum": "n.j"})
    table["n.."] = table["nij"].sum()
    table["mean_prior_probability"] = ((table["ni."] * table["n.j"]) / table["n.."]) * (
        1 / table["n.."]
    )
    if calculate_p_value:
        table["score"] = binom.cdf(
            table["nij"], table["n.."], table["mean_prior_probability"]
        )
        return table[["src", "trg", "nij", "score"]]
    table["kappa"] = table["n.."] / (table["ni."] * table["n.j"])
    table["score"] = ((table["kappa"] * table["nij"]) - 1) / (
        (table["kappa"] * table["nij"]) + 1
    )
    table["var_prior_probability"] = (
        (1 / (table["n.."] ** 2))
        * (
            table["ni."]
            * table["n.j"]
            * (table["n.."] - table["ni."])
            * (table["n.."] - table["n.j"])
        )
        / ((table["n.."] ** 2) * ((table["n.."] - 1)))
    )
    table["alpha_prior"] = (
        ((table["mean_prior_probability"] ** 2) / table["var_prior_probability"])
        * (1 - table["mean_prior_probability"])
    ) - table["mean_prior_probability"]
    table["beta_prior"] = (
        table["mean_prior_probability"] / table["var_prior_probability"]
    ) * (1 - (table["mean_prior_probability"] ** 2)) - (
        1 - table["mean_prior_probability"]
    )
    table["alpha_post"] = table["alpha_prior"] + table["nij"]
    table["beta_post"] = table["n.."] - table["nij"] + table["beta_prior"]
    table["expected_pij"] = table["alpha_post"] / (
        table["alpha_post"] + table["beta_post"]
    )
    table["variance_nij"] = (
        table["expected_pij"] * (1 - table["expected_pij"]) * table["n.."]
    )
    table["d"] = (1.0 / (table["ni."] * table["n.j"])) - (
        table["n.."]
        * ((table["ni."] + table["n.j"]) / ((table["ni."] * table["n.j"]) ** 2))
    )
    table["variance_cij"] = table["variance_nij"] * (
        (
            (2 * (table["kappa"] + (table["nij"] * table["d"])))
            / (((table["kappa"] * table["nij"]) + 1) ** 2)
        )
        ** 2
    )
    table["sdev_cij"] = table["variance_cij"] ** 0.5

    if not return_self_loops:
        table = table[table["src"] != table["trg"]]

    if undirected:
        # Only keep first occurrence of combination
        table = table[table["src"] <= table["trg"]]

    # Reset index before returning
    table = table.reset_index(drop=True)
    newcols = [
        "src",
        "trg",
        "nij",
        "score",
        "sdev_cij",
        "variance_cij",
        "d",
        "expected_pij",
        "variance_nij",
        "kappa",
        "var_prior_probability",
    ]
    edgelist = table[newcols + [x for x in original_cols if x not in newcols]]
    return edgelist


def noise_correct_nw(
    nw,
    weightcol,
    noise_correction_threshold=0.2,
    undirected=True,
    return_self_loops=False,
    calculate_p_value=False,
):
    """Noise correct a network using network backboning algorithm

    Args:
        nw (networkx graph): network to denoise
        weightcol (str): edge weight to use for significance correction
        noise_correction_threshold (float, optional): Only keep edges above this significance value. Defaults to 0.2.
        undirected (bool, optional): whether graph is undirected. Defaults to True.
        return_self_loops (bool, optional): Defaults to False.
        calculate_p_value (bool, optional): Defaults to False.

    Returns:
        corrected_nw (networkx graph): denoised network
    """
    # Convert network to edgelist
    edgelist = nx.to_pandas_edgelist(nw, source="src", target="trg")
    edgecols = list(edgelist.columns)
    edgelist["nij"] = edgelist[weightcol]
    # Get edgelist with scores
    edgelist = get_edge_significance(
        table=edgelist,
        undirected=undirected,
        return_self_loops=return_self_loops,
        calculate_p_value=calculate_p_value,
    )
    # Keep relevant values
    newcols = ["src", "trg", "nij", "score"]
    edgelist = edgelist[newcols + [x for x in edgecols if x not in newcols]]
    edgelist = edgelist[edgelist["score"] > noise_correction_threshold]
    # Convert edgelist back to network
    nw_type = nx.Graph() if undirected else nx.DiGraph()
    corrected_nw = nx.from_pandas_edgelist(
        edgelist, source="src", target="trg", edge_attr=True, create_using=nw_type
    )
    nx.set_node_attributes(corrected_nw, dict(nw.nodes(data=True)))
    return corrected_nw
