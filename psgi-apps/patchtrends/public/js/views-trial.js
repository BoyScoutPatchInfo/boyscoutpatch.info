var count = 1;
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
        var campURLs = [
            'http://rover.ebay.com/rover/1/711-53200-19255-0/1?icep_ff3=2&pub=5574774297&toolid=10001&campid=5337044717&ipn=psmain&icep_vectorid=229466&kwid=902099&mtid=824&kw=lg&icep_item=',
            'http://rover.ebay.com/rover/1/711-53200-19255-0/1?icep_ff3=2&pub=5575058914&toolid=10001&campid=5337383337&ipn=psmain&icep_vectorid=229466&kwid=902099&mtid=824&kw=lg&icep_item=',
            'http://www.patchtrends.com/cgi-bin/index/join',
            'http://www.patchtrends.com/cgi-bin/index/join',
            'http://www.patchtrends.com/cgi-bin/index/join'
        ];
        var urlIndex = Math.floor(Math.random()*campURLs.length); //o.rowIndex % campURLs.length;  
        alert(urlIndex);
        var url = campURLs[urlIndex] + o.value;
        return '<a href=' + url + ' target=_other>link</a>';
    }

    var toggleEPNImage = function (o) {
        var campURLs = [
            'http://rover.ebay.com/rover/1/711-53200-19255-0/1?icep_ff3=2&pub=5574774297&toolid=10001&campid=5337044717&ipn=psmain&icep_vectorid=229466&kwid=902099&mtid=824&kw=lg&icep_item=',
            'http://rover.ebay.com/rover/1/711-53200-19255-0/1?icep_ff3=2&pub=5575058914&toolid=10001&campid=5337383337&ipn=psmain&icep_vectorid=229466&kwid=902099&mtid=824&kw=lg&icep_item=',
            'http://www.patchtrends.com/cgi-bin/index/join',
            'http://www.patchtrends.com/cgi-bin/index/join',
            'http://www.patchtrends.com/cgi-bin/index/join'
        ];
        var urlIndex = Math.floor(Math.random()*campURLs.length); //o.rowIndex % campURLs.length;  
        var url = campURLs[urlIndex] + o.value;
        return '<a href=' + url + ' target=_other><img width=50 height=50 src=http://www.patchtrends.com/cgi-bin/item/image/micro/' + o.value + '></a>';
    }

    var toggleEPNTitle = function (o) {
        var campURLs = [
            'http://rover.ebay.com/rover/1/711-53200-19255-0/1?icep_ff3=2&pub=5574774297&toolid=10001&campid=5337044717&ipn=psmain&icep_vectorid=229466&kwid=902099&mtid=824&kw=lg&icep_item=',
            'http://rover.ebay.com/rover/1/711-53200-19255-0/1?icep_ff3=2&pub=5575058914&toolid=10001&campid=5337383337&ipn=psmain&icep_vectorid=229466&kwid=902099&mtid=824&kw=lg&icep_item=',
            'http://www.patchtrends.com/cgi-bin/index/join?item=',
            'http://www.patchtrends.com/cgi-bin/index/join?item=',
            'http://www.patchtrends.com/cgi-bin/index/join?item=',
            'http://www.patchtrends.com/cgi-bin/index/join?item=',
            'http://www.patchtrends.com/cgi-bin/index/join?item=',
        ];
        var urlIndex = Math.floor(Math.random()*campURLs.length); //o.rowIndex % campURLs.length;  
        var url = campURLs[urlIndex] + o.data.doc;
        return '<font size=4><u><b><a href=' + url + ' target=_other>' + o.value + '</a></b></u></font>';
    }

    var activeAuctions = function(o) {
        var searchTerms = Y.one('#searchTerms').get('value');
        return '<u><b><a href=http://www.patchbazaar.com/cgi-bin/index/search/'+encodeURI(searchTerms)+'>buy!</a></b></u>';
    }

	Y.namespace('patchtrends').dataSearchView = Y.Base.create('dataSearchView', Y.View, [], {
		events: {
			'#findButton': {
				click: '_findData',
			},
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
				terms: encodeURIComponent(x), // encode for url
			};
			this.get('model').load(searchOptions, function(errObj, data) {
			    var jsonObj;
                try {
			        jsonObj = JSON.parse(data);
                } 
                catch (e) {

                }
                if ( ! jsonObj ) {
                        resultContainer.set('innerHTML', '<font size=4 color=red>Bad response from server. Try again.!</font>');
                        _foo_doesnt_exist();
                }
				if (jsonObj.length > 0) {
		            resultContainer.set('innerHTML', '');
                    var table = new Y.DataTable({
                        columns: [
                            //{key:"endtime", label:"Retreived", formatter:itemDate},
                            //{key:"doc", label:"URL", formatter:toggleEPN, allowHTML:true},
                            {key:"doc", label:"Item", formatter:toggleEPNImage, allowHTML:true},
                            {key:"title", label:"Title of Sold Item", formatter:toggleEPNTitle, allowHTML:true}, 
                            {key:"currentprice", label:"Approx.", formatter:'<a href=/cgi-bin/index/join>{value}</a>', allowHTML:true},
                            {key:"title", label:"Related", formatter: activeAuctions, allowHTML: true}
                        ],
                        data: jsonObj,
                        // Optionally configure your table with a caption
                        // and/or a summary (table attribute)
                        summary: "limited search results"
                    });
                    table.set('caption','<a href=/cgi-bin/index/join>showing ' + jsonObj.length + ' results of MANY, <u>join to see them all</u>!</a>');
                    table.render("#searchResults");
		            var html = resultContainer.get('innerHTML');
                    var promoText="<br/><h2><a href=/cgi-bin/index/join><font size=5 color=blue>Learn how to view <i>many</i> more results!</font></a></h2>";

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
		},
	},
	{
		ATTRS: {

		}
	})
},
'0.1', {
	requires: ['view', 'node', 'json-stringify', 'io', 'datatable', 'datatype', 'datatype-date']
});

