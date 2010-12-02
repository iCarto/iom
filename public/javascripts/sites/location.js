
    $(document).ready( function() {
      
      //If right part is bigger than float left
      if ($('div#left_column div.float_left').height() < $('div#left_column div.right').height()) {
        var offset =  $('div#left_column div.right').height() - $('div#left_column div.float_left').height() + 120;
        $('div#left_column div.float_left div.block:last').height(offset);
      }
      
      if ($('div#left_column div.float_left').height() > $('div#left_column div.left').height()) {
        $('div#left_column div.left').height($('div#left_column div.float_left').height());
      }
      
      
      
      var myOptions = {
            zoom: 4,
            center: new google.maps.LatLng(40.4166909, -3.7003454),
            disableDefaultUI: true,
            mapTypeId: google.maps.MapTypeId.ROADMAP
          }
      var map = new google.maps.Map(document.getElementById("map"),myOptions);
      var map2 = new google.maps.Map(document.getElementById("secondary_map"),myOptions);
      map2.setCenter(new google.maps.LatLng(40.42245660632275, -3.699495792388916));
      map2.setZoom(17);
    });