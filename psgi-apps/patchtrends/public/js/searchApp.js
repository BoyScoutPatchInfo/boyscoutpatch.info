var myApp=angular.module('myApp',[]);
myApp.controller('listController', ['$scope', '$http', function ($scope, $http) {
    $scope.terms = "[% terms | html %]"; // initial search
    $scope.terms = ( $scope.terms) ? $scope.terms : ' ';

    // default search parameters
    $scope.search = {
      descending: true,
      matchMode: 'any',
      primaryCategory: 'all', 
      minBidCount: 1,
      maxBidCount: 500, 
      minBidAmount: 0,       
      maxBidAmount: 100000,
      orderBy: 'date',
      perPage: 100 
    };

    $scope.form2query = function(obj) {
      var str=[];
      for(var p in obj)
        str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
      return str.join("&");
    };

    var terms = ( $scope.terms ) ? $scope.terms : ' ';
    var query = $scope.form2query($scope.search);
    $http.get("http://www.patchtrends.com/cgi-bin/rest/search/" + encodeURIComponent($scope.terms) + '?' + query ).success(function(response) {
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
        url: 'http://www.patchtrends.com/cgi-bin/rest/search/' + terms + '?' + query, 
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

}]);
