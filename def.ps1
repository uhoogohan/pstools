$params = @{
  "XYZ123S2C5" = @{host_name = "hostname4" ; ipaddr1 = "192.168.1.64"; gw1 = "192.168.1.1"}
  "XYZ123S2C9" = @{host_name = "hostname3" ; ipaddr1 = "192.168.1.94"; gw1 = "192.168.1.1"}
  "XYZ123S2C6" = @{host_name = "hostname2" ; ipaddr1 = "192.168.1.84"; gw1 = "192.168.1.1"}
  "XYZ123VDED" = @{host_name = "hostname1" ; ipaddr1 = "192.168.1.74"; gw1 = "192.168.1.1"}
}

#$serial    = (gwmi win32_bios).SerialNumber  # このコンピュータのシリアル№
$serial    = "XYZ123S2C9"
$uhoo      = $params[$serial]
$host_name = $uhoo.host_name       # ホスト名
$ipaddr1   = $uhoo.ipaddr1         # IPv4アドレス -1
$gw1       = $uhoo.gw1             # デフォゲ -1
$team_name = "team_" + $host_name  # チーム名

$param = @{

  # ホスト名
  host_name = $host_name
  domain    = "WORKGROUP"

  # ネットワークのプロパティ
  nw = @{

    # ポート名の変更
    rename_ifs = @(
       @{Name = "Ethernet0" ; NewName = "Eth1"}
       @{Name = "Ethernet1" ; NewName = "Eth5"}
     )

    # チーミングの設定
    lbfo1 = @{
      Name = $team_name
      TeamMembers  = ("Eth1","Eth5")
      TeamingMode  = "SwitchIndependent"
      LoadBalancingAlgorithm = "Dynamic"
      Confirm = $false
    }

    lbfo2 = @{
      Name = "Eth5"
      AdministrativeMode = "Standby"
    }

    # 接続の設定
    ifs = @(
      # インタフェイス-1 
      @{
        name = $team_name
     
        # バインディング (既定値を変更する ComponentID だけ追加し、enabled 属性を与えてください)
        bindings  = @(
          @{ComponentID = "ms_tcpip6"; Enabled = $false}
        )
     
        # IPv4アドレス (個別パラメータの $ipaddr1 を参照しています)
        ip = @{IPAddress = $ipaddr1; PrefixLength = 24; DefaultGateway = $gw1}
     
        # DNSサーバ
        dns = @{ServerAddress = @('192.168.0.2','192.168.0.1')}
     
        # $false を指定すると「この接続のアドレスをDNSに登録する」のチェックを外します
        register = $false
      }
    )

    # false を指定すると「LMHOSTS の参照を有効にするチェック」のを外します
    enablewins = $true

    # コンポーネントIDとその説明
    binding_dscr = @{
      ms_rspndr    = "Link-Layer Topology Discovery Responder"
      ms_lltdio    = "Link-Layer Topology Discovery Mapper I/O Driver"
      ms_implat    = "Microsoft Network Adapter Multiplexor Protocol"
      ms_msclient  = "Microsoft ネットワーク用クライアント"
      ms_netftflt  = "Microsoft Failover Cluster Virtual Adapter Performance Filter"
      ms_bridge    = "Microsoft MAC Bridge"
      ms_lbfo      = "Microsoft Load Balancing/Failover Provider"
      ms_pacer     = "QoS パケット スケジューラ"
      ms_server    = "Microsoft ネットワーク用ファイルとプリンター共有"
      ms_tcpip6    = "インターネット プロトコル バージョン 6 (TCP/IPv6)"
      ms_tcpip     = "インターネット プロトコル バージョン 4 (TCP/IPv4)"
    }
  }
}
