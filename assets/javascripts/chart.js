/**
 * Created by IntelliJ IDEA.
 * User: kurtc
 * Date: 1/31/11
 * Time: 5:16 PM
 * To change this template use File | Settings | File Templates.
 */

/**
 * HTML5 Javascript charting library
 */
function drawChartLine(ctxt, originX, originY, xData, yData, color) {
    ctxt.lineWidth = 1.5;
    ctxt.strokeStyle = "#332222";

    ctxt.moveTo(xData[0] +originX, yData[0]+originY);
    for (var i = 1; i < xData.length && i < yData.length; i++) {
        ctxt.lineTo(xData[i]+originX, yData[i]+originY);
    }

    ctxt.strokeStyle=color;
    ctxt.stroke();
    ctxt.beginPath();
}

function drawGrid(ctxt, originX, originY, gridWidth, gridHeight, xInterval, yInterval) {
    ctxt.lineWidth = 0.6;
    ctxt.strokeStyle = "#ccccee";

    for (var x = originX; x < originX + gridWidth; x += xInterval) {
        ctxt.moveTo(x, originY);
        ctxt.lineTo(x, originY + gridHeight);
    }

    for (var y = originY; y < originY + gridHeight; y += yInterval) {
        ctxt.moveTo(originX, y);
        ctxt.lineTo(originX + gridWidth, y);
    }
    ctxt.stroke();
    ctxt.beginPath();
}


/**
 * Find the scaling factor for a set of data, so that the data will fit nicely within 'bound'
 */
function getScalingFactor(bound, data) {
    return bound / Math.max.apply(Math, data);
}

/**
 * Returns a new array containing the elements of 'data', with each element multiplied by 'scalingFactor'
 */
function scale(scalingFactor, data) {
    return data.map(function (x) {return x * scalingFactor;});
}


function drawTitle(ctx, canvas, text) {
    ctx.textBaseline = "top";
    ctx.textAlign = "center";
    ctx.font = "bold 16px sans-serif";
    ctx.fillText(text, canvas.width / 2, 0)
}

function drawLabelsX(ctx, x, y, text) {
//    ctx.textBaseline = "left";
//    ctx.textAlign = "right";
    ctx.font = "bold 20px sans-serif";

    // TODO - Rotating the entire canvas and having it line up correctly on the the underlying grid will require some careful trickery
    // ctx.rotate(Math.PI/12);

    ctx.fillText(text, 150, 150);

    // ctx.rotate(-Math.PI/12); // Remember to rotate the canvas back before we draw anything else!
}


/**
 * Expects array of x-data as first argument, followed by one or more corresponding arrays of y-data
 */
function drawLineChart() {
    var canvas = document.getElementById("graph");
    var ctx = canvas.getContext("2d");
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.lineWidth = 2;

    // TODO - We should error check some of this, and paint nice error messages on the canvas (e.g., 'Your margins are too big')
    var marginX = 50; // X margin
    var marginY = 50; // Y margin

    var graphWidth = canvas.width - (marginX * 2);
    var graphHeight = canvas.height - (marginY * 2);

    drawTitle(ctx, canvas, "Burnup");

    // TODO - Make me real
    //drawLabelsX(ctx, 20, canvas.height - graphY, "TEST");

    var xScalingFactor = getScalingFactor(graphWidth, arguments[0]);
    var xData = scale(xScalingFactor, arguments[0]);

    var allY = [];
    for (var y = 1; y < arguments.length; y++) {
        allY = allY.concat(arguments[y]);
    }
    var yScalingFactor = getScalingFactor(graphHeight, allY);


    drawGrid(ctx, marginX, marginY, graphWidth, graphHeight, 20 * xScalingFactor, 20 * yScalingFactor);

    for (var i = 1  ; i < arguments.length; i++) {
        drawChartLine(ctx, marginX, marginY, xData, scale(yScalingFactor, arguments[i]), "#ff0000");
    }


    // This code will export the chart as an image:
    //var img = canvas.toDataURL("image/png");
    //document.write('<img src="'+img+'"/>');
}

