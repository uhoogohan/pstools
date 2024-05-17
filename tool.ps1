<#------------------------------------------------------------------
 Windows Server をキッティングします
------------------------------------------------------------------#>
using module ".\menu.psm1"
. (join-path $PSScriptRoot "def.ps1")

class Host : Menu {
  Host($x, $y, $param) : base($x, $y, "ホスト名の設定") {
    $s = gwmi win32_computersystem
    $this.body += [MenuItem]::new(7, 5, "設定確認", {sysdm.cpl})
    $this.body += [MenuItem]::new(7, 7, "設定実行", $this.config)
    $this.foot += [Caption]::new(7, 11, "* 現在の設定")
    $this.foot += [Caption]::new(7, 13, ("ホスト名       : "+$s.name))
    $this.foot += [Caption]::new(7, 14, ("ワークグループ : "+$s.domain))
    $this.foot += [Caption]::new(7, 17, "* 変更後の設定")
    $this.foot += [Caption]::new(7, 19, ("ホスト名       : "+$param.host_name))
    $this.foot += [Caption]::new(7, 20, ("ワークグループ : "+$param.domain))
    $this.foot += [Caption]::new(7, 23, "* 実行後、再起動します")
  }

  $config = {
    clear
    $ch = $false
    $s = gwmi win32_computersystem
    if($s.name -ne $param.host_name) {
      $s.rename($param.host_name)
      $ch = $true
    }
    if($s.domain -ne $param.domain) {
      Add-Computer -WorkgroupName $param.domain
      $ch = $true
    }
    if($ch -eq $true) {
      restart-computer
    }
  }
}

class Network : Menu {
  Network($x, $y, $nw) : base($x, $y, "ネットワーク設定") {
    $this.body += [RenameIfs]::new(7, 5, $nw)
    $this.body += [Lbfo]::new(7, 7, $nw)
    $this.body += [Binding]::new(7, 9, $nw)
    $this.body += [IPAddr]::new(7, 11, $nw)
    $this.body += [MenuItem]::new(7, 13, "ncpa.cpl", {ncpa.cpl})
  }
}

class RenameIfs : Menu {
  RenameIfs($x, $y, $nw) : base ($x, $y, "NICのポート名の変更") {
    $this.body += [MenuItem]::new(7, 5, "設定実行", $this.config)
    $this.foot += [Caption]::new(7, 8, "* 次の名前に変更します*")
    $i = 10
    foreach($r in $nw.rename_ifs) {
      $this.foot += [Caption]::new(7, $i, ($r.name +" => "+ $r.newname)); $i+=1
    }
  }

  $config = {
    clear
    foreach($r in $param.nw.rename_ifs) {
      rename-netadapter @r
    }
    pause
  }
}

class Lbfo : Menu {
  Lbfo($x, $y, $nw) : base($x, $y, "チーミング") {
    $this.body += [MenuItem]::new(7, 5, "設定確認", $this.confirm)
    $this.body += [MenuItem]::new(7, 7, "設定実行", $this.config)
    $this.foot += [Caption]::new(7, 10, "* 次の値を追加します")
    $this.foot += [Caption]::new(9, 12, ("チーム名         : " + $nw.lbfo1.Name))
    $this.foot += [Caption]::new(9, 13, ("メンバー         : " + $nw.lbfo1.TeamMembers))
    $this.foot += [Caption]::new(9, 14, ("チーミングモード : " + $nw.lbfo1.TeamingMode))
    $this.foot += [Caption]::new(9, 15, ("不可分散モード   : " + $nw.lbfo1.LoadBalancingAlgorithm))
    $this.foot += [Caption]::new(9, 16, ("スタンバイポート : " + $nw.lbfo2.Name))
  }

  $config = {
    clear
    $lbfo1 = $param.nw.lbfo1
    $lbfo2 = $param.nw.lbfo2
    New-NetLbfoTeam @lbfo1
    Set-NetLbfoTeamMember @lbfo2
    pause
  }

  $confirm = {
    lbfoadmin
  }
}

class Binding : Menu {
  Binding($x, $y, $nw) : base($x, $y, "バインディング") {
    $this.body += [MenuItem]::new(7, 5, "設定実行", $this.config)
    $this.foot += [Caption]::new(7, 8, "* 次の値に設定します")
    $i=10
    foreach($r in $nw.ifs) {
      $this.foot += [Caption]::new(9, $i, ("接続名 : "+ $r.name)); $i+=2
      foreach($x in $r.bindings) {
        $this.foot += [Caption]::new(9, $i, ($nw.binding_dscr[$x.ComponentID]+" : "+$x.Enabled)); $i+=1
      }$i+=2
    }
  }

  $config = {
    clear
    foreach($r in $param.nw.ifs) {
      foreach($x in $r.bindings) {
        set-netadapterbinding -Name $r.name @x
      }
    }
    pause
  }
}

class IPAddr : Menu {
  IPAddr($x, $y, $nw) : base($x, $y, "IPアドレス") {
    $this.body += [MenuItem]::new(7, 5, "設定実行", $this.config)
    $this.foot += [Caption]::new(7, 8, "* 次の値を追加します")
    $i=10
    foreach($r in $nw.ifs) {
      if($r.ip -ne $null) {
        $this.foot += [Caption]::new(9, $i, ("接続名     : "+ $r.name)); $i+=1
        $this.foot += [Caption]::new(9, $i, ("IPアドレス : "+ $r.ip.IPAddress + "/"+ $r.ip.PrefixLength)); $i+=1
        $this.foot += [Caption]::new(9, $i, ("デフォゲ   : "+ $r.ip.DefaultGateway)); $i+=1
        $this.foot += [Caption]::new(9, $i, ("DNSサーバ  : "+ $r.dns.ServerAddress)); $i+=1
      }
      if($r.register -eq $false) {
        $this.foot += [Caption]::new(9, $i, "* この接続のアドレスをDNSに登録する のチェックを外します"); $i+=1
      }
    }
    if($nw.enablewins -eq $false) {
       $i+=3
       $this.foot += [Caption]::new(9, $i, "* LMHOSTSの参照を有効にする のチェックを外します")
    }
  }

  $config = {
    clear
    foreach($r in $param.nw.ifs) {
      if($r.ip -ne $null) {
        $ip = $r.ip
        New-NetIPAddress -IfAlias $r.name @ip
        if($r.register -eq $false) {
          $cmd = "netsh int ip set dnsservers name=`"" + $r.name + "`" source=dhcp register=none"
          invoke-expression $cmd
        }
        if($r.dns -ne $null) {
          $dns = $r.dns
          Set-DnsClientServerAddress $r.name @dns
        }
      }
    }
    if($param.nw.enablewins -eq $false) {
      $nicClass = Get-WmiObject -list Win32_NetworkAdapterConfiguration
      $nicClass.enablewins($false,$false)
    }
    pause
  }
}

class Root : Menu {
  Root($param, $serial) : base(0, 0, "Windows Server 設定ツール") {
    $this.body += [Host]::new(7, 5, $param)
    $this.body += [Network]::new(7, 7, $param.nw)
    $this.foot += [Caption]::new(7, 10, "** S/N : $serial")
  }
}

$root = [Root]::new($param, $serial)
$root.exe()
