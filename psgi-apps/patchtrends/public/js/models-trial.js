YUI.add('data-model', function(Y) {
	Y.namespace('patchtrends').dataModel = Y.Base.create('data', Y.Model, [], {

		// Custom sync layer.
		sync: function(action, options, callback) {
			var data;
			switch (action) {
			case 'create':
				data = this.toJSON();
				callback(null, data);
				return;
			case 'read':
				// this is a GET 
				var cfg = {
					method: 'GET'
				};

				var data = null;
				var terms = options.terms;
                if (terms) {
                    var uri = searchBaseURI + "/" + terms;
                    var success = function(resid, o, args) {
                        var resid = resid; // Transaction ID.
                        data = o.responseText; // Response data.
                        callback(null, data);
                        return;
                    };

                    // fallback
                    var failure = function(resid, o, args) {
                        var failed_id = args[0];
                        // issue call back with err message set and a null payload
                        callback('Load failed for ' + failed_id, null);
                        return;
                    };

                    // register Y.IO request event handlers                
                    var io = new Y.IO();
                    io.on('io:success', success, Y, []);
                    io.on('io:failure', failure, Y, []);

                    //make request
                    var request = io.send(uri);
                }
                else {
                    alert('please search for something');
                }
				return;

			case 'update':
				data = this.toJSON();
				callback(null, data);
				return;
			case 'delete':
				callback();
				return;
			default:
				callback('Invalid action');
			}
		}
	},
	{
		ATTRS: {
			//clientId - automatically generated for client side usage            
			id: {
				value: null,
				validator: function(val) {
					return true;
				},
			},
			title: {
				value: null,
				validator: function(val) {
					return true;
				},
			},
			price: {
				value: null,
				validator: function(val) {
					return true;
				},
			},
		}
	})
},
'0.1', {
	requires: ['model', 'json-stringify', 'json-parse', 'io']
});
