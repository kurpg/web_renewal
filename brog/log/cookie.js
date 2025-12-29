var cookie = document.cookie.split(';');
var form_value = new Array();
var form_flag = false;
for (var i=0;i<cookie.length;i++) {
	var cook_val = cookie[i].split('=');
	if (cook_val[0].indexOf('sbviewer') > -1) {
		var cook_detail = cook_val[1].split(',');
		for (var j=0;j<cook_detail.length;j++) {
			if (cook_detail[j].length > 0) {
				var key = cook_detail[j].split('<>');
				key[1] = decodeURIComponent(key[1]);
				form_value[key[0]] = key[1];
				form_flag = true;
			}
		}
	}
}
var form_tag = document.getElementsByTagName('input');
for (var i=0;i<form_tag.length;i++) {
	var name = form_tag[i].getAttribute('name');
	if (name) {
		if (name.indexOf('set_cookie') > -1) {
			if (form_flag) form_tag[i].checked = true;
		} else {
			for (var j in form_value) {
				if (name.indexOf(j) > -1) {
					var check = form_tag[i].getAttribute('value');
					if (!check || check.length == 0) form_tag[i].setAttribute('value',form_value[j]);
				}
			}
			
		}
	}
}
var form_icon = document.getElementsByTagName('select');
for (var i=0;i<form_icon.length;i++) {
	var name = form_icon[i].getAttribute('name');
	if (name.indexOf('icon') > -1) {
		var icon_sel = form_icon[i].options;
		for (var j=0;j<icon_sel.length;j++) {
			if (icon_sel[j].value == form_value.icon) {
				icon_sel[j].selected = true;
				previewCommentIcon(form_value.icon);
			}
		}
	}
}
function previewCommentIcon(id) {
	var objDiv = this.document.getElementById('icon_form');
	if (!objDiv) return false;
	var imgSrc = '';
	switch (id) {

	default: break;
	};
	var objPre = objDiv.getElementsByTagName('span');
	if (objPre.length == 1) {
		objPre[0].innerHTML = (imgSrc != '') ? Array('<img src="',imgSrc,'" />').join('') : '[icon]';
	}
	return;
}
