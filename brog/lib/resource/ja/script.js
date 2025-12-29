function confirmDelete() {
	var selNum = checkSelectedItems();
	if (selNum == 0) {
		alert('\u5BFE\u8C61\u304C\u9078\u629E\u3055\u308C\u3066\u3044\u307E\u305B\u3093');
		return false;
	}
	if ( window.confirm('\u524A\u9664\u3057\u3066\u3082\u3088\u308D\u3057\u3044\u3067\u3059\u304B\uFF1F') ) {
		return true;
	} else {
		return false;
	}
}
function confirmDeleteTarget(objTarget) {
	var selNum = 0;
	if (!objTarget) return false;
	for (var i=0;i<objTarget.elements.length;i++) {
		if (objTarget.elements[i].name == 'sel') {
			var obj = objTarget.elements[i];
			if (obj.checked) selNum++;
		}
		if ( objTarget.elements[i].name == '__mode'
		  && objTarget.elements[i].value == 'rebuild') {
			selNum++;
		}
	}
	if (selNum == 0) {
		alert('\u5BFE\u8C61\u304C\u9078\u629E\u3055\u308C\u3066\u3044\u307E\u305B\u3093');
		return false;
	}
	if ( window.confirm('\u524A\u9664\u3057\u3066\u3082\u3088\u308D\u3057\u3044\u3067\u3059\u304B\uFF1F') ) {
		return true;
	} else {
		return false;
	}
}
function confirmAction() {
	var selNum = checkSelectedItems();
	var flag = checkAction();
	if (selNum == 0) {
		alert('\u5BFE\u8C61\u304C\u9078\u629E\u3055\u308C\u3066\u3044\u307E\u305B\u3093');
		return false;
	}
	if (!flag) {
		alert('\u51E6\u7406\u5185\u5BB9\u304C\u9078\u629E\u3055\u308C\u3066\u3044\u307E\u305B\u3093');
		return false;
	}
	if ( window.confirm('\u51E6\u7406\u3092\u5B9F\u884C\u3057\u3066\u3088\u308D\u3057\u3044\u3067\u3059\u304B\uFF1F') ) {
		return true;
	} else {
		return false;
	}
}
function checkSelectedItems() {
	if (document.listform) {
		var selNum = 0;
		for (var i=0;i<document.listform.elements.length;i++) {
			if (document.listform.elements[i].name == 'sel') {
				var obj = document.listform.elements[i];
				if (obj.checked) selNum++;
			}
			if ( document.listform.elements[i].name == 'mid'
			  || document.listform.elements[i].name == 'bid'
			  || document.listform.elements[i].name == 'iid'
			  || document.listform.elements[i].name == 'lid'
			  || document.listform.elements[i].name == 'tid'
			  || document.listform.elements[i].name == 'pid'
			  || document.listform.elements[i].name == 'aid'
			  || document.listform.elements[i].name == 'cid') {
				var obj = document.listform.elements[i];
				if (obj.value != null) selNum++;
			}
		}
		return(selNum);
	} else {
		return(1);
	}
}
function checkAction() {
	var obj = this.document.getElementById('regi_action');
	if (!obj) return true;
	if (obj.value == '') return false;
	return true;
}
function changeHeight(idName, direction) {
	var max = 99;
	var min = 3;
	var obj = this.document.getElementById(idName);
	if (!obj) return false;
	var row = parseInt(obj.getAttribute("rows"));
	if (row > 0) {
		row = row + ( direction * 2);
		if (row < min) row = min;
		if (row > max) row = max;
		obj.setAttribute("rows", row);
		if (window.navigator.userAgent.indexOf('AppleWebKit') > -1) {
			var height = row * 1.1;
			obj.style.height = Array(height,'em').join('');
		}
	}
	return false;
}
function replaceEntity(str) {
	str = str.split("&").join("&amp;");
	str = str.split("<").join("&lt;");
	str = str.split(">").join("&gt;");
	str = str.split('"').join("&quot;");
	str = str.split("{").join("&#123;");
	str = str.split("}").join("&#125;");
	return(str);
}
function reverseEntity(str) {
	str = str.split('&#123;').join("{");
	str = str.split('&#125;').join("}");
	str = str.split("&quot;").join('"');
	str = str.split("&gt;").join(">");
	str = str.split("&lt;").join("<");
	str = str.split("&amp;").join("&");
	return(str);
}
function changeEntity(idName, mode) {
	var obj = this.document.getElementById(idName);
	if (!obj) return false;
	var txtConfirm = (mode) ? '\u30C6\u30AD\u30B9\u30C8\u30A8\u30EA\u30A2\u5185\u306E\u300C\u0026\u002C\u003C\u002C\u003E\u002C\u0022\u300D\u3092\u5B9F\u4F53\u53C2\u7167\u5316\u3057\u307E\u3059\u3002' : '\u30C6\u30AD\u30B9\u30C8\u30A8\u30EA\u30A2\u5185\u306E\u5B9F\u4F53\u53C2\u7167\u6587\u5B57\u3092\u300C\u0026\u002C\u003C\u002C\u003E\u002C\u0022\u300D\u306B\u5909\u63DB\u3057\u307E\u3059\u3002';
	txtConfirm = Array(txtConfirm,"\n\n\u3088\u308D\u3057\u3044\u3067\u3059\u304B\uFF1F").join('');
	if (document.selection) {
		obj.focus();
		var str = document.selection.createRange().text;
		if (str) {
			document.selection.createRange().text = (mode) ? replaceEntity(str) : reverseEntity(str);
		} else if (obj.value && confirm(txtConfirm)) {
			obj.value = (mode) ? replaceEntity(obj.value) : reverseEntity(obj.value);
		}
	} else if ( (obj.selectionEnd - obj.selectionStart) > 0 ) {
		var bgnPos = obj.selectionStart;
		var endPos = obj.selectionEnd;
		var bfrStr = obj.value.substring(0, bgnPos);
		var fcsStr = (mode) ? replaceEntity(obj.value.substring(bgnPos, endPos)) : reverseEntity(obj.value.substring(bgnPos, endPos));
		var difLen = fcsStr.length - (endPos - bgnPos);
		var aftStr = obj.value.substring(endPos, obj.value.length);
		obj.value = Array(bfrStr,fcsStr,aftStr).join('');
		obj.setSelectionRange(bgnPos,endPos + difLen);
	} else if (obj.value) {
		if (confirm(txtConfirm)) {
			obj.value = (mode) ? replaceEntity(obj.value) : reverseEntity(obj.value);
		}
	}
	return false;
}
function addHtmlTag(idName, tag, option) {
	var obj = this.document.getElementById(idName);
	if (!obj) return false;
	if (option && option.lastIndexOf('/') == (option.length - 1))
		return addText(idName,Array('<',tag,' ',option,'>').join(''));
	var bgnTag = (!option) ? Array('<',tag,'>').join('') : Array('<',tag,' ',option,'>').join('');
	var endTag = Array('</',tag,'>').join('');
	if (document.selection) {
		obj.focus();
		var str = document.selection.createRange().text;
		document.selection.createRange().text = Array(bgnTag,str,endTag).join('');
	} else if ( (obj.selectionEnd - obj.selectionStart) >= 0 ) {
		var bgnPos = obj.selectionStart;
		var endPos = obj.selectionEnd;
		var bfrStr = obj.value.substring(0, bgnPos);
		var fcsStr = Array(bgnTag,obj.value.substring(bgnPos, endPos),endTag).join('');
		var difLen = fcsStr.length - (endPos - bgnPos);
		var aftStr = obj.value.substring(endPos, obj.value.length);
		obj.value = Array(bfrStr,fcsStr,aftStr).join('');
		obj.setSelectionRange(bgnPos,endPos + difLen);
	} else {
		obj.value = Array(obj.value,bgnTag,endTag).join('');
	}
	return false;
}
function addLink(idName) {
	var url = prompt('\u30EA\u30F3\u30AF\u3059\u308B\u30B5\u30A4\u30C8\u306E\u0055\u0052\u004C\u3092\u5165\u529B\u3057\u3066\u304F\u3060\u3055\u3044\u3002', 'http://');
	var target = prompt('\u0074\u0061\u0072\u0067\u0065\u0074\u5C5E\u6027\u3092\u6307\u5B9A\u3057\u3066\u304F\u3060\u3055\u3044', '_blank');
	var title = prompt('\u0074\u0069\u0074\u006C\u0065\u5C5E\u6027\u3092\u6307\u5B9A\u3057\u3066\u304F\u3060\u3055\u3044','');
	if (url == null || target == null || title == null) return false;
	if (url == '' || url == 'http://') return false;
	var option = Array('href="',url,'"').join('');
	if (target != '') option = Array(option,' target="',target,'"').join('');
	if (title != '') option = Array(option,' title="',title,'"').join('');
	addHtmlTag(idName, 'a', option);
}
function addText(idName,val) {
	var obj = this.document.getElementById(idName);
	if (!obj) return false;
	if (val == '') return false;
	if (document.selection) {
		obj.focus();
		var str = document.selection.createRange().text;
		if (!str) {
			document.selection.createRange().text = Array(val).join('');
		} else {
			obj.value = Array(obj.value,val).join('');
		}
	} else if ( (obj.selectionEnd - obj.selectionStart) == 0 ) {
		var bgnPos = obj.selectionStart;
		var endPos = obj.selectionEnd;
		var bfrStr = obj.value.substring(0, bgnPos);
		var fcsStr = Array(val).join('');
		var difLen = fcsStr.length;
		var aftStr = obj.value.substring(endPos, obj.value.length);
		obj.value = Array(bfrStr,fcsStr,aftStr).join('');
		obj.setSelectionRange(bgnPos,endPos + difLen);
	} else {
		obj.value = Array(obj.value,val).join('');
	}
	return false;
}
function switchAll(obj) {
	if (obj.checked) {
		selectAllList();
	} else {
		clearAllList();
	}
}
function switchAllTarget(obj,objTarget) {
	if (obj.checked) {
		selectAllList(objTarget);
	} else {
		clearAllList(objTarget);
	}
}
function switchList(obj) {
	if (obj.checked) {
		selectList(obj);
	} else {
		clearList(obj);
	}
}
function selectType(str) {
	if (!str) return;
	var num = 0;
	for (var i=0;i<document.listform.elements.length;i++) {
		if (document.listform.elements[i].name == 'sel') {
			var obj = document.listform.elements[i];
			var parentObj = null;
			if (obj.parentNode) {
				parentObj = obj.parentNode;
			} else if (obj.parentElement) {
				parentObj = obj.parentElement;
			}
			if (parentObj) {
				if (parentObj.className.indexOf(str) > -1) {
					num++;
					selectList(obj);
				} else {
					clearList(obj);
				}
			}
		}
	}
	var obj = this.document.getElementById('showSelected');
	if (obj) obj.innerHTML = num;
}
function selectAllList(objList) {
	if (!objList) objList = document.listform
	if (!objList) return;
	var obj = this.document.getElementById('showSelected');
	if (obj) obj.innerHTML = 0;
	for (var i=0;i < objList.elements.length;i++) {
		if (objList.elements[i].name == 'sel') {
			selectList(objList.elements[i]);
		}
	}
	objList.selectAll.checked = true;
}
function clearAllList(objList) {
	if (!objList) objList = document.listform
	if (!objList) return;
	for (var i=0;i < objList.elements.length;i++) {
		if (objList.elements[i].name == 'sel') {
			clearList(objList.elements[i]);
		}
	}
	objList.selectAll.checked = false;
	if (objList.typeselect) document.listform.typeselect.selectedIndex = 0;
}
function selectList(obj) {
	obj.checked = true;
	var parentObj = null;
	if (obj.parentNode && obj.parentNode.parentNode && obj.parentNode.parentNode.parentNode) {
		parentObj = obj.parentNode.parentNode.parentNode;
	} else if (obj.parentElement && obj.parentElement.parentElement && obj.parentElement.parentElement.parentElement) {
		parentObj = obj.parentElement.parentElement.parentElement;
	}
	if (parentObj) {
		if (parentObj.className == 'odd') {
			parentObj.className = 'selected_odd';
		} else if (parentObj.className == 'even') {
			parentObj.className = 'selected_even';
		}
	}
	displaySelectedNumber(+1);
}
function clearList(obj) {
	obj.checked = false;
	var parentObj = null;
	if (obj.parentNode && obj.parentNode.parentNode && obj.parentNode.parentNode.parentNode) {
		parentObj = obj.parentNode.parentNode.parentNode;
	} else if (obj.parentElement && obj.parentElement.parentElement && obj.parentElement.parentElement.parentElement) {
		parentObj = obj.parentElement.parentElement.parentElement;
	}
	if (parentObj) {
		if (parentObj.className == 'selected_odd') {
			parentObj.className = 'odd';
		} else if (parentObj.className == 'selected_even') {
			parentObj.className = 'even';
		}
	}
	displaySelectedNumber(-1);
}
function displaySelectedNumber(diff) {
	var obj = this.document.getElementById('showSelected');
	if (obj) {
		var selNum = parseInt(obj.innerHTML);
		selNum = selNum + diff;
		if (selNum < 0) selNum = 0;
		obj.innerHTML = selNum;
	}
}
function toggleVisible(idName,objThis,orgValue) {
	var obj = this.document.getElementById(idName);
	if (!obj) return false;
	if (obj.style.display == 'none') {
		obj.style.display = 'block';
		if (objThis)
			objThis.value = '\u96A0\u3059';
	} else {
		obj.style.display = 'none';
		if (objThis)
			objThis.value = orgValue;
	}
	return false;
}
function showForm(idName) {
	var obj = this.document.getElementById(idName);
	if (!obj) return false;
	obj.style.display = 'block';
	window.location.hash = idName;
	var objForm = this.document.getElementById('upload_file0');
	if (!objForm) return;
	objForm.focus();
	return;
}
function setNowTime() {
	var nowTime = new Date();
	var yr = nowTime.getYear();
	var mo = nowTime.getMonth()+1;
	var dy = nowTime.getDate();
	var ho = nowTime.getHours();
	var mi = nowTime.getMinutes();
	var sc = nowTime.getSeconds();
	var form = document.mainform;
	form.entry_date_yr.value = (yr < 2000) ? yr + 1900 : yr;
	form.entry_date_mo.value = (mo < 10) ? '0' + mo : mo;
	form.entry_date_dy.value = (dy < 10) ? '0' + dy : dy;
	form.entry_date_ho.value = (ho < 10) ? '0' + ho : ho;
	form.entry_date_mi.value = (mi < 10) ? '0' + mi : mi;
	form.entry_date_sc.value = (sc < 10) ? '0' + sc : sc;
	return;
}
function sbit(txt_subj,txt_url,txt_body) {
	if (txt_subj.length > 0) {
		var obj = this.document.getElementById('entry_title');
		txt_subj = txt_subj.split("\n").join("");
		obj.value = Array('Re: ',unescape(txt_subj)).join('');
	}
	if (txt_body.length > 0) {
		var obj = this.document.getElementById('entry_body');
		obj.value = Array(obj.value,'<blockquote><p>',unescape(txt_body),'</p></blockquote>').join('');
	}
	if (txt_url.length > 0 && txt_subj.length > 0) {
		var obj = this.document.getElementById('entry_body');
		obj.value = Array(obj.value,'<p class="source"><cite><a href="',unescape(txt_url),'">',unescape(txt_subj),'</a></cite></p>\n').join('');
	}
}
function insertUploadForm(buttonId,formId) {
	var button = document.getElementById(buttonId);
	var upForm = document.getElementById(formId);
	var parentObj = null;
	if (button.parentNode && button.parentNode.parentNode) {
		parentObj = button.parentNode.parentNode;
	} else if (button.parentElement && button.parentElement.parentElement) {
		parentObj = button.parentElement.parentElement;
	}
	parentObj.appendChild(upForm);
	upForm.style.display = 'block';
	var targetParam = document.getElementById('insert_target');
	if (targetParam) targetParam.value = (buttonId == 'insertMore') ? 'more' : 'body';
}

var checkOption = true;
var currentOption = null;
var allCategories = new Array();

function showCategorySelector(showName,hideName) {
	var objButton   = document.getElementById('show_category');
	var objForm     = document.getElementById('multi_category');
	var objCategory = document.getElementById('entry_category');
	var objMulti    = document.getElementById('entry_multicat');
	if (objForm.style.display == 'none') {
		objForm.style.display = 'block';
		objButton.value = hideName;
	} else {
		objForm.style.display = 'none';
		objButton.value = showName;
	}
	if (checkOption) {
		for (var i=0;i<objCategory.options.length;i++) {
			allCategories[i] = new Array();
			allCategories[i].text    = objCategory.options[i].text;
			allCategories[i].value   = objCategory.options[i].value;
			allCategories[i].inMulti = false;
			if (objCategory.options[i].selected) currentOption = i;
		}
		for (i=0;i<allCategories.length;i++) {
			for (var j=0;j<objMulti.options.length;j++) {
				if (allCategories[i].value != objMulti.options[j].value) continue;
				objMulti.options[j].text = allCategories[i].text;
				allCategories[i].inMulti = true;
			}
		}
		checkOption = false;
	}
	changeOption();
}
function changeOption() {
	var objCategory = document.getElementById('entry_category');
	var objSelector = document.getElementById('category_selector');
	var objMulti    = document.getElementById('entry_multicat');
	for (var i=0;i<objCategory.options.length;i++) {
		if (objCategory.options[i].selected) currentOption = i;
	}
	objSelector.options.length = 0;
	objMulti.options.length = 0;
	for (var i=0;i<allCategories.length;i++) {
		if (i == currentOption) {
			allCategories[i].inMulti = false;
			continue;
		}
		if (allCategories[i].value == 'none') continue;
		var num;
		if (allCategories[i].inMulti) {
			num = objMulti.options.length;
			objMulti.options[num] = new Option;
			objMulti.options[num].text  = allCategories[i].text;
			objMulti.options[num].value = allCategories[i].value;
			objMulti.options[num].setAttribute("title", allCategories[i].text);
		} else {
			num = objSelector.options.length;
			objSelector.options[num] = new Option;
			objSelector.options[num].text  = allCategories[i].text;
			objSelector.options[num].value = allCategories[i].value;
			objSelector.options[num].setAttribute("title", allCategories[i].text);
		}
	}
}
function addCategories(maxNum) {
	var checkNum = 0;
	var objSelector = document.getElementById('category_selector');
	for (var i=0;i<allCategories.length;i++) {
		if (allCategories[i].inMulti) checkNum++;
	}
	var addCat = new Array();
	for (var i=0;i<objSelector.options.length;i++) {
		if (maxNum > 0 && addCat.length >= (maxNum - checkNum)) break;
		if (objSelector.options[i].selected) addCat[addCat.length] = objSelector.options[i].value;
	}
	for (var i=0;i<allCategories.length;i++) {
		for (var j=0;j<addCat.length;j++)
			if (addCat[j] == allCategories[i].value) allCategories[i].inMulti = true;
	}
	changeOption();
}
function removeCategories() {
	var objMulti = document.getElementById('entry_multicat');
	for (i=0;i<allCategories.length;i++) {
		for (var j=0;j<objMulti.options.length;j++) {
			if (allCategories[i].value != objMulti.options[j].value) continue;
			if (objMulti.options[j].selected) allCategories[i].inMulti = false;
		}
	}
	changeOption();
}
function selectAllCategories(idName) {
	var catSel = document.getElementById('entry_multicat');
	for (var i=0;i<catSel.options.length;i++) {
		catSel.options[i].selected = true;
	}
}
function changeIcon(baseUrl,iconUrl,idName) {
	var objIcon = document.getElementById(idName);
	if (objIcon) {
		objIcon.setAttribute("src", baseUrl + iconUrl + '.gif');
	}
}
var sbTimeSet = new Array();
initTimeSet();
function changeDateSet(setName) {
	if (setName == '') return false;
	document.getElementById('entry_date').value  = sbTimeSet[setName].entry_date;
	document.getElementById('entry_time').value  = sbTimeSet[setName].entry_time;
	document.getElementById('msg_time').value    = sbTimeSet[setName].msg_time;
	document.getElementById('dateinlist').value  = sbTimeSet[setName].dateinlist;
	document.getElementById('archivelist').value = sbTimeSet[setName].archivelist;
	var selLang = document.getElementById('time_lang');
	for (var i=0;i<selLang.options.length;i++) {
		if (selLang[i].value == sbTimeSet[setName].time_lang) selLang[i].selected = true;
	}
}
function initTimeSet() {
	sbTimeSet['default'] = new Array();
	sbTimeSet['default'].entry_date  = '%Year%.%Mon%.%Day% %WeekLong%';
	sbTimeSet['default'].entry_time  = '%Hour%:%Min%';
	sbTimeSet['default'].msg_time    = '%Year%/%Mon%/%Day% %Hour12%:%Min% %HourAP%';
	sbTimeSet['default'].dateinlist  = ' (%Mon%/%Day%)';
	sbTimeSet['default'].archivelist = '%MonLong% %Year%';
	sbTimeSet['default'].time_lang   = 'en';

	sbTimeSet['EngLong'] = new Array();
	sbTimeSet['EngLong'].entry_date  = '%WeekLong% %DayOrd% %MonLong% %Year%';
	sbTimeSet['EngLong'].entry_time  = '%Hour%:%Min%';
	sbTimeSet['EngLong'].msg_time    = '%Week% %Day%/%Mon%/%Year% %Hour%:%Min%';
	sbTimeSet['EngLong'].dateinlist  = ' (%Mon%/%Day%)';
	sbTimeSet['EngLong'].archivelist = '%MonLong% %Year%';
	sbTimeSet['EngLong'].time_lang   = 'en';

	sbTimeSet['EngShrt'] = new Array();
	sbTimeSet['EngShrt'].entry_date  = '%Week% %Day% %MonShort% %Year%';
	sbTimeSet['EngShrt'].entry_time  = '%Hour%:%Min%';
	sbTimeSet['EngShrt'].msg_time    = '%Week% %Day%/%Mon%/%Year% %Hour%:%Min%';
	sbTimeSet['EngShrt'].dateinlist  = ' (%Mon%/%Day%)';
	sbTimeSet['EngShrt'].archivelist = '%MonLong% %Year%';
	sbTimeSet['EngShrt'].time_lang   = 'en';

	sbTimeSet['French'] = new Array();
	sbTimeSet['French'].entry_date  = '%WeekLong% %Day% %MonLong% %Year%';
	sbTimeSet['French'].entry_time  = '%Hour%:%Min%';
	sbTimeSet['French'].msg_time    = '%Week% %Day%/%Mon%/%Year% %Hour%:%Min%';
	sbTimeSet['French'].dateinlist  = ' (%Mon%/%Day%)';
	sbTimeSet['French'].archivelist = '%MonLong% %Year%';
	sbTimeSet['French'].time_lang   = 'fr';

	sbTimeSet['EngNum'] = new Array();
	sbTimeSet['EngNum'].entry_date  = '%Year%/%Mon%/%Day% %Week%';
	sbTimeSet['EngNum'].entry_time  = '%Hour%:%Min%';
	sbTimeSet['EngNum'].msg_time    = '%Year%/%Mon%/%Day%  %Hour%:%Min%';
	sbTimeSet['EngNum'].dateinlist  = ' (%Mon%/%Day%)';
	sbTimeSet['EngNum'].archivelist = '%MonLong% %Year%';
	sbTimeSet['EngNum'].time_lang   = 'en';

	sbTimeSet['JpnNum'] = new Array();
	sbTimeSet['JpnNum'].entry_date  = '%Year%/%Mon%/%Day% %Week%';
	sbTimeSet['JpnNum'].entry_time  = '%Hour%:%Min%';
	sbTimeSet['JpnNum'].msg_time    = '%Year%/%Mon%/%Day%  %Hour%:%Min%';
	sbTimeSet['JpnNum'].dateinlist  = ' (%Mon%/%Day%)';
	sbTimeSet['JpnNum'].archivelist = '%Year%/%Mon%';
	sbTimeSet['JpnNum'].time_lang   = 'ja';

	sbTimeSet['LstYear'] = new Array();
	sbTimeSet['LstYear'].entry_date  = '%Year%/%Mon%/%Day% %Week%';
	sbTimeSet['LstYear'].entry_time  = '%Hour%:%Min%';
	sbTimeSet['LstYear'].msg_time    = '%Year%/%Mon%/%Day%  %Hour%:%Min%';
	sbTimeSet['LstYear'].dateinlist  = ' (%Year%/%Mon%/%Day%)';
	sbTimeSet['LstYear'].archivelist = '%MonLong% %Year%';
	sbTimeSet['LstYear'].time_lang   = 'en';

	sbTimeSet['LstNone'] = new Array();
	sbTimeSet['LstNone'].entry_date  = '%Year%/%Mon%/%Day% %Week%';
	sbTimeSet['LstNone'].entry_time  = '%Hour%:%Min%';
	sbTimeSet['LstNone'].msg_time    = '%Year%/%Mon%/%Day%  %Hour%:%Min%';
	sbTimeSet['LstNone'].dateinlist  = '';
	sbTimeSet['LstNone'].archivelist = '%MonLong% %Year%';
	sbTimeSet['LstNone'].time_lang   = 'en';
}
function changeEditLink(targetName,baseUrl,tmpId) {
	var obj = document.getElementById(targetName);
	if (obj) {
		var linkUrl = baseUrl;
		if (tmpId > -1) linkUrl = Array(baseUrl,'&tid=',tmpId).join('');
		obj.setAttribute("href",linkUrl);
	}
}
var sbRebuildTime = null;
var sbRebuildFlag = false;
function rebuildAll(num,max) {
	if (max == 0) return false;
	if (!sbRebuildFlag) {
		document.getElementById('rebuildOptionField').style.display = 'none';
		document.getElementById('rebuildStatusField').style.display = 'block';
		sbRebuildFlag = true;
	}
	var xmlObj = initXmlRequest();
	if (xmlObj) {
		xmlObj.onreadystatechange = function() {
			if (xmlObj.readyState == 4 && xmlObj.status == 200) {
				var percent = Math.floor((num / max) * 100);
				var content = xmlObj.responseXML;
				if (content) {
					var result  = content.getElementsByTagName('result');
					if (result.length) {
						var check = result[0].firstChild.nodeValue;
						if (check == 1 && num <= max) {
							document.getElementById('rebuildProgress').innerHTML   = percent + ' %';
							document.getElementById('rebuildProgress').style.width = (percent * 4) + 'px';
							num++;
							if (sbRebuildTime != null) window.clearTimeout(sbRebuildTime);
							sbRebuildTime = window.setTimeout("rebuildAll(" + num + "," + max + ")",100);
						} else if (check != 1) {
							document.getElementById('rebuildProgress').innerHTML   = '<strong>' + check + '</strong>';
							document.getElementById('rebuildProgress').style.width = '400px';
							if (check == 'completed') {
								document.getElementById('explainComplete').style.display = 'block';
								document.getElementById('explainProgress').style.display = 'none';
							}
						}
					} else { // result.length == 0
						document.getElementById('rebuildProgress').innerHTML = '<strong>error no result</strong>';
					}
				} else { // content == null
					document.getElementById('rebuildProgress').innerHTML = '<strong>error no content</strong>';
				}
			} // end of if (xmlObj.readyState == 4 && xmlObj.status == 200)
		} // function
		xmlObj.open('GET','admin.cgi?__rebuild=' + num);
		xmlObj.send(null);
	} // end of if (xmlObj)
}
function initXmlRequest() {
	var obj = null
	try {
		obj = new ActiveXObject("Msxml2.XMLHTTP");
	} catch(e) {
		try {
			obj = new ActiveXObject("Microsoft.XMLHTTP");
		} catch(e) {
			obj = null;
		}
	}
	if (!obj && typeof XMLHttpRequest != 'undefined') {
		obj = new XMLHttpRequest();
	}
	return obj;
}
function initRebuildField() {
	var xmlObj = initXmlRequest();
	if (xmlObj) {
		xmlObj.onreadystatechange = function() {
			if (xmlObj.readyState == 4 && xmlObj.status == 200) {
				var content = xmlObj.responseXML;
				if (content) {
					var result  = content.getElementsByTagName('result');
					if (result.length) {
						var check = result[0].firstChild.nodeValue;
						if (check == 1) {
							var button = document.getElementById('optionalRebuild');
							if (button) button.style.display = 'inline';
							var selObj = document.getElementById('rebuild_option');
							if (selObj && selObj.options) {
								var idxOpt = new Option;
								idxOpt = selObj.options[1];
								for (var i=0;i<selObj.options.length;i++)
									selObj.options[i] = null;
								selObj.options[0] = idxOpt;
								selObj.length = 1;
							}
						} // end of if (check == 1)
					} // end of if (result.length)
				} // end of if (content)
			} // end of if (xmlObj.readyState == 4 && xmlObj.status == 200)
		} // function
		xmlObj.open('GET','admin.cgi?__rebuild=-1');
		xmlObj.send(null);
	} // end of if (xmlObj)
}

