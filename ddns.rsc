# Script for updating DDNS records on FreeDNS.afraid.org
# Script uses ideas by Chupakabra303 # http://habrahabr.ru/post/270719/
# tested on ROS 6.49.19 & 7.20.4
# updated 2025/12/09

:do {
  :local dmnDNS "aaa.xyz.com"
  :local subDmnHsh "TElRcWlwRzNYMHNnZ2NCR5VmiE92a2pnOjE5MTg19DM4"
  
  # search of interface-list gateway
  :local GwFinder do={ # no input parameters
    :local routeISP [/ip route find dst-address=0.0.0.0/0 active=yes]; :if ([:len $routeISP]=0) do={:return ""}
    :set routeISP "/ip route get $routeISP"; /interface
    :local routeGW {"[$routeISP vrf-interface]";"[$routeISP immediate-gw]";"[$routeISP gateway-status]"}
    :foreach ifLstMmb in=[list member find] do={
      :local ifIfac [list member get $ifLstMmb interface]
      :local brName ""; :do {:set brName [bridge port get [find interface=$ifIfac] bridge]} on-error={}
      :foreach answer in=$routeGW do={
        :local gw ""; :do {:set gw [:tostr [[:parse $answer]]]} on-error={}
        :if ([:len $gw]>0 && $gw~$ifIfac) do={:return $ifIfac}
        :if ([:len $brName]>0 && $gw~$brName) do={:return $brName}}}
    :return ""}

  # external IP address return function # https://forummikrotik.ru/viewtopic.php?p=65345#p65345
  :local ExtIP do={
    # function of cutting out unnecessary characters # https://forum.mikrotik.com/viewtopic.php?p=714396#p714396
    :local ConvSymb do={
      :if ([:typeof $1]!="str" or [:len $1]=0) do={:return ""}
      :local allowSymb "0123456789."; :local res ""
      :for i from=0 to=([:len $1]-1) do={
        :local chr [:pick $1 $i]
        :local pos [:find $allowSymb $chr]; :if ($pos>-1) do={} else={:set chr ""}
        :set res ($res.$chr)}
      :return $res}

    :local addr {{mode="http";url="checkip.amazonaws.com"};{mode="http";url="icanhazip.com"};{mode="http";url="checkip.dyndns.org"}}
    :local resp ""
    :foreach payLoad in=$addr do={
      :put "Request data from '$($payLoad->"mode")://$($payLoad->"url")'";
      :do {:set resp [/tool fetch mode=($payLoad->"mode") url="$($payLoad->"mode")://$($payLoad->"url")" as-value output=user]} on-error={}
      :if ([:len $resp]!=0) do={
        :local content [$ConvSymb ($resp->"data")]; :put "Response received: '$content'"
        :if ($content~"((25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)[.]){3}(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)") do={
          :return [[:parse ":return $content"]]}
      } else={:put "No response received"}}
    :return "Unknown"}

  # main body
  :global lastIP
  :put "Start of updating DDNS script on router: '$[/system identity get name]'"
  :local ifcWAN [$GwFinder]; # search gw interface
  :local remark ""; :local currIP ""
  :do {:set remark [/interface get [find name=$ifcWAN] comment]} on-error={}
  :do {:set currIP [/ip dhcp-client get [find interface=$ifcWAN] address]} on-error={}
  :set $currIP [:pick $currIP 0 [:find $currIP "/"]]
  :if ($currIP~"192.168([.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)){2}" or \
    $currIP~"10([.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)){3}") do={
      :put "IP '$currIP' is private"; :set $currIP [$ExtIP]}; # private adresses: 192.168.0.0/16 or 10.0.0.0/8
  :local msg ">>> External IP '$currIP' on '$ifcWAN' with comment '$remark'"
  :if ([:len $currIP]>0 && $currIP!="Unknown" && $currIP!=$lastIP) do={
    :set msg "$msg changed for '$dmnDNS' (old IP '$lastIP')"
    :log warning ">>> DynDNS: Old IP '$lastIP' for '$dmnDNS' change to IP '$currIP' on '$ifcWAN'"
    :local url "http://freedns.afraid.org/dynamic/update.php\?$subDmnHsh&address=$currIP"; :local method "put"; # or "post"
    /tool fetch http-method=$method url=$url keep-result=no
    :set lastIP $currIP
  } else={:set msg "$msg nothing has changed"}
  :put $msg
} on-error={log warning "Error on script of updating DDNS records"}
