var width = 1200,
    height = 800;

var tree = d3.layout.tree()
    .size([width, height])
    .children(function (d) { return d.states || d.actions || d.observations; });

var diagonal = d3.svg.diagonal();

var svg = d3.select("body").append("svg")
    .attr("width", width + 100)
    .attr("height", height + 100)
    .append("g")
    .attr("transform", "translate(10,10)");

var root,
    i = 0,
    duration = 750;

d3.json("mcts.json", function(error, json) {
    root = json
    root.x0 = width / 2;
    root.y0 = 0;

    //root.states.forEach(collapse);

    update(root);
});


function collapse(d) {
    if (d.states) {
        d._states = d.states;
        d._states.forEach(collapse);
        d.states = null;
    } else if (d.actions) {
        d._actions = d.actions;
        d._actions.forEach(collapse);
        d.actions = null;
    } else if (d.observations) {
        d._observations = d.observations;
        d._observations.forEach(collapse);
        d.observations = null;
    }
}

function click(d) {
    if (d.states) {
        d._states = d.states;
        d.states = null;
    } else if (d._states) {
        d.states = d._states;
        d._states = null;
    } else if (d.actions) {
        d._actions = d.actions;
        d.actions = null;
    } else if (d._actions) {
        d.actions = d._actions;
        d._actions = null;
    } else if (d.observations) {
        d._observations = d.observations;
        d.observations = null;
    } else if (d._observations) {
        d.observations = d._observations;
        d._observations = null;
    }

    update(d);
}

function mouseover(d) {
    d3.select(this).append("text")
        .attr("class", "hover")
        .attr('transform', function(d) { return 'translate(8, 4)'; })
        .text(function (d) {
            if (d.name)
                return d.name
            else if (d.state)
                return d.state + ", " + d.N
            else if (d.action)
                return d.action + ", " + d.N + ", " + d.r + ", " + d.R
            else if (d.observation)
                return d.observation
        });
}

function mouseout(d) {
    d3.select(this).select("text.hover").remove();
}

function update(source) {
    var nodes = tree.nodes(root).reverse(),
        links = tree.links(nodes);

    //console.log(nodes)

    nodes.forEach(function(d) { d.y = d.depth * 50; });

    var node = svg.selectAll("g.node")
        .data(nodes, function(d) { return d.id || (d.id = ++i); });


    var nodeEnter = node.enter().append("g")
        .attr("class", "node")
        .attr("transform", function(d) { return "translate(" + source.x0 + "," + source.y0 + ")"; })
        .on("click", click)
        .on("mouseover", mouseover)
        .on("mouseout", mouseout);

    nodeEnter.append("circle")
        .attr("r", 4.5)
        .attr("style", coloring_rs_node);

    nodeEnter.append("text")
        .attr("dx", 8)
        .attr("dy", 4)
        .text(texting_rs_node)
        .style("fill-opacity", 1e-6);


    var nodeUpdate = node.transition()
        .duration(duration)
        .attr("transform", function(d) { return "translate(" + d.x + "," + d.y + ")"; });

    nodeUpdate.select("circle")
        .attr("r", 4.5)
        .attr("style", coloring_rs_node);

    nodeUpdate.select("text")
        .style("fill-opacity", 1);


    var nodeExit = node.exit().transition()
        .duration(duration)
        .attr("transform", function(d) { return "translate(" + source.x + "," + source.y + ")"; })
        .remove();

    nodeExit.select("circle")
        .attr("r", 1e-6);

    nodeExit.select("text")
        .style("fill-opacity", 1e-6);


    var link = svg.selectAll("path.link")
        .data(links, function(d) { return d.target.id; });

    link.enter().insert("path", "g")
        .attr("class", "link")
        .attr("d", function(d) {
            var o = {x: source.x0, y: source.y0};
            return diagonal({source: o, target: o});
        });

    link.transition()
        .duration(duration)
        .attr("d", diagonal);

    link.exit().transition()
        .duration(duration)
        .attr("d", function(d) {
            var o = {x: source.x, y: source.y};
            return diagonal({source: o, target: o});
        })
        .remove();


    nodes.forEach(function(d) {
        d.x0 = d.x;
        d.y0 = d.y;
    });
}


function coloring_cb_node(d) {
    if (d.state && d.actions != null) {
        if (d.state.search("nothungry") != -1)
            return "fill: white; stroke: red; stroke-opacity: 0.5"
        else
            return "fill: red; fill-opacity: 0.5"
    } else if (d.state) {
        if (d.state.search("nothungry") != -1)
            return "fill: white; stroke: red; stroke-opacity: 0.8"
        else
            return "fill: red; fill-opacity: 0.8"
    } else if (d.action && d.observations != null) {
        if (d.action.search("notfeed") != -1)
            return "fill: white; stroke: blue; stroke-opacity: 0.5"
        else
            return "fill: blue; fill-opacity: 0.5"
    } else if (d.action) {
        if (d.action.search("notfeed") != -1)
            return "fill: white; stroke: blue; stroke-opacity: 0.8"
        else
            return "fill: blue; fill-opacity: 0.8"
    } else if (d.observation && d.states != null) {
        if (d.observation.search("notcrying") != -1)
            return "fill: white; stroke: orange; stroke-opacity: 0.5"
        else
            return "fill: orange; fill-opacity: 0.5"
    } else if (d.observation) {
        if (d.observation.search("notcrying") != -1)
            return "fill: white; stroke: orange; stroke-opacity: 0.8"
        else
            return "fill: orange; fill-opacity: 0.8"
    } else if (d.name && d.states != null)
        return "fill: black; fill-opacity: 0.5"
    else if (d.name)
        return "fill: black; fill-opacity: 0.8"
}

function texting_cb_node(d) {
    return ""
    if (d.state)
        return d.N
    else if (d.action)
        return d.N
        //return d.r
        //return d.R
}


function coloring_rs_node(d) {
    var children;

    colors_for_observations = {"none": "gray", "good": "green", "bad": "red"}

    if (d.state) {
        style = "fill: purple"
        children = d.actions
    } else if (d.action) {
        if (d.action == "north" || d.action == "south" || d.action == "east" || d.action == "west")
            style = "stroke: blue"
        else if (d.action == "sample")
            style = "stroke: olive"
        else
            style = "stroke: orange"
        children = d.observations
    } else if (d.observation) {
        style = "stroke: " + colors_for_observations[d.observation]
        children = d.states
    } else if (d.name) {
        style = "fill: black"
        children = d.states
    }

    if (children != null)
        style += "; stroke-opacity: 0.5; fill-opacity: 0.5"
    else
        style += "; stroke-opacity: 0.8; fill-opacity: 0.8"

    return style
}

function texting_rs_node(d) {
    return ""
    if (d.state)
        return d.N
    else if (d.action)
        return d.N
        //return d.r
        //return d.R
}


/*
d3.json("mcts.json", function(error, json) {
    tree.children(function (d) { return d.states || d.actions || d.observations; })

    var nodes = tree.nodes(json),
        links = tree.links(nodes);

    var link = svg.selectAll("path.link")
        .data(links)
        .enter()
        .append("g")
        .attr("class", "link");

    link.append("path")
        .attr("d", diagonal);

    link.append("text")
        .attr("dx", 8)
        .attr("transform", function(d) {
            return "translate(" +
                ((d.source.x + d.target.x) / 2) + "," +
                ((d.source.y + d.target.y) / 2) + ")";
        })
        .text(function(d) { return d.target.actionAndObservation; });

    var node = svg.selectAll("g.node")
        .data(nodes)
        .enter()
        .append("g")
        .attr("class", "node")
        .attr("transform", function(d) { return "translate(" + d.x + "," + d.y + ")"; });

    node.append("circle")
        .attr("r", 4.5)
        .attr("style", coloring_cb_node);

    node.append("text")
        .attr("dx", 8)
        .attr("dy", 4)
        .text(texting_cb_node);
});
*/


