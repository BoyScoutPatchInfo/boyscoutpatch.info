var baseRequestURI = '/cgi-bin/rest/email';
YUI.add('trial-request-view', function(Y) {
	Y.namespace('patchtrends').dataSearchView = Y.Base.create('trialRequestView', Y.View, [], {
		events: {
			'#requestButton': {
				click: '_sendRequest',
			},
		},
		_sendRequest: function(e) {
            var uri = baseRequestURI;
            var cfg = {
                method: 'PUT',
                form: {
                    id: trialform,
                    useDisabled: false 
                }
            };
            var success = function(resid, o, args) {
                var resid = resid; // Transaction ID.
                data = o.responseText; // Response data.
                Y.one('#requestbox').set('innerHTML','<font color=green>Thank You! A special link has been sent. Check your email.</font>');
                return;
            };

            // fallback
            var failure = function(resid, o, args) {
                var failed_id = args[0];
                var data = o.responseText; // Response data.
			    var jsonObj;
                try {
			        jsonObj = JSON.parse(data);
                    alert(jsonObj.errmsg);
                } 
                catch (e) {
                    alert('unspecified error');
                }
                return;
            };

            // register Y.IO request event handlers                
            var io = new Y.IO();
            io.on('io:success', success, Y, []);
            io.on('io:failure', failure, Y, []);

            //make request
            var request = io.send(uri, cfg);
        },
		initializer: function() {

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
	requires: ['view', 'node', 'json-stringify', 'io-form']
});

