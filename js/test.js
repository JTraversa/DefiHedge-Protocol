
function toggleText() {
    var x = document.getElementById("Rate").value;
    var y = document.getElementById("Duration").value;
    var z = document.getElementById("Token").value;
    var w = document.getElementById("Supplied").value;
    document.getElementById("outputRate").innerHTML = x;
    document.getElementById("outputDuration").innerHTML = y;
    document.getElementById("outputToken").innerHTML = z;
    document.getElementById("outputSupply").innerHTML = w;
}
