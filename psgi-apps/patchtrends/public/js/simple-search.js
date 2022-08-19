'use strict';
/*
* Copyright Patchtrends.com 2012-present
*/

function getBaseURL() {
    var url = location.href;  // entire url including querystring - also: window.location.href;
    var baseURL = url.substring(0, url.indexOf('/', 14));
    if (baseURL.indexOf('http://localhost') != -1) {
        // Base Url for localhost
        var url = location.href;  // window.location.href;
        var pathname = location.pathname;  // window.location.pathname;
        var index1 = url.indexOf(pathname);
        var index2 = url.indexOf("/", index1 + 1);
        var baseLocalUrl = url.substr(0, index2);
        return baseLocalUrl + "/";
    }
    else {
        // Root Url for domain name
        return baseURL + "/";
    }
}

var myApp = angular.module('myApp', []);

myApp.controller('listController', ['$scope', '$http', function($scope, $http) {
    $scope.baseUrl = getBaseURL();
    var tmpBaseUrl = $scope.baseUrl;
    tmpBaseUrl = tmpBaseUrl.replace(/https?:\/\//, '');
    var tld = tmpBaseUrl.split('.');
    $scope.imageBaseUrl = "images." + tld[tld.length-2] + "." + tld[tld.length-1];
    $scope.apiBaseUrl = $scope.baseUrl + "api/search/";
    $scope.noItems = false;
    $scope.terms = " "; // initial search
    $scope.terms = ($scope.terms) ? $scope.terms : ' ';
    $scope.showAdvanced = false;
    $scope.message = 'Searching ...';

    $scope.today = function() {
      var currentDate = new Date();
      var day = currentDate.getDate();
      var month = currentDate.getMonth() + 1;
      var year = currentDate.getFullYear();
      return month + "/" + day + "/" + year;
    };

    // default search parameters
    $scope.resetSearch = function () {
      $scope.search = {
        descending: true,
        matchMode: 'all',
        primaryCategory: 'all',
        minBidCount: 0,
        maxBidCount: 500,
        minBidAmount: 1,
        maxBidAmount: 100000,
        orderBy: 'date',
        perPage: 250,
        listingType: 'Auction',
        soldStatus: 'sold',
	begin: '01/01/2012', // well earlier than earliest data
	end: $scope.today()  // ended "today"
      };

      return;
    };

    $scope.resetSearch();

    $scope.form2query = function(obj) {
      // deal with date
      if ($scope.search.begin && $scope.search.end) {
        var a = new Date($scope.search.begin).getTime() / 1000;
        var b = new Date($scope.search.end).getTime() / 1000;
        // swap if a (begin) is greater than b (end)
        if (a > b) {
          a = b + (b = a, 0)
        }
        $scope.search.beginDate = a;
        $scope.search.endDate = b;
      }

      var str = [];
      for (var p in obj) {
        if (p != 'end' && p != 'begin' && obj[p] != null) {
          str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
        }
      }
      return str.join("&");
    };

    var terms = ($scope.terms) ? $scope.terms : ' ';
    var query = $scope.form2query($scope.search);

    $http.get($scope.apiBaseUrl + encodeURIComponent($scope.terms) + '?' + query).success(function(response) {
      $scope.items = response;
      $scope.message = (response.length <= 0) ? (terms != ' ') ? 'Sorry, no results found. Try broadening your search terms. If you feel this is an error, email patchtrends@gmail.com' : 'Unexpectedly got no results. Something might be wrong, please email patchtrends@gmail.com. Thank you!' : null ;
    }).error(function(data, status) {
      if (data.message == 'unauthorized') {
        $scope.message = 'Session has expired, please login again.';
      }
      else {
        $scope.message = 'There has been a request error. If issue persists, please email patchtrends@gmail.com.';
      }
    });

    $scope.doSearch = function() {
      $scope.message = 'Searching ...';
      var terms = ($scope.terms) ? $scope.terms : ' ';
      var query = $scope.form2query($scope.search);

      terms = encodeURIComponent(terms);
      $scope.items = [];
      $http({
        method: 'GET',
        url: $scope.apiBaseUrl + terms + '?' + query,
      }).success(function(response) {
        $scope.items = response;
        $scope.message = (response.length <= 0) ? (terms != ' ')
		                 ? 'Sorry, no results found. Try broadening your search terms. If you feel this is an error, email patchtrends@gmail.com'
		                 : 'Unexpectedly got no results. Something might be wrong, please email patchtrends@gmail.com. Thank you!': null;
      }).error(function(data, status) {
      if (data.message == 'unauthorized') {
        $scope.message = 'Session has expired, please login again.';
      }
      else {
        $scope.message = 'There has been a request error. If issue persists, please email patchtrends@gmail.com.';
      }
      });
      return;
    };

    /* trigger search */
    $scope.doSearchAll = function() {
      $scope.terms = ' ';
      $scope.doSearch();
      return;
    };

    $scope.saveAll = function() {
      $http({
        method: 'GET',
        headers: {'Content-Type': 'application/json'},
        url: $scope.baseUrl+'api/itembucket'
      }).success(function(response) {
        $scope.lists=response;
        $scope.authorized=true;
        $scope.selectedItem = $scope.lists[1];
        $scope.showSaveItems = true;
      }).error(function(data, status, headers, config) {
        if ( status=='401' ) {
          $scope.authorized=false;
        }
      });
    };

    /* save items to selected list */
    $scope.doSaveItems = function() {
      var itemsToSave = [];
      angular.forEach($scope.items, function(item) {
        if (item.checked == true) {
          itemsToSave.push(item.doc);
        }
      });
      var listid = $scope.lists[angular.element(document.getElementById('selectedList')).val()].id
      var data = {
        "items" : itemsToSave,
      };
      // make call to add items
      $http({
        method: 'PUT',
        headers: {'Content-Type': 'application/json'},
        url: $scope.baseUrl+'api/itembucket/'+listid+'/items',
	data: data
      }).success(function(response) {
        $scope.itemsSavedOk = true;
      }).error(function(data, status, headers, config) {
        if ( status=='401' ) {
          $scope.authorized=false;
        }
	if ( status=='400' ) {
          $scope.itemsSavedNotOk = true;
	}
      });
    };

    /* check all items */
    $scope.checkAll = function() {
      angular.forEach($scope.items, function(item) {
        item.checked = true;
      });
    };

    /* uncheck all items that are checked */
    $scope.uncheckAll = function() {
      angular.forEach($scope.items, function(item) {
        if (item.checked == true) {
          item.checked = false;
        }
      });
    };

    /* hide all checed items if expanded */
    $scope.hideAll = function() {
      angular.forEach($scope.items, function(item) {
        if (item.checked == true) {
          item.showthumb = false;
        }
      });
    };

    /* show images for checked items */
    $scope.loadChecked = function() {
      angular.forEach($scope.items, function(item) {
        if (item.checked == true) {
          item.showthumb = true;
        }
      });
    };

    $scope.show = function(item) {
      item.showthumb = true;
      item.checked = true;
    };

    $scope.hide = function(item) {
      item.showthumb = false;
      item.checked = false;
    };

    $scope.formatListingType = function(listingType) {
      if (listingType == "Auction") {
        return "Auction";
      }
      else if (listingType == "AuctionWithBIN") {
        return "Auct/BIN";
      }
      else if (listingType == "FixedPrice") {
        return "Fixed";
      }
      else if (listingType == "StoreInventory") {
        return "Store";
      }
    };

    $scope.first_of_month = function () {
      var currentDate = new Date();
      var month = currentDate.getMonth() + 1;
      var year = currentDate.getFullYear();
      return month + "/01/" + year;
    };
    
    $scope.first_of_year = function () {
      var currentDate = new Date();
      var year = currentDate.getFullYear();
      return"01/01/" + year;
    };
  
    $scope.days_before_today = function (days) {
      var d = new Date();
      d.setDate(d.getDate() - days);
      var day = d.getDate();
      var month = d.getMonth() + 1;
      var year = d.getFullYear();
      return month + "/" + day + "/" + year;
    }; 

    $scope.add_seller = function(seller) {
      $scope.showAdvanced = true;
      if ($scope.search.seller) {
        $scope.search.seller += " " + seller;
      }
      else {
        $scope.search.seller = seller;
      }
    };


    $scope.randomWaitReload = function(imageObj) {
      this.src = 'https://images.boyscoutpatch.info/404.jpg';
    };
}]);
