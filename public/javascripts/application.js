/* application javascript */
// --------------------------------------------
function submitStop(e){
    if (!e) var e = window.event;
    if(e.keyCode == 13) return false;
}

// --------------------------------------------
function trim(str){
  return str.replace(/^\s+|\s+$/g, "");
}
// to_s
function to_s(obj){
  if(obj == undefined) return "";
  return obj.toString();
}

// --------------------------------------------
// o make
function index_of(obj, elem)
{
  var objtype = "undefined";
  // check String object
  try {
    obj.charAt(0);
    objtype = "String";
  } catch(ex){ }

  // check Array object
  try {
    var cao = obj.join(",");
    objtype = "Array";
  } catch(ex){ }

  switch(objtype){
  case "Array":
    for(var i = 0; i < obj.length; i++){
      if(obj[i] == elem) return i;
    }
    break;
  case "String":
    return obj.indexOf(elem);
    break;
  }
  return -1;
}

// easy format
function fmt(num, cnt, sp){
    var arrsp = new Array(cnt).fill(sp);
    return (arrsp.join("") + num).substr(-1 * cnt);
}

// HTML Tag emulate :p
// class="blink"
$(function() {
    setInterval(function() {
	$(".blink").css("visibility", $(".blink").css("visibility") == "hidden" ? "visible" : "hidden");
    }, 800);
});

// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// select date functions
function _isLeapYear(year){
    var isLeap = false;
    if((year % 4) == 0) isLeap = true;
    if((year % 100) == 0 && (year % 400) != 0) isLeap = false;
    return isLeap;
}
function _daysOfMonth(year, month){
    var smallmonths = [2, 4, 6, 9, 11];
    var days = 31;
    if(index_of(smallmonths, month) != -1){
	days = 30;
	if(month == 2){
	    days = 28;
	    if(_isLeapYear(year)) days = 29;		
	}
    }
    return days;
}
function _change_select_date(ytag, mtag, dtag, settoday){
    if(settoday == undefined){
	var y = $("#" + ytag).val();
	var m = $("#" + mtag).val();
	
	var days = _daysOfMonth(y, m);
	$("#" + dtag + " > option").remove();
	for(var i = 0; i < days; i++){
	    $("#" + dtag).append($('<option>').val(i + 1).text(i + 1));
	}
    } else {
	var ndate = new Date();
	ndate.setDate(ndate.getDate() + (settoday - 0));
	var ndays = _daysOfMonth(ndate.getFullYear(),
				 ndate.getMonth() + 1);
	$("#" + dtag + " > option").remove();
	for(var i = 0; i < ndays; i++){
	    $("#" + dtag).append($('<option>').val(i + 1).text(i + 1));
	}
	$("#" + ytag).val(ndate.getFullYear());
	$("#" + mtag).val(ndate.getMonth() + 1);
	$("#" + dtag).val(ndate.getDate());
    }
}
