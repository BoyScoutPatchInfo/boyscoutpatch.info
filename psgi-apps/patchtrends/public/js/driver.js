//var searchBaseURI = null;
//var views = '/js/views-trial.js?h';
//var models = '/js/models-trial.js?g';

/*
function setDataSource (source) {
    if (source === "search") {
	    searchBaseURI = '/cgi-bin/rest/sphinx';
        views = '/js/views.js?i';
        models = '/js/models.js?g';
    }
    else if (source === "trial") {
        searchBaseURI = '/cgi-bin/rest/trial';
        views = '/js/views-trial.js?h';
        models = '/js/models-trial.js?g';
    }
}
*/

// "enter" button disabled
function stopRKey(evt) {
  var evt = (evt) ? evt : ((event) ? event : null);
  var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
  if ((evt.keyCode == 13) && (node.type=="text")) {
    document.getElementById('findButton').click();
    return false;
  }
}

document.onkeypress = stopRKey; 

YUI({
	modules: {
		"data-model": {
            fullpath: models,
			requires: ['model', 'json-stringify', 'json-parse', 'io']
		},
		"data-search-view": {
			fullpath: views,
			requires: ['view', 'node', 'json-stringify', 'io-form', 'datatable', 'datatype', 'datatype-date', 'imageloader']
		}
	}
}).use('node', 'data-model', 'data-search-view', 'event-base', 'node-event-simulate', function(Y) {
	var data = new Y.patchtrends.dataModel();
	var searchView = new Y.patchtrends.dataSearchView({
		model: data,
		container: Y.one('#searchbox')
	});
    searchView.render();

    /* trigger search if URL with search terms is sent */
    if (! document.getElementById('searchTerms').value) {
       // default
       document.getElementById('searchTerms').value = ' ';
    }
    Y.on('domready', function () {
       Y.one("#findButton").simulate("click");
    });
});
