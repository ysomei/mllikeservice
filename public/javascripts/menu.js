/* menu javascript */
function Menu() {}
var Menu = function () {this.init();};

Menu.prototype = {
    init: function() {
    },

    add_new_ml: function() {
	var f = $("#add_form");
	var mailaddr = trim($("#mailaddr").val());
	var smtpsrv = trim($("#smtpsrv").val());
	var acnt = trim($("#account").val());
	var passwd = trim($("#passwd").val());

	if(mailaddr == "" || smtpsrv == "" || acnt == "" || passwd == ""){
	    alert("Please input there parameters.");
	    return false;
	}
	f.submit();
    },

    // -----------------------------------------------------------------------
    update_settings: function() {
	var mladdr = $("#mladdr").val();
	var mlname = $("#mlname").val();
	var smtpsrv = $("#smtpserver").val();
	var rcvtype = $("#rcvtype").val();
	var acnt = $("#account").val();
	var passwd = $("#password").val();

	$.post(root_path + "/update_settings",
	       { mladdr: mladdr,
		 mlname: mlname,
		 smtpsrv: smtpsrv,
		 rcvtype: rcvtype,
		 acnt: acnt,
		 passwd: passwd },
	       function(html){
		   alert("update done.");
		   $("#ml_settings").html(html);
	       });
    },

    add_new_user: function() {
	var mladdr = $("#mladdr").val();
	var uname = trim($("#uname").val());
	var umail = trim($("#umail").val());
	if(umail == ""){
	    alert("Please input user mailaddress.");
	    return false;
	}

	$.post(root_path + "/add_new_user",
	       { mladdr: mladdr,
		 umail: umail,
		 uname: uname },
	       function(html){
		   $("#ml_users").html(html);
	       });
    },

    show_edit_userinfo: function(pno) {
	$("#mailarea_" + pno).hide();
	$("#maileditarea_" + pno).show();
	$("#namearea_" + pno).hide();
	$("#nameeditarea_" + pno).show();
	$("#btnarea_" + pno).hide();
	$("#btneditarea_" + pno).show();
    },
    hide_edit_userinfo: function(pno) {
	$("#maileditarea_" + pno).hide();
	$("#mailarea_" + pno).show();
	$("#nameeditarea_" + pno).hide();	
	$("#namearea_" + pno).show();
	$("#btneditarea_" + pno).hide();
	$("#btnarea_" + pno).show();
    },
    
    edit_userinfo: function(pno) {
	menu.show_edit_userinfo(pno);
    },
    update_userinfo: function(pno) {
	var mladdr = $("#mladdr").val();
	var newmail = trim($("#newmail_" + pno).val());
	var newname = trim($("#newname_" + pno).val());
	var orgmail = trim($("#mailarea_" + pno).html());
	var orgname = trim($("#namearea_" + pno).html());
	if(newmail != orgmail || newname != orgname){
	    $.post(root_path + "/update_userinfo",
		   { mladdr: mladdr,
		     pno: pno,
		     newmail: newmail,
		     newname: newname },
		   function(html){
		       $("#mailarea_" + pno).html(newmail);
		       $("#namearea_" + pno).html(newname);
		       menu.hide_edit_userinfo(pno);
		   });
	} else {
	    menu.hide_edit_userinfo(pno);
	}
    }
    
};

var menu = new Menu;
