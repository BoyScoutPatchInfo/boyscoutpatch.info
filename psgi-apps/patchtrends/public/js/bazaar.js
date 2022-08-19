'use strict';

/*
 * Copyright Patchtrends.com, Patchbazaar.com 2012-present
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

var myApp = angular.module('myApp', ['ngResource']);

myApp.filter("sanitize", ['$sce', function($sce) {
    return function(htmlCode) {
      return $sce.trustAsHtml(htmlCode);
    }
}]);

myApp.filter('trustAsResourceUrl', ['$sce', function($sce) {
    return function(val) {
        return $sce.trustAsResourceUrl(val);
    };
}]);

myApp.filter('escape', function() {
      return window.encodeURIComponent;
});


myApp.controller('listController', ['$scope', '$http', '$location', function($scope, $http, $location) {

    $scope.profile = null; 
    $scope.lastConfig = 'popular';
    $scope.showAdvanced = 0;
    $scope.baseURL = getBaseURL();
    $scope.itemURL = $scope.baseURL + "item/details/";
    $scope.fields = new Array("maxBidCount", "minBidCount", "maxBidAmount", "minBidAmount", "orderBy", "perPage", "descending", "listingType");
    $scope.show_good = true;
    $scope.show_okay = true;
    $scope.show_remaining = true;
    $scope.show_auctions = true;
    $scope.show_bins = true;
    $scope.show_bestoffers = true;

    var configure = function(minBidCount, maxBidCount, minBidAmount, maxBidAmount, perPage, orderBy, descending, listingType) {
      var search = {
        minBidCount: minBidCount,
        maxBidCount: maxBidCount,
        minBidAmount: minBidAmount,
        maxBidAmount: maxBidAmount,
        perPage: perPage,
        orderBy: orderBy,
        descending: descending,
        listingType: listingType
      };
      $scope.search = search;
      return search;
    }

    $scope.reset = function() {
      $scope.terms = null;
      $location.search({
        profile: 'endingSoon'
      });
      $scope.setConfig('endingSoon');
      $scope.showAdvanced = false;
      return;
    };

    var createSearchLink = function() {
      var terms = '';
      var search = $scope.search;
      if ($scope.terms != null) {
        terms = $scope.terms.replace('/', ' '); // will mess up route
        terms = terms.replace('?', ' ');        // will mess up query params
        terms = encodeURIComponent(terms);
        search.orderBy = 'relevance';
      }
      var serial = ['matchMode=any'];
      for (var i = 0; i < $scope.fields.length; i++) {
        var value = search[$scope.fields[i]];
        if (value != null && typeof value !== 'undefined') {
          value = encodeURIComponent(search[$scope.fields[i]]);
          serial.push($scope.fields[i] + '=' + value);
        }
      }
      var query = serial.join('&');
      var url = $scope.baseURL + 'api/bazaar/search/' + terms + '?' + query;
      return url;
    };

    var nowDiff = function(epoch) {
      var a = new Date(epoch * 1000);
      var now = (new Date).getTime();
      var diff = a - now;
      return diff;
    };

    $scope.findSimilar = function(title) {
      $scope.terms = title;
      $scope.doSearch();
    };

    $scope.doSearch = function() {
      var url = createSearchLink();
      $scope.tryZeroBids = false; 
      if ($scope.terms != null) {
        var s = $location.search();
        s.terms = encodeURIComponent($scope.terms);
        $location.search(s);
      }
      $scope.message = 'Searching ...';
      $scope.results = [];
      $http.get(url)
        .success(function(response) {
          if (response.length >= 1) {
            for (var i = 0; i < response.length; i++) {
              response[i].nowDiff = nowDiff(response[i].endtimeunix);
            }
            $scope.results = response;
          } else {
            $scope.message = 'No results, please broaden your search criteria.';
            if ($scope.search.maxBidCount > 0) {
              $scope.tryZeroBids = true; 
            }
          }
        });
        return;
      };
      $scope.makeBid = function(item) {
        var bidcount = item.bidcount;
        if ( item.is_bin == 1) {
          return '';
        }
        else if (item.bestoffer == 1) {
          return '';
        } else {
          var s = 's';
          if ( bidcount == 1 ) {
            s = '';
          }
          return ', ' + bidcount + ' bid' + s;
       }
    };

//add link for similar 'for sale'
//add links to completed header in item details page so ppl know more info is above
    $scope.makeDealLabel = function(item) {
      // default
      var deal = '<a href=/item/details/'+item.itemid+' target="'+item.itemid+'">';
      if ( item.rating == 1 ) {
        deal = '<a href=/item/details/'+item.itemid+' target="'+item.itemid+'"><span class="label label-success">Good Deal</span><sup><p/></sup></a>';
      }
      else if ( item.rating == 2 ) {
        deal = '<a href=/item/details/'+item.itemid+' target="'+item.itemid+'"><span class="label label-info">Okay Deal</span><sup><p/></sup></a>';
      }
      return deal;
    };

    $scope.makeTitle = function(item) {
      var ret  = '<b><a href=/item/details/'+item.doc+' target="'+item.itemid+'">' + item.title + '</a></b>';
      return ret;
    };

    $scope.makeHttps = function(itemUrl) {
      itemUrl = itemUrl.replace(/http:/, 'https:');
      return itemUrl; 
    };

    $scope.makeButton = function(item) {
      var epoch = item.endtimeunix;
      var itemId = item.itemid;
      var is_bin = item.is_bin;
      var bestoffer = item.bestoffer;
      var bidurl = "https://boyscoutpatch.info/ebay/" + itemId;
      if ( is_bin == 1 ) {
        var buynow = '<a href="'+bidurl+'" target='+itemId+'><button style="font-size:20px" class="btn btn-danger"><i class="fa fa-money-o">Buy Now!</i></button></a>';
        return buynow;
      }
      else if (bestoffer == 1) {
        var bestoffer = '<a href="'+bidurl+'" target='+itemId+'><button style="font-size:20px" class="btn btn-success"><i class="fa fa-money-o">Make Offer!</i></button></a>';
        return bestoffer;
      }
      else {
        return $scope.formatEndTime(epoch, itemId); 
      }
    };

    // this think is non-functional as-is
    $scope.formatEndTime = function(epoch, itemId) {
      var a = new Date(epoch * 1000);
      var now = (new Date).getTime();
      var diff = a - now;

      var bidurl = $scope.baseURL + "ebay/" + itemId;
      if (diff < 300000) { // 5 min
        var bidnow = '<a href="'+bidurl+'" target='+itemId+'><button style="font-size:20px" class="btn btn-danger"><i class="fa fa-money-o">Bid Now!</i></button></a>';
        return "<b><font color=red>under 5 min</font></b><p/>" + bidnow;
      } else if (diff < 900000) { // 15 min
        var bidnow = '<a href="'+bidurl+'" target='+itemId+'><button class="btn btn-danger"><i class="fa fa-money-o">Bid Now!</i></button></a>';
        return "<b><font color=red>under 15 min</font></b><p/>" + bidnow;
      } else if (diff < 1800000) { // 30 min
        var bidnow = '<a href="'+bidurl+'" target='+itemId+'><button class="btn btn-danger"><i class="fa fa-money-o">Bid Now!</i></button></a>';
        return "<b><font color=red>under 30 min!!</font></b><p/>" + bidnow;
      } else if (diff < 3200000) { // 1 hr
        var bidnow = '<a href="'+bidurl+'" target='+itemId+'><button class="btn btn-danger"><i class="fa fa-money-o">Bid Now!</i></button></a>';
        return "<b><font color=red>under 1 hour</font></b><p/>" + bidnow;
      } else if (diff < 7400000) { // 2 hrs
        var bidnow = '<a href="'+bidurl+'" target='+itemId+'><button class="btn btn-info"><i class="fa fa-money-o">Bid Now!</i></button></a>';
        return "<b><font color=red>under 2 hours</font></b><p/>" + bidnow;
      } else if (diff < 9600000) { // 3 hrs
        var bidnow = '<a href="'+bidurl+'" target='+itemId+'><button class="btn btn-info"><i class="fa fa-money-o">Bid Now!</i></button></a>';
        return "<b><font color=black>under 3 hours</font></b><p/>" + bidnow;
      } else if (diff < 86400000) { // 24 hrs
        var bidnow = '<a href="'+bidurl+'" target='+itemId+'><button class="btn btn-info"><i class="fa fa-money-o">Bid Now!</i></button></a>';
        return "<b><font color=green>Ending Today</font></b><p/>" + bidnow;
      } else if (diff < 172800000) { // 48 hrs 
        return "<b><font color=black>under 2 days left</font></b>";
      } else if (diff < 259200000) { // 72 hrs 
        return "<b><font color=black>under 3 days left</font></b>";
      } else if (diff < 345600000) { // 96 hrs 
        return "<b><font color=black>under 4 days left</font></b>";
      } else if (diff < 43200000) { // 96 hrs 
        return "<b><font color=black>under 5 days left</font></b>";
      } else {
        return "";// "<b><font color=black>over 5 days</font></b>";
      }
    };

    var isEmpty = function(obj) {
      for (var prop in obj) {
        if (obj.hasOwnProperty(prop))
          return false;
      }
      return true;
    };

    $scope.setConfig = function(config) {
      // extract URL and params on first load
      var search = $location.search();
      if (isEmpty(search)) { // if there are absolutely no params in URL
        config = $scope.lastConfig;
      }

      $scope.lastConfig = config;
      var minBidCount = (search.minBidCount) ? search.minBidCount : 1;
      var maxBidCount = (search.maxBidCount) ? search.maxBidCount : 500;
      var minBidAmount = (search.minBidAmount) ? search.minBidAmount : 0;
      var maxBidAmount = (search.maxBidAmount) ? search.maxBidAmount : 100000;
      var perPage = (search.perPage) ? search.perPage : 100;
      var orderBy = (search.orderBy) ? search.orderBy : 'date';
      var descending = (!search.descending || search.descending == 0) ? 0 : 1; 

      // reset
      //$scope.reverseSort = 0;

      var configProfiles = {
        init: function() {
          return configure(minBidCount, maxBidCount, minBidAmount, maxBidAmount, perPage, orderBy, descending);
        },
        search: function() {
          return configure(minBidCount, maxBidCount, minBidAmount, maxBidAmount, perPage, orderBy, descending);
        },
        // the following support the preset buttons
        endingSoon: function() {
          return configure(1, perPage, 1, 100000, perPage, 'end time', 0, 'Any');
        },
        newlyListed: function() {
          return configure(1, perPage, 1, 100000, perPage, 'start time', 1, 'Auction');
        },
        popular: function() {
          return configure(1, perPage, 1, 100000, perPage, 'bids', 1, 'Auction');
        },
        highPrice: function() {
          return configure(1, perPage, 1, 100000, perPage, 'bid amount', 1, 'Any');
        },
        buyNow: function() {
          // setFilter('buy now');
          var _search = configure(null, null, 1, 100000, perPage, 'end time', 0, 'BuyItNow');
          return _search;
        },
        bestOffer: function() {
          var _search = configure(null, null, 1, 100000, perPage, 'end time', 0, 'BestOffer');
          return _search;
        },
        bestDeal: function() {
          return configure(1, perPage, 1, 100000, perPage, 'rating', 0, 'Any');
        }
      };

      if (config in configProfiles) {
        $scope.profile = config;
        if (config != 'init') {
          var s = {
            profile: config
          };
          if ($scope.terms != null) {
            s.terms = encodeURIComponent($scope.terms);
          }
          $location.search(s);
        }
      }
      $scope.search = configProfiles[$scope.profile]();
      $scope.doSearch();
    };

    $scope.updateURL = function() {
      var s = $scope.search;
      if ($scope.terms != null) {
        s.terms = encodeURIComponent($scope.terms);
      }
      $location.search(s);
    };

    $scope.maxBid = function(min, max) {
      $scope.search.minBidCount = min;
      $scope.search.maxBidCount = max;
      $scope.profile = null;
      $scope.updateURL();
      $scope.doSearch();
    };

    $scope.maxAmount = function(min, max) {
      $scope.search.minBidAmount = min;
      $scope.search.maxBidAmount = max;
      $scope.profile = null;
      $scope.updateURL();
      $scope.doSearch();
    };

    $scope.sortBy = function(by, descend) {
      $scope.search.orderBy = by;
      $scope.search.descending = descend;
      $scope.profile = null;
      $scope.updateURL();
      $scope.doSearch();
    }

    $scope.setPerPage = function(perPage) {
      $scope.search.perPage = perPage;
      $scope.profile = null;
      $scope.updateURL();
      $scope.doSearch();
    };

    $scope.filterOnType = function(item) {
      if ( (item.listingtype == "Auction" || item.listingtype == "AuctionWithBIN" ) && $scope.show_auctions ) {
        return true;
      }
      if ( item.is_bin == 1 && $scope.show_bins ) {
        return true;
      }
      if ( item.bestoffer == 1 && $scope.show_bestoffers ) {
        return true;
      }
      return false;
    };

    $scope.filterOnDeal = function(rating) {
      if ( rating == 1 && $scope.show_good ) {
        return true;
      } 
      if ( rating == 2 && $scope.show_okay ) {
        return true;
      } 
      if ( ( rating == 0 || rating >= 3 ) && $scope.show_remaining ) {
        return true;
      } 
      return false;
    };

    var loc = $location.search();
    var p = loc.profile;
    var t = loc.terms;
    if (t != null) {
      $scope.terms = decodeURIComponent(t);
    }
    if (p != null) {
      $scope.setConfig(p);
    } else {
      $scope.setConfig('init');
    }
}]);
