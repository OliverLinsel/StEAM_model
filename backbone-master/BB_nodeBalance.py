# -*- coding: utf-8 -*-
"""
This file is part of Backbone.

Backbone is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Backbone is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with Backbone.  If not, see <http://www.gnu.org/licenses/>.

For further information, see https://gitlab.vtt.fi/backbone/backbone/-/wikis/home

@author: Esa Pursiheimo, Tomi J. Lindroos
"""
import os
import dash
from packaging import version
import dash_bootstrap_components as dbc
from dash import Input, Output, State, dcc, callback, html
import plotly.graph_objects as go
from dash.exceptions import PreventUpdate
import numpy as np
import gdxpds
import pandas as pd
from plotly.subplots import make_subplots
from typing import Tuple, List, Dict, Any



#----------------------------------------------------------
# Application configuration (DBC + routing callback naming)
#----------------------------------------------------------
# Initialize Dash app with external stylesheets for theming and icons
# - CYBORG theme provides a dark UI aesthetic
# - FONT_AWESOME enables use of icon fonts in the UI
app = dash.Dash(__name__,
                external_stylesheets=[dbc.themes.CYBORG,dbc.icons.FONT_AWESOME]
                )


#------------------------------------------------------------------
# Blank graph to be in layout, loading fig for waiting screen
#------------------------------------------------------------------
def blank_fig() -> go.Figure:
    """
    Create a blank Plotly figure with no data, styled using the dark template.

    Returns:
        go.Figure: An empty Plotly figure object with hidden axes and no grid.
    """
    fig = go.Figure(go.Scatter(x=[], y=[]))

    # Apply dark theme and remove axis ticks/grid
    fig.update_layout(template="plotly_dark")
    fig.update_xaxes(showgrid=False, showticklabels=False, zeroline=False)
    fig.update_yaxes(showgrid=False, showticklabels=False, zeroline=False)

    return fig


def message_fig(msg: str) -> go.Figure:
    """
    Create a Plotly figure with a central message annotation.

    Args:
        msg (str): Message text to display in the center of the figure.

    Returns:
        go.Figure: A Plotly figure with the message annotation applied.
    """
    fig = go.Figure()

    # Add annotation centered in the figure
    fig.add_annotation(
        text=msg,
        xref="paper", yref="paper",
        showarrow=False,
        font=dict(size=20),
        x=0.5, y=0.5
    )

    # Apply dark theme
    fig.update_layout(template="plotly_dark")

    return fig


#------------------------------------------------------------------
# Processing gdx file
#------------------------------------------------------------------

def safe_read(gdx_file: str, symbol_list: list[str], symbol: str, cols: list[str] = None) -> pd.DataFrame:
    """
    Safely read a symbol's DataFrame from a GDX file if it exists in the symbol list.

    Args:
        gdx_file (str): Path to the GDX file.
        symbol_list (list[str]): List of available symbols in the GDX file.
        symbol (str): Target symbol to read.
        cols (list[str], optional): Subset of columns to select from the DataFrame.

    Returns:
        pd.DataFrame: DataFrame for the symbol if found, otherwise an empty DataFrame.
    """
    if symbol in symbol_list:
        df = gdxpds.read_gdx.to_dataframe(gdx_file, symbol, old_interface=False)
        if cols:
            df = df[cols]
        return df
    else:
        return pd.DataFrame()


def get_node_list_from_pgn(df_p_gn: pd.DataFrame, df_influx: pd.DataFrame) -> pd.DataFrame:
    """
    Create a DataFrame of active nodes with flags indicating the presence of
    nodeBalance, energy storage, and influx parameters.

    Args:
        df_p_gn (pd.DataFrame): DataFrame containing 'param_gn', 'Value', and 'node' columns.
        df_influx (pd.DataFrame): DataFrame containing influx data, including 'node'.

    Returns:
        pd.DataFrame: DataFrame indexed by node, with boolean flags for 'bal', 'sta', and 'inf'.
    """
    # Filter to only active nodes
    active_nodes = df_p_gn[
        (df_p_gn["param_gn"] == "isActive") & 
        (df_p_gn["Value"] == 1)
    ]["node"].unique()

    # Create base DataFrame with node index
    df_nodes = pd.DataFrame(index=active_nodes)
    df_nodes.index.name = "node"
    df_nodes["bal"] = pd.Series(np.nan, index=df_nodes.index, dtype=object)
    df_nodes["sta"] = pd.Series(np.nan, index=df_nodes.index, dtype=object)
    df_nodes["inf"] = pd.Series(np.nan, index=df_nodes.index, dtype=object)

    # Set flag if node has a balance constraint
    df_nodes.loc[
        df_p_gn[df_p_gn["param_gn"] == "nodeBalance"]["node"].values, "bal"
    ] = True

    # Set flag if node is an energy storage
    df_nodes.loc[
        df_p_gn[df_p_gn["param_gn"] == "energyStoredPerUnitOfState"]["node"].values, "sta"
    ] = True

    # Set flag if node has constant influx defined in p_gn
    df_nodes.loc[
        df_p_gn[df_p_gn["param_gn"] == "influx"]["node"].values, "inf"
    ] = True

    # Also mark nodes with influx time series
    if not df_influx.empty:
        df_nodes.loc[
            df_influx["node"].unique(), "inf"
        ] = True

    return df_nodes


def parse_price_ts(gdx_file: str, t0: int) -> pd.DataFrame:
    """
    Parse commodity price data from GDX, combining constant and time series values.

    Args:
        gdx_file (str): Path to the GDX file.
        t0 (int): Time step to assign to static price values.

    Returns:
        pd.DataFrame: Combined DataFrame of price values indexed by time.
    """
    # Try to read the primary price data (new symbol name)
    df_p_price = gdxpds.read_gdx.to_dataframe(gdx_file, "p_priceNew", old_interface=False)
    df_ts_price = pd.DataFrame()

    # Check if new format prices 
    if "param_price" in df_p_price.columns: 
        # Check if time series data needs to be included
        if "useTimeSeries" in df_p_price["param_price"].values:
            df_ts_price = gdxpds.read_gdx.to_dataframe(gdx_file, "ts_priceNew", old_interface=False)
    # Fallback to old price data
    else:   
        df_p_price = gdxpds.read_gdx.to_dataframe(gdx_file, "p_price", old_interface=False)
        # Check if old format time series data needs to be included
        if "param_price" in df_p_price.columns and "useTimeSeries" in df_p_price["param_price"].values:
            df_ts_price = gdxpds.read_gdx.to_dataframe(gdx_file, "ts_price", old_interface=False)

    # Assign static time to constant price entries
    if not df_p_price.empty:
        df_p_price = df_p_price[df_p_price["param_price"] == "price"].rename(columns={"param_price": "t"})
        df_p_price["t"] = t0

    # Combine constant and time series prices
    if df_ts_price.empty:
        df = df_p_price
    elif df_p_price.empty:
        df = df_ts_price
    elif not df_ts_price.empty and not df_p_price.empty:
        df = pd.concat([df_ts_price, df_p_price], ignore_index=True)
    else:
        df = pd.DataFrame()

    # Include only realized values, assuming f00 is the realized forecast branch
    if "f" in df.columns:
        df = df[df["f"] == "f00"].drop("f", axis=1)

    return df


def parse_influx_ts(p_gn: pd.DataFrame, df_influx: pd.DataFrame, t0: int) -> pd.DataFrame:
    """
    Parse influx time series data by combining constant and timeseries data.

    Args:
        p_gn (pd.DataFrame): Parameter DataFrame including influx-related entries.
        df_influx (pd.DataFrame): Time series DataFrame for influx data.
        t0 (int): Default time step to assign to static influx entries.

    Returns:
        pd.DataFrame: Merged DataFrame of influx data with a unified structure.
    """
    # Pick realized influx, assuming f00, and drop f column
    df_influx = df_influx[df_influx["f"] == "f00"].drop(["f"], axis=1)

    # Prepare static influx from p_gn
    df_pgn = p_gn.copy()
    df_pgn = df_pgn[df_pgn["param_gn"] == "influx"]
    df_pgn = df_pgn.rename(columns={"param_gn": "t"})
    df_pgn["t"] = t0

    # Merge static and dynamic influx data
    if df_influx.empty:
        df = df_pgn
    elif df_pgn.empty:
        df = df_influx
    else:
        df = pd.concat([df_pgn, df_influx])

    return df


# ------------------------------------------------------------------
# App Layout: Dash UI constructed with Dash Bootstrap Components (dbc)
# ------------------------------------------------------------------

# Main layout container (fluid=True allows responsive width)
app.layout = dbc.Container(
    [
        # First row: user controls for data input and selection
        dbc.Row(
            [
                # Text input for GDX file path
                dbc.Col(
                    [
                        dcc.Input(
                            id='upload_data',
                            type='text',
                            debounce=True,  # Fires callback only after typing pause
                            value=r".\output\debug.gdx",
                                    style={
                                        'width': '95%',
                                        'height': '60px',
                                        'lineHeight': '60px',
                                        'borderWidth': '1px',
                                        'borderStyle': 'dashed',
                                        'borderRadius': '5px',
                                        'textAlign': 'center',
                                        'margin': '10px',
                                        'fontSize': '15px'
                                    },
                        )
                    ],
                    md=5
                ),

                # Placeholder to display GDX file name
                dbc.Col(
                    [
                        html.Div(id='gdx_name',
                                    style={
                                        'width': '95%',
                                        'height': '60px',
                                        'textAlign': 'left',
                                        'vertical-align': 'center',
                                        'margin': '10px',
                                        'fontSize': '30px'
                                    },
                        )
                    ],
                    md=3
                ),

                # Dropdown to select grid from GDX
                dbc.Col(
                    [
                        dbc.Select(id='grid_select',
                                    style={
                                        'width': '90%',
                                        'height': '60px',
                                        'margin': '10px 10px 10px 10px'
                                    }
                        )
                    ],
                    md=2
                ),

                # Dropdown to select node from selected grid
                dbc.Col(
                    [
                        dbc.Select(id='node_select',
                                style={
                                        'width': '90%',
                                        'height': '60px',
                                        'margin': '10px 10px 10px 10px'
                                    },
                        )
                    ],
                    md=2
                )
            ],
            justify='between'
        ),

        # Second row: graph for node balance data
        dbc.Row(
            [
                dbc.Col(
                    [
                        dcc.Loading(
                            dcc.Graph(id="node_balance", figure=blank_fig(), style={'height': '45vh'})
                        )
                    ]
                )
            ]
        ),

        # Third row: graph for marginal cost data
        dbc.Row(
            [
                dbc.Col(
                    [
                        dcc.Loading(
                            dcc.Graph(id="node_marginal_cost", figure=blank_fig(), style={'height': '45vh'})
                        )
                    ]
                )
            ]
        ),

        # Fullscreen modal for weekly data exploration on click
        dbc.Modal(
            [
                dbc.ModalHeader(id='week_header'),
                dbc.ModalBody(id="week_graf"),
                dbc.ModalFooter(
                    dbc.Button("Close", id="week_close", className="ml-auto")
                )
            ],
            fullscreen=True,
            id="week_modal",
            is_open=False  # Default closed until user interaction
        ),

        # In-memory storage for raw and filtered data
        dcc.Store(id='result_data', storage_type='memory'),
        dcc.Store(id='filtered_data', storage_type='memory'),
    ],
    # Enabling full-width container layout
    fluid=True  
)


#------------------------------------------------------
# Select file callback
#------------------------------------------------------
@callback(
    Output("grid_select", "options"),     # Dropdown options for grids
    Output("grid_select", "value"),       # Default selected grid
    Output("result_data", "data"),        # Parsed data stored in memory
    Output("node_balance", "figure"),     # Placeholder graph with loading message
    Input("upload_data", "value")         # Triggered when file path input changes
)
def new_file_selected(gdx_file: str) -> Tuple[List[Dict[str, str]], str, Dict[str, Any], Any]:
    """
    Dash callback to handle file input.
    Loads GDX file, verifies content, and prepares initial data layout.

    Args:
        gdx_file (str): Path to the input .gdx file.

    Returns:
        Tuple:
            - Grid dropdown options (list of label/value dicts)
            - Default grid value (str)
            - Result data dictionary to store in dcc.Store
            - Figure displaying status or errors (go.Figure-like)
    """
    res_dict: Dict[str, Any] = {}

    try:
        # --- validity checks ---
        # File validity check
        if not os.path.exists(gdx_file) or not gdx_file.lower().endswith(".gdx"):
            msg = "No file found, or not a gdx file. Check spelling."
            return [], "", {}, message_fig(msg)

        # Ensure 'gn' symbol exists (Backbone-specific check)
        symbol_list = gdxpds.read_gdx.list_symbols(gdx_file)
        if "gn" not in symbol_list:
            print("Missing 'gn' symbol in GDX file. Check that file is Backbone debug.gdx")
            raise PreventUpdate

        # --- Preparing the (grid, node) structure ---
        # Read required symbols
        df_p_gn = safe_read(gdx_file, symbol_list, "p_gn")
        df_influx = safe_read(gdx_file, symbol_list, "ts_influx")

        # Build (grid, node) mapping of active entries
        mask_active = (df_p_gn["param_gn"] == "isActive") & (df_p_gn["Value"] == 1)
        gn_df = df_p_gn.loc[mask_active, ["grid", "node"]].reset_index(drop=True)

        # Generate grid selector options
        grid_list_raw = sorted(gn_df["grid"].unique())
        grid_list = [{"label": g, "value": g} for g in grid_list_raw]
        default_grid = grid_list[0]["value"] if grid_list else ""

        # Analyze node types
        node_df = get_node_list_from_pgn(df_p_gn, df_influx)


        # --- Populate result dictionary ---
        res_dict["nodes"] = node_df.reset_index().to_dict("records")
        res_dict["gn_map"] = gn_df.drop(columns=["Value"], errors="ignore").to_dict("records")
        res_dict["gen"] = safe_read(gdx_file, symbol_list, "r_gen_gnuft").to_dict("records")
        res_dict["ts"] = safe_read(gdx_file, symbol_list, "r_info_t_realized", cols=["t"]).to_dict("records")

        # t0 is int used when converting constant values to timeseries for plotting
        t0 = res_dict["ts"][0]["t"] if res_dict["ts"] else 0

        res_dict["gnn"] = safe_read(gdx_file, symbol_list, "r_transfer_gnnft").to_dict("records")
        res_dict["mc"] = safe_read(gdx_file, symbol_list, "r_balance_marginalValue_gnft").to_dict("records")
        res_dict["sta"] = safe_read(gdx_file, symbol_list, "r_state_gnft").to_dict("records")
        res_dict["pri"] = parse_price_ts(gdx_file, t0).to_dict("records") if t0 else []
        res_dict["inf"] = parse_influx_ts(df_p_gn, df_influx, t0).to_dict("records") if t0 else []
        res_dict["dum"] = safe_read(gdx_file, symbol_list, "r_qGen_gnft").to_dict("records")
        res_dict["spi"] = safe_read(gdx_file, symbol_list, "r_spill_gnft").to_dict("records")

        # --- Step 4: Return controls and loading message ---
        msg = "Loading data from GDX, please wait..."
        return grid_list, default_grid, res_dict, message_fig(msg)

    except Exception as e:
        print(f"Exception in new_file_selected: {e}")
        raise PreventUpdate


#------------------------------------------------------
# Select grid callback
#------------------------------------------------------

@callback(
    Output("node_select", "options"),                       # Dropdown options for nodes
    Output("node_select", "value"),                         # Default selected node
    Output("filtered_data", "data"),                        # Filtered dataset to store
    Output("node_balance", "figure", allow_duplicate=True), # Updated node balance figure; allows multiple callbacks to set this
    Output("node_marginal_cost", "figure"),                 # Updated marginal cost figure
    Input("grid_select", "value"),                          # Trigger on grid selection
    State("result_data", "data"),                           # Use preloaded full dataset
    prevent_initial_call=True                               # Prevents this callback from running at app start
)
def new_grid_selected(grid: str, data: Dict[str, Any]) -> Tuple[List[Dict[str, str]], str, Dict[str, Any], Any, Any]:
    """
    Dash callback triggered on grid selection. Filters node-related data
    for the selected grid and returns updated options and relevant figures.

    Args:
        grid (str): Selected grid identifier.
        data (dict): Dictionary containing full parsed GDX data.

    Returns:
        Tuple:
            - List of node dropdown options.
            - Default selected node.
            - Filtered dataset dictionary for selected grid.
            - Placeholder node balance figure.
            - Placeholder marginal cost figure.
    """
    if not grid or "gn_map" not in data or "nodes" not in data:
        raise PreventUpdate

    # --- Extract and filter node data for selected grid ---
    df_gn = pd.DataFrame(data["gn_map"])
    df_all_nodes = pd.DataFrame(data["nodes"])

    # Filter to only nodes within the selected grid
    filtered_node_names = df_gn[df_gn["grid"] == grid]["node"].unique()
    df_filtered_nodes = df_all_nodes[df_all_nodes["node"].isin(filtered_node_names)]

    # Generate dropdown options and default node
    node_list_raw = sorted(df_filtered_nodes["node"].tolist())
    node_list = [{"label": n, "value": n} for n in node_list_raw]
    default_node = node_list[0]["value"] if node_list else ""

    # --- Helper function: filter a DataFrame by grid (node presence) ---
    node_set = set(node_list_raw)

    def filter_df(key: str) -> List[Dict[str, Any]]:
        if key not in data:
            return []

        df = pd.DataFrame(data[key])
        if df.empty or df.shape[1] == 0:
            return []

        if "node" in df.columns:
            df = df[df["node"].isin(node_set)]
        elif {"from_node", "to_node"}.issubset(df.columns):
            df = df[df["from_node"].isin(node_set) | df["to_node"].isin(node_set)]

        return df.to_dict("records")

    # --- Assemble grid-filtered dataset dictionary ---
    filtered_data = {
        "ts": data.get("ts", []),
        "nodes": df_filtered_nodes.to_dict("records"),
        "gen": filter_df("gen"),
        "gnn": filter_df("gnn"),
        "mc": filter_df("mc"),
        "sta": filter_df("sta"),
        "pri": filter_df("pri"),
        "inf": filter_df("inf"),
        "dum": filter_df("dum"),
        "spi": filter_df("spi"),
    }

    # Generating waiting figure
    msg = "Loading data from GDX, please wait..."
    return node_list, default_node, filtered_data, message_fig(msg), message_fig("")


#------------------------------------------------------
# Select node callback
#------------------------------------------------------
@callback(
    Output("node_balance", "figure", allow_duplicate=True),         # print daily node balance figure; allows multiple callbacks to set this
    Output("node_marginal_cost", "figure", allow_duplicate=True),   # print daily node marginal cost figure; allows multiple callbacks to set this
    Input("node_select",'value'),                                   # Trigger on grid selection
    State('filtered_data','data'),                                  # Use preloaded filtered dataset
    prevent_initial_call=True                                       # Prevents this callback from running at app start
    )
def new_node_selected(node: str, data: Dict[str, Any]) -> Tuple[go.Figure, go.Figure]:
    """
    Dash callback to generate node-level figures based on selected node.

    Args:
        node (str): Selected node identifier.
        data (Dict[str, Any]): Filtered data dictionary for the selected grid.

    Returns:
        Tuple[go.Figure, go.Figure]: Bar chart for node balance and line chart for marginal cost.
    """
    if not node or not data or "ts" not in data:
        raise PreventUpdate

    ts = pd.DataFrame(data['ts'])["t"]
    node_df = pd.DataFrame(data["nodes"]).set_index("node")

    # --- Generation data ---
    df_gen = pd.DataFrame(data['gen'])
    if not df_gen.empty:
        tab_gen = pd.pivot_table(
            df_gen[df_gen["node"] == node],
            index="t", columns="unit", values="Value", aggfunc="sum"
        ).reindex(ts).fillna(0.0)
        tab_gen = tab_gen.groupby(np.arange(len(tab_gen)) // 24).mean()

    # --- Transfer data ---
    df_tra = pd.DataFrame(data['gnn'])
    if not df_tra.empty:
        df_tra = df_tra[(df_tra["from_node"] == node) | (df_tra["to_node"] == node)]
        tab_tra = pd.pivot_table(
            df_tra, index="t", columns=("from_node", "to_node"), values="Value", aggfunc="sum"
        ).reindex(ts).fillna(0.0)
        if node in tab_tra.columns:
            tab_tra[node] = -tab_tra[node]
        tab_tra = tab_tra.groupby(np.arange(len(tab_tra)) // 24).mean()

    df_spi = pd.DataFrame(data["spi"])
    df_dum = pd.DataFrame(data["dum"])

    # --- Build node balance bar chart ---
    fig1 = go.Figure()

    if not df_gen.empty:
        for u in tab_gen.columns:
            fig1.add_trace(go.Bar(x=tab_gen.index, y=tab_gen[u], name=u,
                                  hovertemplate="(day %{x}, %{y:.2f}) " + u + "<extra></extra>"))

    if not df_tra.empty:
        for top in tab_tra.columns:
            label = ' → '.join(top)
            fig1.add_trace(go.Bar(x=tab_tra.index, y=tab_tra[top], name=label,
                                  hovertemplate="(day %{x}, %{y:.2f}) " + label + "<extra></extra>"))

    if node_df.loc[node, "inf"]:
        df_inf = pd.DataFrame(data['inf'])
        df_inf = df_inf[df_inf["node"] == node].set_index("t").reindex(ts).ffill()
        df_inf = df_inf[["Value"]].groupby(np.arange(len(df_inf)) // 24).mean()
        fig1.add_trace(go.Bar(x=df_inf.index, y=df_inf["Value"], name="Influx",
                              hovertemplate="(day %{x}, %{y:.2f}) Influx<extra></extra>"))

    if not df_spi.empty:
        df_spi = df_spi[df_spi["node"] == node].set_index("t").reindex(ts).fillna(0.0)
        df_spi = -df_spi[["Value"]].groupby(np.arange(len(df_spi)) // 24).mean()
        fig1.add_trace(go.Bar(x=df_spi.index, y=df_spi["Value"], name="Spill",
                              hovertemplate="(day %{x}, %{y:.2f}) Spill<extra></extra>"))

    if not df_dum.empty:
        df_dum = df_dum[df_dum["node"] == node]
        tab_dum = pd.pivot_table(df_dum, index="t", columns="inc_dec", values="Value", aggfunc="sum")
        tab_dum = tab_dum.reindex(ts).fillna(0.0)
        tab_dum = tab_dum.groupby(np.arange(len(tab_dum)) // 24).mean()
        if "increase" in tab_dum.columns:
            fig1.add_trace(go.Bar(x=tab_dum.index, y=tab_dum["increase"], name="Dummy increase",
                                  hovertemplate="(day %{x}, %{y:.2f}) Dummy increase<extra></extra>"))
        if "decrease" in tab_dum.columns:
            tab_dum["decrease"] = -tab_dum["decrease"]
            fig1.add_trace(go.Bar(x=tab_dum.index, y=tab_dum["decrease"], name="Dummy decrease",
                                  hovertemplate="(day %{x}, %{y:.2f}) Dummy decrease<extra></extra>"))

    fig1.update_layout(
        barmode='relative', margin=dict(l=0, r=50, b=0, t=50), template="plotly_dark",
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="left", x=0.01)
    )
    fig1.add_hline(y=0, line_width=3, line_color="white")

    # --- Build marginal cost or price + state chart ---
    fig2 = make_subplots(specs=[[{"secondary_y": True, "r": -0.06}]])

    if node_df.loc[node, 'bal']:
        df_mc = pd.DataFrame(data['mc'])
        if not df_mc.empty:
            df_mc = -df_mc[df_mc["node"] == node].set_index("t").reindex(ts)["Value"].fillna(0.0)
            fig2.add_trace(go.Scatter(x=df_mc.index, y=df_mc, name="Node MC",
                                      hovertemplate="(%{x}, %{y:.2f}) %{fullData.name}<extra></extra>"), secondary_y=False)
    else:
        df_pri = pd.DataFrame(data['pri'])
        if not df_pri.empty:
            df_pri = df_pri[df_pri["node"] == node].set_index("t").reindex(ts).ffill()
            fig2.add_trace(go.Scatter(x=df_pri.index, y=df_pri['Value'], name="Commodity Price",
                                      hovertemplate="(%{x}, %{y:.2f}) %{fullData.name}<extra></extra>"), secondary_y=False)

    if node_df.loc[node, "sta"]:
        df_sta = pd.DataFrame(data["sta"])
        if not df_sta.empty:
            df_sta = df_sta[df_sta["node"] == node].set_index("t").reindex(ts).fillna(0.0)
            fig2.add_trace(go.Scatter(x=df_sta.index, y=df_sta['Value'], name="Storage State",
                                      hovertemplate="(%{x}, %{y:.2f}) %{fullData.name}<extra></extra>"), secondary_y=True)

    fig2.update_layout(
        margin=dict(l=0, r=50, b=0, t=50), template="plotly_dark",
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="left", x=0.01),
        showlegend=True
    )
    fig2.update_yaxes(title_text='')

    return fig1, fig2


#------------------------------------------------------------------
# Callback for annual clickdata
#------------------------------------------------------------------
@callback(
    Output('week_header', 'children'),         # Updates the content of the modal header
    Output("week_graf", 'children'),           # Outputs the Plotly graph inside the modal
    Output('week_modal', 'is_open'),           # Controls whether the modal is shown
    Input("node_balance", "clickData"),        # Triggered by a click event in the node balance chart
    State("result_data", 'data'),              # Provides the full result dataset without triggering the callback
    State("node_select", 'value'),             # Currently selected node, also read-only
    prevent_initial_call=True                  # Prevents this callback from running at app start
)
def create_week_modal(clicks: Dict[str, Any], data: Dict[str, Any], node: str) -> Tuple[html.Div, dcc.Loading, bool]:
    """
    Callback to create a modal displaying 5-day detailed view of selected node's activity.

    Args:
        clicks (dict): Click event data from node_balance graph.
        data (dict): Result data dictionary containing full GDX-derived sets.
        node (str): Selected node identifier.

    Returns:
        Tuple:
            - HTML div with modal header text.
            - Loading wrapper containing the generated Plotly figure.
            - Boolean flag to open the modal.
    """
    ts = pd.DataFrame(data['ts'])["t"]
    node_df = pd.DataFrame(data["nodes"]).set_index("node")

    # --- Generation Data ---
    df_gen = pd.DataFrame(data['gen'])
    if not df_gen.empty:
        tab_gen = pd.pivot_table(
            df_gen[df_gen["node"] == node], index="t", columns="unit", values="Value", aggfunc="sum"
        ).reindex(ts).fillna(0.0)

    # --- Transfer Data ---
    df_tra = pd.DataFrame(data['gnn'])
    if not df_tra.empty:
        df_tra = df_tra[(df_tra["from_node"] == node) | (df_tra["to_node"] == node)]
        tab_tra = pd.pivot_table(df_tra, index="t", columns=("from_node", "to_node"), values="Value", aggfunc="sum")
        tab_tra = tab_tra.reindex(ts).fillna(0.0)
        if node in tab_tra.columns:
            tab_tra[node] = -tab_tra[node]

    # --- Influx ---
    if node_df.loc[node, "inf"]:
        df_inf = pd.DataFrame(data['inf'])
        df_inf = df_inf[df_inf["node"] == node].set_index("t").reindex(ts).ffill()

    df_spi = pd.DataFrame(data["spi"])
    df_dum = pd.DataFrame(data["dum"])

    # --- Define Hour Range ---
    h_start = clicks["points"][0]["x"] * 24
    h_end = h_start + 5 * 24  # 5-day window

    # Clip to week
    tab_gen = tab_gen.iloc[h_start:h_end, :]
    tab_tra = tab_tra.iloc[h_start:h_end, :]

    # --- Subplot Figure ---
    fig1 = make_subplots(
        rows=2, cols=1, vertical_spacing=0.05, shared_xaxes=True, row_heights=[0.8, 0.2],
        specs=[[{"secondary_y": True}], [{"secondary_y": True}]]
    )

    # --- Add bar traces ---
    if not df_gen.empty:
        for u in tab_gen.columns:
            fig1.add_trace(go.Bar(x=tab_gen.index, y=tab_gen[u], name=u), row=1, col=1, secondary_y=False)

    if not df_tra.empty:
        for top in tab_tra.columns:
            label = ' → '.join(top)
            fig1.add_trace(go.Bar(x=tab_tra.index, y=tab_tra[top], name=label), row=1, col=1, secondary_y=False)

    if node_df.loc[node, "inf"]:
        df_inf = df_inf.iloc[h_start:h_end, :]
        fig1.add_trace(go.Bar(x=df_inf.index, y=df_inf["Value"], name="Influx"), row=1, col=1, secondary_y=False)

    if not df_spi.empty:
        df_spi = df_spi[df_spi["node"] == node]
        if not df_spi.empty:
            df_spi = df_spi.set_index("t").reindex(ts).fillna(0.0).iloc[h_start:h_end, :]
            if not (df_spi["Value"] == 0.0).all():
                fig1.add_trace(go.Bar(x=df_spi.index, y=-df_spi["Value"], name="Spill"), row=1, col=1, secondary_y=False)

    if not df_dum.empty:
        df_dum = df_dum[df_dum["node"] == node]
        tab_dum = pd.pivot_table(df_dum, index="t", columns="inc_dec", values="Value", aggfunc="sum").reindex(ts).fillna(0.0)
        tab_dum = tab_dum.iloc[h_start:h_end, :]
        if "increase" in tab_dum.columns:
            fig1.add_trace(go.Bar(x=tab_dum.index, y=tab_dum["increase"], name="Dummy increase"), row=1, col=1, secondary_y=False)
        if "decrease" in tab_dum.columns:
            tab_dum["decrease"] = -tab_dum["decrease"]
            fig1.add_trace(go.Bar(x=tab_dum.index, y=tab_dum["decrease"], name="Dummy decrease"), row=1, col=1, secondary_y=False)

    # Adjusting the layout
    fig1.update_layout(barmode='relative', margin=dict(l=0, r=50, b=0, t=50), template="plotly_dark")
    fig1.add_hline(y=0, line_width=3, line_color="white")

    # --- Line plot traces (MC/Price/State) ---
    if node_df.loc[node, 'bal']:
        df_mc = pd.DataFrame(data['mc'])
        if not df_mc.empty:
            df_mc = -df_mc[df_mc["node"] == node].set_index("t").reindex(ts)["Value"].fillna(0.0).iloc[h_start:h_end]
            fig1.add_trace(go.Scatter(x=df_mc.index, y=df_mc, name="Node MC"), row=2, col=1, secondary_y=False)
    else:
        df_pri = pd.DataFrame(data['pri'])
        if not df_pri.empty:
            df_pri = df_pri[df_pri["node"] == node].set_index("t").reindex(ts).ffill().iloc[h_start:h_end]
            fig1.add_trace(go.Scatter(x=df_pri.index, y=df_pri['Value'], name="Commodity Price"), row=2, col=1, secondary_y=False)

    if node_df.loc[node, "sta"]:
        df_sta = pd.DataFrame(data["sta"])
        if not df_sta.empty:
            df_sta = df_sta[df_sta["node"] == node].set_index("t").reindex(ts).fillna(0.0).iloc[h_start:h_end]
            fig1.add_trace(go.Scatter(x=df_sta.index, y=df_sta['Value'], name="Storage State"), row=2, col=1, secondary_y=True)

    fig1.update_layout(legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="left", x=0.01), showlegend=True)

    return (
        html.Div("Node balance (5 days):", style={"fontSize": "25px"}),
        dcc.Loading(dcc.Graph(figure=fig1, style={'height': '85vh'})),
        True
    )



#------------------------------------------------------
# Callback for Week data modal close
#------------------------------------------------------
@callback(
    Output("week_modal", "is_open", allow_duplicate=True),   # Controls modal visibility; allows multiple callbacks to set this
    Input("week_close", "n_clicks"),                         # Triggered when the modal's close button is clicked
    prevent_initial_call=True                                # Prevents the callback from firing when the app first loads
)
def close_mc_modal(n):
    """Callback to close the week modal when close button is clicked."""
    return False

#------------------------------------------------------
# App launch (with version control)
#------------------------------------------------------

if __name__ == "__main__":
    if version.parse(dash.__version__) >= version.parse("3.0.0"):
        app.run(debug=True,port=8888)
    else:
        app.run_server(debug=True,port=8888)