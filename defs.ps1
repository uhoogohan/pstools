# このファイルは tools.ps1 のパラメータを定義したファイルです。
#

# 集合パラメータ
# 左辺をシリアル№、右辺を個別パラメータとしてハッシュテーブルを定義してください。

$params = @{
  "XYZ123S2C5" = @{host_name = "hostname4" ; ipaddr1 = "192.168.1.64"; gw1 = "192.168.1.1"}
  "XYZ123S2C9" = @{host_name = "hostname3" ; ipaddr1 = "192.168.1.94"; gw1 = "192.168.1.1"}
  "XYZ123S2C6" = @{host_name = "hostname2" ; ipaddr1 = "192.168.1.84"; gw1 = "192.168.1.1"}
  "XYZ123VDED" = @{host_name = "hostname1" ; ipaddr1 = "192.168.1.74"; gw1 = "192.168.1.1"}
}


# 個別のパラメータ
# 集合パラメータの中からこのコンピュータのシリアル№と一致した値が、個別パラメータに設定されます。

$serial    = (gwmi win32_bios).SerialNumber  # このコンピュータのシリアル№
$host_name = $params[$serial].host_name      # ホスト名
$team_name = "team_" + $host_name            # チーム名
$ipaddr1   = $params[$serial].ipaddr1        # IPv4アドレス -1
$gw1       = $params[$serial].gw1            # デフォゲ -1


# 共通パラメータ
# 全体を通して共通した値をここで定義してください。

$param = @{

  # ホスト名

  host_name = $host_name
  domain    = "WORKGROUP"


  # ディスクの設定

  disks = @(
    @{id=1; lun=0; letter="D"; size=460800; label="ボリューム"}
    @{id=2; lun=0; letter="E"; size=153600; label="ボリューム"}
    @{id=3; lun=0; letter="F"; size= 40960; label="ボリューム"}
    @{id=4; lun=0; letter="G"; size= 18186; label="ボリューム"}
    @{id=5; lun=0; letter="H"; size= 51200; label="ボリューム"}
    @{id=6; lun=0; letter="I"; size= 30720; label="ボリューム"}
    @{id=7; lun=1; letter="J"; size=921600; label="ボリューム"}
  )


  # ネットワークのプロパティ

  nw = @{

    # ポート名の変更

    rename_ifs = @(
      @{Name = "Ethernet0"   ; NewName = "Eth1"}
      @{Name = "Ethernet1"   ; NewName = "Eth5"}
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


  # システムのプロパティ

  sys = @{

    # ページング

    pagefile = @{
      Drive       = "C"
      InitialSize = 1024
      MaximumSize = 1024
    }

    # メモリダンプ

    memdump = @{
      AutoReboot    = $false      # $false :「自動的に再起動する」のチェックを外します
      DebugInfoType = 1           # debug_info_dsc を参照
      Mkdir         = $true       # $true : ディレクトリを作成します
      DebugFilePath = "C:\dump"   # ディレクトリ名を指定します

      debug_info_dsc = @{
        1 = "完全メモリダンプ"
        2 = "カーネルメモリダンプ"
        3 = "最小メモリダンプ (64KB)"
      }
    }

  }


  # リモートデスクトップ

  mstsc = @{
    # ネットワークレベル認証でリモートデスクトップを実行しているコンピュータからのみ接続を許可する
    # $false を指定すると、このチェックを外します
    UserAuthentication = $false
  }


  # キーボードダンプ    # 有効化するものだけコメントを外してください

  kbdump = @(
    @{name = "i8042prt"}
    @{name = "kbdhid"}
    @{name = "hyperkbd"}
  )


  # SNPの設定    # 設定するものだけコメントを外してください

  snp = @(
    @{name = "rss";     action = "disabled"}
    #@{name = "chimney"; action = "disabled"}
    #@{name = "netdma";  action = "disabled"}
  )


  # SMB3.0の設定  # 無効にするときは enabled = $false にしてコメントを外してください

  smb = @(
    #@{name = "Set-SmbServerConfiguration"; enabled = $false}   # サーバ
    #@{name = "Set-SmbClientConfiguration"; enabled = $false}   # クライアント
  )

}

