add-type -AssemblyName System.Windows.Forms
$kmp = [Windows.Forms.Keys]
$rui = $host.UI.RawUI
. ".\def.ps1"

# メニュー表示
function show_menu($head, $body, $foot)
{
  $init = $true
  $i = 0
  do {
    if($init) {
      clear
      foreach($s in $head) {mv_cur $s.x $s.y; write-host $s.caption}
      foreach($s in $body) {mv_cur $s.x $s.y; write-host $s.caption}
      foreach($s in $foot) {mv_cur $s.x $s.y; write-host $s.caption}
      $init = $false;
    }

    $s = $body[$i]

    mv_cur $s.x $s.y
    write-host $s.caption -F "Black" -B "White"
    mv_cur $s.x $s.y

    $kif = $rui.ReadKey("NoEcho,IncludeKeyDown")
    $kcd = $kif.VirtualKeyCode

    if($kcd -in ($kmp::Up, $kmp::Left)) {
      write-host $s.caption; $i-=1 
      if($i -lt 0) { $i = $body.length - 1 }
    }

    if($kcd -in ($kmp::Down, $kmp::Right)) {
      write-host $s.caption; $i+=1
      if($i -ge $body.length) { $i = 0; }
    }

    if($kcd -eq $kmp::Enter) {
      $s.exe()
      $init = $true;
    }
  }
  until($kcd -in ($kmp::Escape, $kmp::Q))
  clear
}

# カーソル移動
function mv_cur($x, $y) {
  $cd = New-Object System.Management.Automation.Host.Coordinates $x, $y
  $rui.CursorPosition = $cd
}

class Caption {
  $x; $y; $caption

  Caption($x, $y, $caption) {
    $this.x = $x; $this.y = $y; $this.caption = $caption
  }
}

class Menu : Caption {
  $head = @(); $body = @(); $foot = @()

  Menu($x, $y, $caption) : base ($x, $y, $caption) {
    $title = "** "+ $caption + " **"
    $this.head += new-object Caption(7, 2, $title)
  }

  exe() {
    show_menu $this.head $this.body $this.foot
  }
}

class MenuItem : Caption {
  $cmd

  MenuItem($x, $y, $caption, $cmd) : base($x, $y, $caption) {
    $this.cmd = $cmd
  }

  exe() {
    &($this.cmd)
  }
}

class Host : Menu {
  Host($x, $y, $param) : base($x, $y, "ホスト名の設定") {
    $s = gwmi win32_computersystem
    $this.body += new-object MenuItem(7, 5, "設定確認", {sysdm.cpl})
    $this.body += new-object MenuItem(7, 7, "設定実行", $this.config)
    $this.foot += new-object Caption(7, 11, "* 現在の設定")
    $this.foot += new-object Caption(7, 13, ("ホスト名       : "+$s.name))
    $this.foot += new-object Caption(7, 14, ("ワークグループ : "+$s.domain))
    $this.foot += new-object Caption(7, 17, "* 変更後の設定")
    $this.foot += new-object Caption(7, 19, ("ホスト名       : "+$param.host_name))
    $this.foot += new-object Caption(7, 20, ("ワークグループ : "+$param.domain))
    $this.foot += new-object Caption(7, 23, "* 実行後、再起動します")
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
    $this.body += new-object RenameIfs(7, 5, $nw)
    $this.body += new-object Lbfo(7, 7, $nw)
    $this.body += new-object Binding(7, 9, $nw)
    $this.body += new-object IPAddr(7, 11, $nw)
    $this.body += new-object MenuItem(7, 13, "ncpa.cpl", {ncpa.cpl})
  }
}

class RenameIfs : Menu {
  RenameIfs($x, $y, $nw) : base ($x, $y, "NICのポート名の変更") {
    $this.body += new-object MenuItem(7, 5, "設定実行", $this.config)
    $this.foot += new-object Caption(7, 8, "* 次の名前に変更します*")
    $i = 10
    foreach($r in $nw.rename_ifs) {
      $this.foot += new-object Caption(7, $i, ($r.name +" => "+ $r.newname)); $i+=1
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
    $this.body += new-object MenuItem(7, 5, "設定確認", $this.confirm)
    $this.body += new-object MenuItem(7, 7, "設定実行", $this.config)
    $this.foot += new-object Caption(7, 10, "* 次の値を追加します")
    $this.foot += new-object Caption(9, 12, ("チーム名         : " + $nw.lbfo1.Name))
    $this.foot += new-object Caption(9, 13, ("メンバー         : " + $nw.lbfo1.TeamMembers))
    $this.foot += new-object Caption(9, 14, ("チーミングモード : " + $nw.lbfo1.TeamingMode))
    $this.foot += new-object Caption(9, 15, ("不可分散モード   : " + $nw.lbfo1.LoadBalancingAlgorithm))
    $this.foot += new-object Caption(9, 16, ("スタンバイポート : " + $nw.lbfo2.Name))
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
    $this.body += new-object MenuItem(7, 5, "設定実行", $this.config)
    $this.foot += new-object Caption(7, 8, "* 次の値に設定します")
    $i=10
    foreach($r in $nw.ifs) {
      $this.foot += new-object Caption(9, $i, ("接続名 : "+ $r.name)); $i+=2
      foreach($x in $r.bindings) {
        $this.foot += new-object Caption(9, $i, ($nw.binding_dscr[$x.ComponentID]+" : "+$x.Enabled)); $i+=1
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
    $this.body += new-object MenuItem(7, 5, "設定実行", $this.config)
    $this.foot += new-object Caption(7, 8, "* 次の値を追加します")
    $i=10
    foreach($r in $nw.ifs) {
      if($r.ip -ne $null) {
        $this.foot += new-object Caption(9, $i, ("接続名     : "+ $r.name)); $i+=1
        $this.foot += new-object Caption(9, $i, ("IPアドレス : "+ $r.ip.IPAddress + "/"+ $r.ip.PrefixLength)); $i+=1
        $this.foot += new-object Caption(9, $i, ("デフォゲ   : "+ $r.ip.DefaultGateway)); $i+=1
        $this.foot += new-object Caption(9, $i, ("DNSサーバ  : "+ $r.dns.ServerAddress)); $i+=1
      }
      if($r.register -eq $false) {
        $this.foot += new-object Caption(9, $i, "* この接続のアドレスをDNSに登録する のチェックを外します"); $i+=1
      }
    }
    if($nw.enablewins -eq $false) {
       $i+=3
       $this.foot += new-object Caption(9, $i, "* LMHOSTSの参照を有効にする のチェックを外します")
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
    $this.body += new-object Host(7, 5, $param)
    $this.body += new-object Network(7, 7, $param.nw)
    $this.foot += new-object Caption(7, 10, "** S/N : $serial")
  }
}

$root = new-object Root($param, $serial)
$root.exe()
