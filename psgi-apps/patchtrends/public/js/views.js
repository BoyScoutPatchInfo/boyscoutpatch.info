var count = 1;
var beginDate;
var endDate;
var calendar;

function loadImg (itemId) {
    if (isOneTimePass) {
        document.getElementById(itemId).innerHTML = '<a href=# onClick="alert(\'Upgrade for large image view!\'); return false"><img border=0 src=/cgi-bin/item/image/otp/' + itemId + ' ></a><sup>[<a href=# onClick="unloadImg('+itemId+'); return false">X</a>]</sup>';
    }
    else {
        document.getElementById(itemId).innerHTML = '<a href=/cgi-bin/item/image/' + itemId +' target=' + itemId + '><img src=/cgi-bin/item/image/sm/' + itemId + ' ></a><sup>[<a href=# onClick="unloadImg('+itemId+'); return false">X</a>]</sup>';
    }
    return;
}

function unloadImg (itemId) {
    document.getElementById(itemId).innerHTML = '<a href=# onClick="loadImg('+itemId+'); return false">show</a>';
    return;
}

function loadChecked() {
  var checkboxes = document.getElementsByName('loadImg');
  for(var i=0, n=checkboxes.length;i<n;i++) {
      if (checkboxes[i].checked) {
        loadImg(checkboxes[i].value);
      }
  }
}

function unloadChecked() {
  var checkboxes = document.getElementsByName('loadImg');
  for(var i=0, n=checkboxes.length;i<n;i++) {
      if (checkboxes[i].checked) {
        unloadImg(checkboxes[i].value);
      }
  }
}

function unCheckAll() {
  var checkboxes = document.getElementsByName('loadImg');
  for(var i=0, n=checkboxes.length;i<n;i++) {
      if (checkboxes[i].checked) {
        unloadImg(checkboxes[i].value);
        checkboxes[i].checked = false;
      }
  }
}

function checkAll() {
  var checkboxes = document.getElementsByName('loadImg');
  for(var i=0, n=checkboxes.length;i<n;i++) {
    checkboxes[i].checked = true;
  }
}

function toggle(showHideDiv, switchTextDiv, showText, hideText) {
    var ele = document.getElementById(showHideDiv);
    var text = document.getElementById(switchTextDiv);
    if(ele.style.display == "block") {
        ele.style.display = "none";
        text.innerHTML = showText;
    }
    else {
        ele.style.display = "block";
        text.innerHTML = hideText;
    }
    return;
} 

YUI.add('data-search-view', function(Y) {
    var currency = function(o) {
        var val = parseFloat(o.value).toFixed(2);
        return '$' + val;
    };

    var sortCurrency = function (a, b, desc) {
            var aPrice   = parseFloat(a.get('currentprice')),
                bPrice   = parseFloat(b.get('currentPrice')),
                order = // existing records are equivalent
                        (aPrice === bPrice) ? 0 :
                        // new records are grouped apart from existing records
                        (aPrice && -1) || (bPrice && 1) ||
                        // new records are sorted by insertion order
                        (aPrice > bPrice) ? 1 : -(aPrice < bPrice);
                return desc ? -order : order;
    };

    var isSold = function (o) {
        if (o.value == "yes" || o.value == "no") {
            return o.value;
        }
        else {
            return o.value;
        }
    };

    var itemDate = function (o) {
        var date = Y.Date.parse(o.value*1000);
        //var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        var year = date.getFullYear();
        //var month = months[date.getMonth()];
        var month = date.getMonth()+1;
        var date = date.getDate();
        return month + '/' + date + '/' + year;
    };

    var toggleEPN = function (o) {
        var url = "http://www.patchtrends.com/cgi-bin/index/ebay/" + o.value;
        return '<a href=' + url + ' target=_other>link</a>';
    }

    var toggleEPNImage = function (o) {
        var url = "http://www.patchtrends.com/cgi-bin/index/ebay/" + o.value;
        return '<a href=' + url + ' target=_other><img src=http://www.patchtrends.com/cgi-bin/item/image/micro/' + o.value + '></a>';
    }

    YUI().use('calendar', 'datatype-date', 'datatype-date-math', function(Y) {
     // Switch the calendar main template to the included two pane template
     //Y.CalendarBase.CONTENT_TEMPLATE = Y.CalendarBase.TWO_PANE_TEMPLATE;

     calendar = new Y.Calendar({
       contentBox: "#mycalendar",
       width: "800px",
       showPrevMonth: true,
       showNextMonth: true,
       selectionMode: 'multiple',
       disabledDatesRule: "future_dates",
       minimumDate: new Date(2013, 0, 1),
       maximumDate: new Date()
     });

    // Create a set of rules to match specific dates. In this case,
    // the "tuesdays_and_fridays" rule will match any Tuesday or Friday,
    // whereas the "all_weekends" rule will match any Saturday or Sunday.
     var rules = {
       "all": {
         "all": {
           "all": {
             "0,6": "all_weekends"
           },
         },
       }
     };

     // all of this shit just do disable selection of the remaining
     // days in a month
     var rightNow = new Date(); 
     var remainingDays = [];
     for (var i=rightNow.getDate();i<=31;i++) {
        remainingDays.push(i);
     }
     var nowMonth = rightNow.getMonth();
     var seq = remainingDays.join(',');
     var nowYear = rightNow.getFullYear(); 
     rules[nowYear] = {};
     rules[nowYear][nowMonth] = {};
     rules[nowYear][nowMonth][seq] = {};
     rules[nowYear][nowMonth][seq]["all"] = "future_dates";
     calendar.set("customRenderer", {
       rules: rules,
       filterFunction: function (date, node, rules) {
         if (Y.Array.indexOf(rules, 'future_dates') >= 0) {
           node.addClass("redtext");
         }
       }
     });
     //alert(calendar.get("customRenderer").toSource());

    // Set a custom header renderer with a callback function,
    // which receives the current date and outputs a string.
    // use the Y.Datatype.Date format to format the date, and
    // the Datatype.Date math to add one month to the current
    // date, so both months can appear in the header (since 
    // this is a two-pane calendar).
     calendar.set("headerRenderer", function (curDate) {
       var ydate = Y.DataType.Date,
           output = ydate.format(curDate, {
           format: "%B %Y"
         }) + " &mdash; " + ydate.format(ydate.addMonths(curDate, 1), {
           format: "%B %Y"
         });
       return output;
     }); 

    // When selection changes, output the fired event to the
    // console. the newSelection attribute in the event facade
    // will contain the list of currently selected dates (or be
    // empty if all dates have been deselected).
     calendar.on("selectionChange", function (ev) {
        if (ev.newSelection.length > 0) {
            var beginDate = ev.newSelection[0];
            var endDate = ev.newSelection[ev.newSelection.length-1];
            document.getElementById('beginDate').value = beginDate.getTime()/1000; 
            document.getElementById('endDate').value = endDate.getTime()/1000; 
            document.getElementById('beginDateShow').value = (1+beginDate.getMonth()) + "/" + beginDate.getDate() + "/" +beginDate.getFullYear();
            document.getElementById('endDateShow').value = (1+endDate.getMonth()) + "/" + endDate.getDate() + "/" +endDate.getFullYear();
        }
     });

     calendar.render();
     
     });

	Y.namespace('patchtrends').dataSearchView = Y.Base.create('dataSearchView', Y.View, [], {
		events: {
			'#findButton': {
				click: '_findData'
			},
            '#findAllButton': {
                click: '_findAllData'
            }
		},
        /* facilitate returning all results, reusing this._findData */
        _findAllData: function(e) {
			var searchTerms = Y.one('#searchTerms').set('value',' ');
            this._findData(e);
        },
		_findData: function(e) {
			var searchTerms = Y.one('#searchTerms').get('value');
			var resultContainer = Y.one('#searchResults');
		    resultContainer.set('innerHTML', '<font color=green size=4>searching ...</font>');
			var searchTermsField = Y.one('#searchTerms');
			var x = document.getElementById('searchTerms').value;

            if ( ! x ) {
			        resultContainer.set('innerHTML', '<font size=4 color=red>Search term required!</font>');
                    _foo_doesnt_exist();
            }
			var searchOptions = {
				terms: encodeURIComponent(x) // encode for url
			};
			this.get('model').load(searchOptions, function(errObj, data) {
			    var jsonObj;
                try {
			        jsonObj = Y.JSON.parse(data);
                } 
                catch (e) {
                }
                if (!jsonObj) {
                    resultContainer.set('innerHTML', '<font size=4 color=red>Bad response from server. Please try again. If the problem persists, email <a href=mailto:patchtrends@gmail.com>patchtrends@gmail.com</a></font>');
                        _foo_doesnt_exist();
                }
                else if (jsonObj.status == 401) {
                    resultContainer.set('innerHTML', '<font size=4 color=red>Your session has expired, please login or renew your One Time Pass for access.</font>');
                    _foo_doesnt_exist();
                }
				if (jsonObj.length > 0) {
		            resultContainer.set('innerHTML', '');
                    var table = new Y.DataTable({
                        columns: [
                            {key:"endtime", label:"Retreived", formatter:itemDate},
                            {key:"doc", label:"URL", formatter:toggleEPN, allowHTML: true},
                            {key:"doc", label:"Item", formatter:'<span id={value} align=center><a href=http://www.patchtrends.com/cgi-bin/item/image/{value} target=_foo><a href=# onClick="loadImg(\'{value}\'); return false">show</a></span>', allowHTML: true},
                            {key:"doc", label:"Check", formatter:'<input type=checkbox name=loadImg value={value} />', allowHTML: true},
                            {key:"title", label:"Title", formatter:'<div align=left><b>{value}</b></div>'}, 
                            {key:"primarycategory", label:"Category"},
                            {key:"currentprice", label:"Bid", formatter: currency},
                            {key:"bidcount", label:"# Bids", formatter: isSold}
                        ],
                        data: jsonObj,
                        // Optionally configure your table with a caption
                        // and/or a summary (table attribute)
                        summary: "limited search results"
                    });
                    table.set('caption','showing ' + jsonObj.length + ' results');
                    table.render("#searchResults");
		            var html = resultContainer.get('innerHTML');
                    var promoText=""; //"<br/><a href=/join.html><font size=5 color=blue>Learn how to view more</font></a>";
                    resultContainer.set('innerHTML',html+promoText);
                
                }
                else {
			        resultContainer.set('innerHTML', '<font size=4 color=red> "' + searchTerms + '" Not found!</font>');
                }
			});
		},
		initializer: function() {
			// this.get('model').after('change', this.render, this);
			// this.get('model').after('destroy', this.destroy, this);
		},
		render: function() {
			var container = this.get('container');
		}
	},
	{
		ATTRS: {

		}
	})
},
'0.1', {
	requires: ['view', 'node', 'json-stringify', 'io', 'datatable', 'datatype', 'datatype-date']
});

