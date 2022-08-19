'use strict';

var myCharts = angular.module('myCharts', ["highcharts-ng"]);

myCharts.controller('myctrl', [ '$scope', '$http', function ($scope, $http) {

  $scope.search = { perPage: 100, orderBy: 'date' };
  $scope.chartSeries = [];
  $scope.termsList = [];

  $scope.clear=function() {
    $scope.chartSeries = []; 
    $scope.termsList = [];
    $scope.reflow();
    return;
  };

  $scope.doSearch=function() {
    var terms  = encodeURIComponent($scope.terms); 
    var limit  = encodeURIComponent($scope.search.perPage); 
    var sortBy = encodeURIComponent($scope.search.orderBy); 
    $scope.termsList.push($scope.terms);
    var data = [];
    var url = 'http://www.patchtrends.com/cgi-bin/rest/search/'+terms+'?descending=true&matchMode=any&primaryCategory=all&minBidCount=1&maxBidCount=500&minBidAmount=0&maxBidAmount=100000&orderBy=date&beginDate=1417413600&endDate=1420005600&perPage=forplot';
    $http.get(url).success(function(response) {
        $scope.items=response;
        var c = 0;
        angular.forEach(response, function (item) {
          data.push([ item.endtime*1000, item.bidcount ]);
        });
    });
    $scope.chartSeries.push ( {   
        name: $scope.terms,
        data: data,
    } );
    $scope.reflow = function () {
      $scope.$broadcast('highchartsng.reflow');
    };

    console.log($scope.data);
    return;
  }

  $scope.chartTypes = [
    //{"id": "line", "title": "Line"},
    //{"id": "spline", "title": "Smooth line"},
    //{"id": "area", "title": "Area"},
    //{"id": "areaspline", "title": "Smooth area"},
    //{"id": "column", "title": "Column"},
    //{"id": "bar", "title": "Bar"},
    //{"id": "pie", "title": "Pie"},
    {"id": "scatter", "title": "Scatter"  }
  ];

  $scope.chartConfig = {
    options: {
      chart: {
        type: 'scatter'
      }
    },
    xAxis: {
       type: 'datetime',
       dateTimeLabelFormats: {
         day: '%e of %b'
       },
       title: {
         text: 'Date'
       },
    },
    yAxis: {
      title: {
         text: 'Bids'
      }
    },
    series: $scope.chartSeries,
    title: {
      text: 'Scatter Series'
    },
    loading: false,
    size: {}
  }

  $scope.reflow = function () {
    $scope.$broadcast('highchartsng.reflow');
  };

}]);
