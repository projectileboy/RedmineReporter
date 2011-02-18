/*
 * Copyright (c) Kurt Christensen, The Bit Bakery, 2011.
 *
 * Licensed under the Artistic License, Version 2.0 (the "License"); you may not use this
 * file except in compliance with the License. You may obtain a copy of the License at:
 *
 * http://www.opensource.org/licenses/artistic-license-2.0.php
 *
 * Unless required by applicable law or agreed to in writing, software distributed under
 * the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
 * OF ANY KIND, either express or implied. See the License for the specific language
 * governing permissions and limitations under the License.
 */


/**
 * HTML5 Javascript charting library
 */
function drawChartLine(ctxt, originX, originY, xScalingFactor, yScalingFactor, data, color) {
    ctxt.lineWidth = 1.5;
    ctxt.strokeStyle = color;

    data = data.map(function (pt) {return [pt[0]*xScalingFactor + originX, (originY + (ctxt.canvas.height - (2*originY))) -  pt[1]*yScalingFactor]}) ;

    ctxt.moveTo(data[0][0], data[0][1]);
    for (var i = 1; i < data.length; i++) {
        ctxt.lineTo(data[i][0], data[i][1]);
    }

    ctxt.stroke();
    ctxt.beginPath();
}

function drawGrid(ctxt, originX, originY, gridWidth, gridHeight, xScalingFactor, xInterval, yScalingFactor, yInterval) {
    ctxt.lineWidth = 0.65;
    ctxt.strokeStyle = "#bbbbcc";

    ctxt.font = "12px sans-serif";
    ctxt.textBaseline = "top";
    ctxt.textAlign = "center";


    // TODO - For the x-axis labels, Rotating the entire canvas and having it line up correctly on the the underlying grid will require some careful trickery
    // ctx.rotate(Math.PI/12);
    // (and un-rotate when you're done!)

    var xVal = 0;
    for (var x = originX; x < originX + gridWidth; x += (xInterval * xScalingFactor)) {
        ctxt.moveTo(x, originY);
        ctxt.lineTo(x, originY + gridHeight);

        ctxt.fillText(xVal, x, originY + gridHeight + 7)
        xVal += xInterval;
    }


    ctxt.textBaseline = "middle";
    ctxt.textAlign = "right";

    var yVal = 0;
    for (var y = originY + gridHeight; y > originY; y -= (yInterval * yScalingFactor)) {
        ctxt.moveTo(originX, y);
        ctxt.lineTo(originX + gridWidth, y);

        ctxt.fillText(yVal, originX - 7, y)
        yVal += yInterval;
    }
    ctxt.stroke();
    ctxt.beginPath();
}


/**
 * Returns a new array containing the elements of 'data', with each element multiplied by 'scalingFactor'
 */
function scale(scalingFactor, data) {
    return data.map(function (x) {
        return x * scalingFactor;
    });
}


function drawTitle(ctx, canvas, title, xTitle, yTitle) {
    ctx.textBaseline = "top";
    ctx.textAlign = "center";
    ctx.font = "bold 16px sans-serif";
    ctx.fillText(title, canvas.width / 2, 0)

    ctx.textBaseline = "bottom";
    ctx.font = "bold 12px sans-serif";
    ctx.fillText(xTitle, canvas.width / 2, canvas.height - 4);

    // TODO - For the x-axis labels, Rotating the entire canvas and having it line up correctly on the the underlying grid will require some careful trickery
    ctx.textBaseline = "top";
    ctx.font = "bold 12px sans-serif";
    ctx.rotate(-Math.PI/ 2);
    ctx.fillText(yTitle, -canvas.height / 2, 10);
    ctx.rotate(Math.PI / 2 );

}


/**
 * TODO: Generalize to multiple, configurable sets of line data
 */
function drawLineChart(planned, signed, tested) {
    var canvas = document.getElementById("graph");
    var ctx = canvas.getContext("2d");
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.lineWidth = 2;

    // TODO - We should error check some of this, and paint nice error messages on the canvas (e.g., 'Your margins are too big')
    var marginX = 110; // X margin
    var marginY = 75; // Y margin

    var graphWidth = canvas.width - (marginX * 2);
    var graphHeight = canvas.height - (marginY * 2);

    drawTitle(ctx, canvas, "Burnup", "Week", "Ideal Days");

    // TODO - I'm sure there's a built-in Javascript function for this kind of silliness - glurf together 3 bags and get the max val
    var maxX = 0;
    var maxY = 0;
    for (var i = 0; i < planned.length; i++) {
        if (planned[i][0] > maxX) maxX = planned[i][0];
        if (planned[i][1] > maxY) maxY = planned[i][1];
    }
    for (var j = 0; j < signed.length; j++) {
        if (signed[j][0] > maxX) maxX = signed[j][0];
        if (signed[j][1] > maxY) maxY = signed[j][1];
    }
    for (var k = 0; k < tested.length; k++) {
        if (tested[k][0] > maxX) maxX = tested[k][0];
        if (tested[k][1] > maxY) maxY = tested[k][1];
    }

    var xScalingFactor = graphWidth / maxX;
    var yScalingFactor = graphHeight / maxY;

    drawGrid(ctx, marginX, marginY, graphWidth, graphHeight, xScalingFactor, 5, yScalingFactor, 500);

    drawChartLine(ctx, marginX, marginY, xScalingFactor, yScalingFactor, planned, "#ff0000");
    drawChartLine(ctx, marginX, marginY, xScalingFactor, yScalingFactor, signed, "#0000ff");
    drawChartLine(ctx, marginX, marginY, xScalingFactor, yScalingFactor, tested, "#00ff00");


    // TODO - It would be nice to be able to view the canvas as an image in a new window/tab:
    //var img = canvas.toDataURL("image/png");
    //document.write('<img src="'+img+'"/>');
}

