'use strict';

/*
* Copyright Patchtrends.com 2012-present
*/

var myApp = angular.module('myApp', []);

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
    $scope.showPlot = false;
    $scope.showPlotInfo = false;
    $scope.message = 'Searching ...';

    // default search parameters
    $scope.resetSearch = function () {
      $scope.search = {
        descending: true,
        matchMode: 'all',
        primaryCategory: 'all',
        minBidCount: 0,
        maxBidCount: 500,
        minBidAmount: 0,
        maxBidAmount: 100000,
        orderBy: 'date',
        perPage: 100,
        listingType: 'all',
        soldStatus: 'sold'
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
        $scope.message = (response.length <= 0) ? (terms != ' ') ? 'Sorry, no results found. Try broadening your search terms. If you feel this is an error, email patchtrends@gmail.com' : 'Unexpectedly got no results. Something might be wrong, please email patchtrends@gmail.com. Thank you!' : null ;
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

    $scope.doSearchAll = function() {
      $scope.terms = ' ';
      $scope.doSearch();
      return;
    };

    $scope.checkAll = function() {
      angular.forEach($scope.items, function(item) {
        item.checked = true;
      });
    };

    $scope.uncheckAll = function() {
      angular.forEach($scope.items, function(item) {
        if (item.checked == true) {
          item.checked = false;
        }
      });
    };

    $scope.hideAll = function() {
      angular.forEach($scope.items, function(item) {
        if (item.checked == true) {
          item.showthumb = false;
        }
      });
    };

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
}]);
