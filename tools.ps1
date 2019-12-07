[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
add-type -AssemblyName Microsoft.VisualBasic
add-type -AssemblyName System.Windows.Forms

$OutputEncoding = [Console]::OutputEncoding
$kmp = [Windows.Forms.Keys]
$rui = $host.UI.RawUI
. ".\defs.ps1"

# メニュー表示
function show_menu($head, $body, $foot)
{
  $init = $true
  $i = 0
  do {
    if($init) {
      clear
      foreach($s in $head) { mv_cur $s.x $s.y; write-host $s.caption }
      foreach($s in $body) { mv_cur $s.x $s.y; write-host $s.caption }
      foreach($s in $foot) { mv_cur $s.x $s.y; write-host $s.caption }
      $init = $false;
    }

    $s = $body[$i]

    mv_cur $s.x $s.y
    write-host $s.caption -F "Black" -B "White"
    mv_cur $s.x $s.y

    $kif = $rui.ReadKey("NoEcho,IncludeKeyDown")
    $kcd = $kif.VirtualKeyCode

    if($kcd -in ($kmp::Up, $kmp::Left)) {
      write-host $s.caption; $i -= 1 
      if($i -lt 0) { $i = $body.length - 1 }
    }

    if($kcd -in ($kmp::Down, $kmp::Right)) {
      write-host $s.caption; $i += 1
      if($i -ge $body.length) { $i = 0; }
    }

    if($kcd -eq $kmp::Enter) {
      &($s.exe)
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

# プロセス起動、SendKeys、スクショ
function scr($pname, $arr, $arg=@{})
{
  try {
    $p = Start-Process $pname -PassThru @arg
    start-sleep -Milliseconds 2000
  }
  catch {
    clear; write-host $_.exception
    start-sleep -Milliseconds 2000; return
  }

  #try { [Microsoft.VisualBasic.Interaction]::AppActivate($p.id) } catch {}

  foreach($r in $arr) {
    [System.Windows.Forms.SendKeys]::SendWait($r["key"])
    start-sleep -Milliseconds 2000

    if($r["prtsc"] -eq $true) {
      [System.Windows.Forms.SendKeys]::SendWait("^{prtsc}")
      start-sleep -Milliseconds 2000
    }
  }

  try { $p.kill() } catch {}
}

$row=3

$caption = "ディスクの設定" ; $row+=2
$disk = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y=2; caption="** "+$disk.menu.caption+" **"})
      $body = @($disk.confirm, $disk.config)
      $foot = @(
        @{x= 7; y=11; caption="* 構成"}
        @{x= 7; y=13; caption="#LUN  ドライブ   サイズ(MB)  ラベル"}
        $i=14
        foreach($r in $param.disks) {
          $i+=1
          @{x= 9; y=$i; caption= $r.lun}
          @{x=16; y=$i; caption= $r.letter+":"}
          @{x=23; y=$i; caption= "{0,10}" -f $r.size}
          @{x=36; y=$i; caption= $r.label}
        }
        $i+=2; @{x= 7; y=$i; caption="* diskpart /s df.conf としてパーティションを自動で作成できます"}
      )
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $disk.menu.caption | clip
      $arr = @(
        @{key="% x"; prtsc=$true}
        @{key="^{tab}{down 5}"; prtsc=$true}
      )
      scr "diskmgmt.msc" $arr
    }
  }
  config = @{
    x=7; y=7; caption="df.confを出力します"
    exe = {
      clear
      $file = $pwd.path + "\df.conf"
      echo "" > $file
      foreach($r in $param.disks) {
        $s = "select disk "+ $r.lun; echo $s >> $file
        $s = "create partition primary size="+ $r.size; echo $s >> $file
        $s = "format fs=ntfs label=`""+ $r.label +"`" quick"; echo $s >> $file
        $s = "assign letter="+ $r.letter; echo $s >> $file
        echo "" >> $file
      }
      notepad $file
      pause
    }
  }
}

$caption = "ホスト名の設定" ; $row+=2
$hosts = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y=2; caption="** "+$hosts.menu.caption+" **"})
      $body = @($hosts.confirm, $hosts.config)
      $s = gwmi win32_computersystem
      $foot = @(
        @{x= 7; y=11; caption="* 現在の設定"}
        @{x= 7; y=13; caption="ホスト名       : "+ $s.name}
        @{x= 7; y=14; caption="ワークグループ : "+ $s.domain}
        @{x=47; y=11; caption="* 変更後の設定"}
        @{x=47; y=13; caption="ホスト名       : "+ $param.host_name}
        @{x=47; y=14; caption="ワークグループ : "+ $param.domain}
        @{x= 7; y=16; caption="* 実行後、再起動します"}
      )
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $hosts.menu.caption | clip
      $arr = @(
        @{key=""; prtsc=$true}
      )
      scr "SystemPropertiesComputerName" $arr
    }
  }
  config = @{
    x=7; y=7; caption="設定実行"
    exe = {
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
}

$caption = "ネットワーク設定" ; $row+=2
$nw = @{
  row = 0
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$nw.menu.caption+" **"})
      $body = @(
        $nw.confirm
        $nw.rename_if.menu
        $nw.teaming.menu
        $nw.binding.menu
        $nw.ipaddr.menu
        $nw.ncpa
      )
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = { 
      foreach($r in $param.nw.ifs) {
        $s = $nw.menu.caption +" - "+ $r.name
        echo $s | clip
        $arr = @(
          @{key="% x"; prtsc=$true}
          @{key="^f"+ $r.name.substring(0,5) +"{tab 2}"; prtsc=$false}
          @{key="{down}"; prtsc=$true}
          @{key="{f10}fr"; prtsc=$true}
          @{key="{pgdn 2}"; prtsc=$true}

          if($r.ip -ne $null) {
            #@{key="{up 2}"; prtsc=$false}  # 環境依存につき適宜調整方
            @{key="%r"; prtsc=$true}
            @{key="%v"; prtsc=$false}
            @{key="^{tab}"; prtsc=$true}
            @{key="^{tab}"; prtsc=$true}
            @{key="{esc 2}"; prtsc=$false}
          }
          @{key="{esc}^w"; prtsc=$false}
        )
        scr "ncpa.cpl" $arr
      }
      if($param.nw.ifs.length -gt 1) {
        $arr = @(
          @{key="% x"; prtsc=$false}
          @{key="%ns"; prtsc=$true}
          @{key="{esc}"; prtsc=$false}
          @{key="{esc}^w"; prtsc=$false}
        )
        scr "ncpa.cpl" $arr
      }
      $s = $nw.menu.caption +" - チーミング設定"
      echo $s | clip
      $arr = @(
        @{key="^{tab 4}{down 2}{right}"; prtsc=$false}
        @{key="~%a"; prtsc=$true}
        #@{key="{esc}%{f4}"; prtsc=$false}
      )
      scr "lbfoadmin" $arr
    }
  }
  rename_if = @{
    menu = @{
      x=7; y=7; caption="NICのポート名の変更"
      exe = {
        $head = @(@{x=7; y= 2; caption="** "+$nw.menu.caption+" - "+$nw.rename_if.menu.caption+" **"})
        $body = @($nw.rename_if.config)
        $i = 10
        $foot = @(
          @{x=7; y= 8; caption="* 次の名前に変更します*"}
          foreach($r in $param.nw.rename_ifs) {
            @{x=7; y=$i; caption= $r.name +" => "+ $r.newname}; $i+=1
          }
        )
        show_menu $head $body $foot
      }
    }
    config = @{
      x=7; y=5; caption="設定実行"
      exe = {
        clear
        foreach($r in $param.nw.rename_ifs) {
          rename-netadapter @r
        }
        pause
      }
    }
  }
  teaming = @{
    menu = @{
      x=7; y=9; caption="チーミング"
      exe = {
        $head = @(@{x=7; y= 2; caption="** "+$nw.menu.caption+" - "+$nw.teaming.menu.caption+" **"})
        $body = @($nw.teaming.config)
        $foot = @(
          $lbfo1 = $param.nw.lbfo1
          $lbfo2 = $param.nw.lbfo2
          @{x=7; y= 8; caption="* 次の値を追加します"}
          @{x=9; y=10; caption="チーム名         : " + $lbfo1.Name}
          @{x=9; y=11; caption="メンバー         : " + $lbfo1.TeamMembers}
          @{x=9; y=12; caption="チーミングモード : " + $lbfo1.TeamingMode}
          @{x=9; y=13; caption="不可分散モード   : " + $lbfo1.LoadBalancingAlgorithm}
          @{x=9; y=14; caption="スタンバイポート : " + $lbfo2.Name}
        )
        show_menu $head $body $foot
      }
    }
    config = @{
      x=7; y=5; caption="設定実行"
      exe = {
        clear
        $lbfo1 = $param.nw.lbfo1
        $lbfo2 = $param.nw.lbfo2
        New-NetLbfoTeam @lbfo1
        Set-NetLbfoTeamMember @lbfo2
        pause
      }
    }
  }
  binding = @{
    menu = @{
      x=7; y=11; caption="バインディング"
      exe = {
        $head = @(@{x=7; y= 2; caption="** "+$nw.menu.caption+" - "+$nw.binding.menu.caption+" **"})
        $body = @($nw.binding.config)
        $foot = @(
          @{x=7; y= 8; caption="* 次の値に設定します"}
          $i = 10
          foreach($r in $param.nw.ifs) {
            @{x=9; y=$i; caption= "接続名 : "+ $r.name}; $i+=2
            foreach($x in $r.bindings) {
              @{x=9; y=$i; caption=$param.nw.binding_dscr[$x.ComponentID]+" : "+$x.Enabled}; $i+=1
            }$i+=2
          }
          @{x=7; y=$i; caption="* 恐れ入りますが次のものは手動でインストールしてください"}
          @{x=7; y=$i+2; caption="  " +$param.nw.binding_dscr["ms_netftflt"]}
        )
        show_menu $head $body $foot
      }
    }
    config = @{
      x=7; y=5; caption="設定実行"
      exe = {
        clear
        foreach($r in $param.nw.ifs) {
          foreach($x in $r.bindings) {
            set-netadapterbinding -Name $r.name @x
          }
        }
        pause
      }
    }
  }
  ipaddr = @{
    menu = @{
      x=7; y=13; caption="IPアドレス"
      exe = {
        $head = @(@{x=7; y= 2; caption="** "+$nw.menu.caption+" - "+$nw.ipaddr.menu.caption+" **"})
        $body = @($nw.ipaddr.config)
        $foot = @(
          @{x=7; y= 8; caption="* 次の値を追加します"}; $i=10
          foreach($r in $param.nw.ifs) {
            if($r.ip -ne $null) {
              @{x=9; y=$i; caption= "接続名     : "+ $r.name}; $i+=1
              @{x=9; y=$i; caption= "IPアドレス : "+ $r.ip.IPAddress + "/"+ $r.ip.PrefixLength}; $i+=1
              @{x=9; y=$i; caption= "デフォゲ   : "+ $r.ip.DefaultGateway}; $i+=1
              @{x=9; y=$i; caption= "DNSサーバ  : "+ $r.dns.ServerAddress}; $i+=1
            }
            if($r.register -eq $false) {
                @{x=9; y=$i; caption= "* この接続のアドレスをDNSに登録する のチェックを外します"}; $i+=1}
            $i+=2
          }
          if($param.nw.enablewins -eq $false) {
            $i+=3; @{x=9; y=$i; caption= "* LMHOSTSの参照を有効にする のチェックを外します"} }
        )
        show_menu $head $body $foot
      }
    }
    config = @{
      x=7; y=5; caption="設定実行"
      exe = {
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
  }
  ncpa = @{
    x=7; y=15; caption="ncpa.cpl"
    exe = {
      ncpa.cpl
    }
  }
}

$caption = "システムのプロパティ" ; $row+=2
$sys = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$sys.menu.caption+" **"})
      $body = @($sys.confirm, $sys.config)
      $foot = @(
        $pagefile = $param.sys.pagefile
        @{x= 7; y=10; caption="* 仮想メモリ"}
        @{x= 7; y=12; caption="ドライブ   : "+ $pagefile.Drive}
        @{x= 7; y=13; caption="初期サイズ : "+ $pagefile.InitialSize}
        @{x= 7; y=14; caption="最大サイズ : "+ $pagefile.MaximumSize}
        $memdump = $param.sys.memdump
        @{x=34; y=10; caption="* 起動と回復"}
        @{x=34; y=12; caption="自動的に再起動する : "+ $memdump.AutoReboot}
        @{x=34; y=13; caption="ダンプの種類       : "+ $memdump.debug_info_dsc[$memdump.DebugInfoType]}
        @{x=34; y=14; caption="ダンプファイル     : "+ $memdump.DebugFilePath+"\MEMORY.DMP"}
      )
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $sys.menu.caption | clip
      $arr = @(
        @{key="%s^{tab}%c"; prtsc=$true}
        @{key="{esc 2}"; prtsc=$false}
        @{key="%t"; prtsc=$true}
      )
      scr "SystemPropertiesAdvanced" $arr
    }
  }
  config = @{
    x=7; y=7; caption="設定実行"
    exe = {
      clear
      $a = gwmi -class win32_computersystem -EnableAllPrivileges
      $a.AutomaticManagedPagefile = $false
      $a.put()

      (gwmi -class Win32_PageFileSetting | ?{$_.name -match "C:\\pagefile.sys"}).delete()

      $pagefile = $param.sys.pagefile
      $a = Set-WmiInstance -Class Win32_PagefileSetting -Arguments @{Name `
        = $pagefile.Drive+":\pagefile.sys"}
      $a.InitialSize = $pagefile.InitialSize
      $a.MaximumSize = $pagefile.MaximumSize
      $a.put()

      $memdump = $param.sys.memdump
      $a = gwmi Win32_OSRecoveryConfiguration
      $a.AutoReboot = $memdump.AutoReboot
      $a.DebugInfoType = $memdump.DebugInfoType
      if($memdump.Mkdir) { mkdir $memdump.DebugFilePath }
      $a.DebugFilePath = $memdump.DebugFilePath +"\MEMORY.DMP"
      $a.put()
      pause
    }
  }
}

$caption = "リモートデスクトップ" ; $row+=2
$mstsc = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$mstsc.menu.caption+" **"})
      $body = @($mstsc.confirm, $mstsc.config)
      $foot = @(
        @{x=7; y= 9; caption="* このコンピュータへの接続を許可します"}
        if($param.mstsc.UserAuthentication -eq $false) {
           @{x=7; y=10; caption="* ネットワークレベル認証でリモートデスクトップを実行している"}
           @{x=7; y=11; caption="* コンピュータからのみ接続を許可する : チェックを外します"}
        }
      )
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $mstsc.menu.caption | clip
      $arr = @(
        @{key=""; prtsc=$true}
      )
      scr "SystemPropertiesRemote" $arr
   }
  }
  config = @{
    x=7; y=7; caption="設定実行"
    exe = {
      clear
      Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
        -Name "fDenyTSConnections" -Value 0 -Force
      if($param.mstsc.UserAuthentication -eq $false) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
          -Name "UserAuthentication" -Value 0 -Force
      }
      pause
    }
  }
}

$caption = "Windows ファイヤーウォール" ; $row+=2
$wf = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$wf.menu.caption+" **"})
      $body = @($wf.confirm, $wf.config)
      $foot = @(@{x=7; y=9; caption="* すべてのプロファイルを無効にします"})
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $wf.menu.caption | clip
      $arr = @(
        @{key=""; prtsc=$false}
        @{key="% x"; prtsc=$true}
      )
      scr "wf.msc" $arr
    }
  }
  config = @{
    x=7; y=7; caption="設定実行"
    exe = {
      clear
      Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled false
      pause
    }
  }
}

$caption = "Windows Update" ; $row+=2
$wu = @{
  menu = @{
    x=7; y=17; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$wu.menu.caption+" **"})
      $body = @($wu.confirm, $wu.config)
      $foot = @(@{x=7; y=9; caption="* [更新プログラムを確認しない] に設定します"})
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $wu.menu.caption | clip
      $arr = @(
        @{key="{tab 5}~"; prtsc=$false}
        @{key="%"; prtsc=$false}
        @{key=" x"; prtsc=$true}
        @{key="^w"; prtsc=$false}
      )
      scr "wuapp.exe" $arr
    }
  }
  config = @{
    x=7; y=7; caption="設定実行"
    exe = {
      clear
      Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" `
        -Name AUOptions -Value 1
      #New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
      #    -Name NoAutoUpdate -Value 1
      pause
    }
  }
}

$caption = "Windows エラー報告" ; $row+=2
$wer = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$wer.menu.caption+" **"})
      $body = @($wer.confirm, $wer.config)
      $foot = @(@{x=7; y=9; caption="* [レポートを送信せずこの確認画面も今後表示...] に設定します"})
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      try { (ps | ?{$_.name.tolower() -match "servermanager"}).kill() } catch{}

      echo $wer.menu.caption | clip
      $arr = @(
        @{key="%"; prtsc=$false}
        @{key=" x"; prtsc=$false}
        @{key="+{tab}{down}~"; prtsc=$false}
        @{key="{tab}{down 4}~"; prtsc=$true}
        @{key="{esc}{tab}~"; prtsc=$true}
        @{key="{esc}"; prtsc=$false}
      )
      scr "servermanager" $arr
    }
  }
  config = @{
    x=7; y=7; caption="設定実行"
    exe = {
      clear
      Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" `
        -Name Disabled -Value 1
      pause
    }
  }
}

$caption = "ユーザアカウント制御" ; $row+=2
$uac = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$uac.menu.caption+" **"})
      $body = @($uac.confirm, $uac.config)
      $foot = @(
        @{x=7; y= 9; caption="* アプリがソフトウェアをインストールしようとする場合、"}
        @{x=7; y=10; caption="* またはコンピュータに変更を加えようとする場合、"}
        @{x=7; y=11; caption="* ユーザが Windows 設定を変更する場合 に設定します"}
      )
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $uac.menu.caption | clip
      $arr = @(
        @{key=""; prtsc=$true}
        @{key="{esc} "; prtsc=$false}
      )
      scr "UserAccountControlSettings" $arr
    }
  }
  config = @{
    x=7; y=7; caption="設定実行"
    exe = {
      clear
      Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
        -Name "EnableLUA" -Value 0
      pause
    }
  }
}

$caption = "Administrator のパスワード" ; $row+=2
$admin = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$admin.menu.caption+" **"})
      $body = @($admin.confirm, $admin.config)
      $foot = @(@{x=7; y=9; caption="* Administrator パスワードの有効期限を無期限にします"})
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $admin.menu.caption | clip
      $arr = @(
        @{key=""; prtsc=$false}
        @{key="% x"; prtsc=$false}
        @{key="{down}"; prtsc=$false}
        @{key="{tab}"; prtsc=$false}
        @{key="{enter}"; prtsc=$true}
      )
      scr "lusrmgr.msc" $arr
    }
  }
  config = @{
    x=7; y=7; caption="設定実行"
    exe = {
      clear
      $a = gwmi win32_useraccount | ?{$_.name -match "Administrator"}
      $a.PasswordExpires = $false
      $a.put()
      pause
    }
  }
}

$caption = "キーボードダンプ" ; $row+=2
$kbdump = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$kbdump.menu.caption+" **"})
      $body = @(
        $kbdump.confirm
        if($param.kbdump.length -gt 0) {$kbdump.config}
      )
      $foot = @(
        if($param.kbdump.length -gt 0) {$i=0; @{x=7; y=10; caption="* 設定する値 :"}}
        foreach($r in $param.kbdump) {
          @{x=23+10*$i; y=10; caption=$r.name}; $i+=1
        }
      )
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $kbdump.menu.caption | clip
      $arr = @(
        @{key="reg query HKLM\SYSTEM\CurrentControlSet\Services\i8042prt\Parameters /v CrashOnCtrlScroll~"; prtsc=$false}
        @{key="reg query HKLM\SYSTEM\CurrentControlSet\Services\kbdhid\Parameters /v CrashOnCtrlScroll~"; prtsc=$false}
        @{key="reg query HKLM\SYSTEM\CurrentControlSet\Services\hyperkbd\Parameters /v CrashOnCtrlScroll~"; prtsc=$true}
      )
      scr "powershell" $arr
    }
  }
  config = @{
    x=7; y=7; caption="設定実行"
    exe = {
      clear
      foreach($r in $param.kbdump) {
        $key = "HKLM:\SYSTEM\CurrentControlSet\Services\"+$r.name+"\Parameters"
        Set-ItemProperty -Path $key -Name CrashOnCtrlScroll -Value 1 -Force
      }
      pause
    }
  }
}

$caption = "自動デフラグ" ; $row+=2
$dfrgui = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$dfrgui.menu.caption+" **"})
      $body = @($dfrgui.confirm, $dfrgui.config)
      $foot = @(@{x=7; y=9; caption="* 恐れ入りますが設定は手動でやってください"})
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $dfrgui.menu.caption | clip
      $arr = @(
        @{key=""; prtsc=$true}
      )
      scr "dfrgui" $arr
    }
  }
  config = @{
    x=7; y=7; caption="dfrgui.exe"
    exe = {
      dfrgui
    }
  }
}

$caption = "SNPの設定" ; $row+=2
$snp = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$snp.menu.caption+" **"})
      $body = @(
        $snp.confirm
        if($param.snp.length -gt 0) {$snp.config}
      )
      $foot = @(
        if($param.snp.length -gt 0) {$i=10; @{x=7; y=$i; caption="* 設定する値"}; $i+=1}
        foreach($r in $param.snp) {
          $i+=1; @{x=7; y=$i; caption=$r.name+" : "+$r.action}
        }
      )
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $snp.menu.caption | clip
      $arr = @(
        @{key="netsh int tcp show global~"; prtsc=$true}
      )
      scr "cmd" $arr
    }
  }
  config = @{
    x=7; y=7; caption="設定実行"
    exe = {
      clear
      foreach($r in $param.snp) {
        $cmd = "netsh int tcp set global " + $r.name + "=" + $r.action
        invoke-expression $cmd
      }
      pause
    }
  }
}

$caption = "SMB3.0マルチチャネル" ; $row+=2
$smb = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$smb.menu.caption+" **"})
      $body = @(
        $smb.confirm
        if($param.smb.length -gt 0) {$smb.config}
      )
      $foot = @(
        if($param.smb.length -gt 0) {$i=10; @{x=7; y=$i; caption="* 設定する値"}; $i+=1}
        foreach($r in $param.smb) {
          $i+=1; @{x=7; y=$i; caption=$r.name+" -EnableMultiChannele $" + $r.enabled}
        }
      )
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $smb.menu.caption | clip
      $arr = @(
        @{key="gsmbsc | fl EnableMultiChannel~"; prtsc=$false}
        @{key="gsmbcc | fl EnableMultiChannel~"; prtsc=$true}
      )
      scr "powershell" $arr
    }
  }
  config = @{
    x=7; y=7; caption="設定実行"
    exe = {
      clear
      foreach($r in $param.smb) {
        $cmd = $r.name +" -EnableMultiChannele $"+ $r.enabled
        invoke-expression $cmd
      }
      pause
    }
  }
}

$caption = "電源オプション" ; $row+=2
$power = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $head = @(@{x=7; y= 2; caption="** "+$power.menu.caption+" **"})
      $body = @($power.confirm, $power.config)
      $foot = @(@{x=7; y=9; caption="* [高パフォーマンス] に設定します"})
      show_menu $head $body $foot
    }
  }
  confirm = @{
    x=7; y=5; caption="設定確認"
    exe = {
      echo $power.menu.caption | clip
      $arr = @(
        @{key=""; prtsc=$true}
        @{key="^w"; prtsc=$false}
      )
      scr "powercfg.cpl" $arr
    }
  }
  config = @{
    x=7; y=7; caption="設定実行"
    exe = {
      clear
      powercfg -setactive SCHEME_MIN
      pause
    }
  }
}

$caption = "スクショ" ; $row+=2
$scr = @{
  menu = @{
    x=7; y=$row; caption=$caption
    exe = {
      $sh = New-Object -ComObject "Shell.Application"
      $sh.MinimizeAll()
      &$disk.confirm.exe
      &$hosts.confirm.exe
      &$nw.confirm.exe
      &$sys.confirm.exe
      &$mstsc.confirm.exe
      &$wf.confirm.exe
      &$wu.confirm.exe
      &$wer.confirm.exe
      &$uac.confirm.exe
      &$admin.confirm.exe
      &$kbdump.confirm.exe
      &$dfrgui.confirm.exe
      &$snp.confirm.exe
      &$smb.confirm.exe
      &$power.confirm.exe
      $sh.UndoMinimizeAll()
    }
  }
}

# メイン処理
function main()
{
  $head = @(@{x=7; y= 2; caption="** Windows Server 設定ツール (sn:$serial) **"})
  $body = @(
    $disk.menu
    $hosts.menu
    $nw.menu
    $sys.menu
    $mstsc.menu
    $wf.menu
    $wu.menu
    $wer.menu
    $uac.menu
    $admin.menu
    $kbdump.menu
    $dfrgui.menu
    $snp.menu
    $smb.menu
    $power.menu
    $scr.menu
  )
  $foot = @()
  show_menu $head $body $foot
}
main
