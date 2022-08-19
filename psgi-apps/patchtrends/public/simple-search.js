'use strict';

var myApp=angular.module('myApp',[]);
var baseurl = 'cdn.patchtrends.com/cgi-bin';

// add plot controller !!!

myApp.controller('listController', ['$scope', '$http', function ($scope, $http) {
    $scope.terms = " "; // initial search
    $scope.terms = ( $scope.terms) ? $scope.terms : ' ';

    $scope.showAdvanced = true;

    // default search parameters
    $scope.search = {
      descending: true,
      matchMode: 'bool',
      primaryCategory: 'all', 
      minBidCount: 1,
      maxBidCount: 500, 
      minBidAmount: 0,       
      maxBidAmount: 100000,
      orderBy: 'date',
      perPage: 100,
    };

    $scope.form2query = function(obj) {
      // deal with date
      if ($scope.search.begin && $scope.search.end) {
        var a = new Date($scope.search.begin).getTime() / 1000;
        var b = new Date($scope.search.end).getTime() / 1000;
        // swap if a (begin) is greater than b (end)
        if (a > b) { a = b + (b=a, 0) }
        $scope.search.beginDate = a;
        $scope.search.endDate = b;
      }
      
      var str=[];
      for(var p in obj) {
        if (p != 'end' && p != 'begin') {
          str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
        }
      }
      return str.join("&");
    };

    var terms = ( $scope.terms ) ? $scope.terms : ' ';

    var query = $scope.form2query($scope.search);

    $http.get("//"+baseurl+"/rest/search/" + encodeURIComponent($scope.terms) + '?' + query ).success(function(response) {
        $scope.items=response;
        $scope.authorized=true;
    }).error(function(data, status, headers, config) {
        if ( status=='401' ) {
          $scope.unauthorized=true;
        }
    });

    $scope.doSearch=function() { 
      var terms = ( $scope.terms ) ? $scope.terms : ' ';
      var query = $scope.form2query($scope.search);

      terms = encodeURIComponent(terms);
      $scope.items = [];
      $http({
        method: 'GET',
        url: '//'+baseurl+'/rest/search/' + terms + '?' + query, 
      }).success(function (response) {
        $scope.items=response;
      })
      return;
    };

    $scope.doSearchAll=function() {
      $scope.terms = ' ';
      $scope.doSearch();
      return;
    };

    $scope.checkAll=function() {
      angular.forEach($scope.items, function (item) {
          item.checked = true; 
      });
    };

    $scope.uncheckAll=function() {
      angular.forEach($scope.items, function (item) {
        if ( item.checked == true ) {
          item.checked = false;
        }
      });
    };

    $scope.hideAll=function() {
      angular.forEach($scope.items, function (item) {
        if ( item.checked == true ) {
          item.showthumb = false;
        }
      });
    };

    $scope.loadChecked=function() {
      angular.forEach($scope.items, function (item) {
        if ( item.checked == true ) {
          item.showthumb = true;
        }
      });
    };

    $scope.show=function(item) {
      item.showthumb=true;
      item.checked=true;
    };

    $scope.hide=function(item) {
      item.showthumb=false;
      item.checked=false;
    };

    $scope.plotChecked=function() {
      $scope.showPlot = true;
    };

}]);
