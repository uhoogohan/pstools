<#------------------------------------------------------------------
 メニューモジュール (^^♪
------------------------------------------------------------------#>
Add-Type -AssemblyName System.Windows.Forms
$kmp = [Windows.Forms.Keys]
$rui = $host.UI.RawUI

# メニュー表示
function show_menu($head, $body, $foot) {
  $init = $true
  $i = 0
  do {
    # 初期画面表示
    if($init) {
      clear
      $head | %{mv_cur $_.x $_.y; write-host $_.caption}
      $body | %{mv_cur $_.x $_.y; write-host $_.caption}
      $foot | %{mv_cur $_.x $_.y; write-host $_.caption}
      $init = $false;
    }

    $s = $body[$i]

    # カーソル移動と反転表示
    mv_cur $s.x $s.y
    write-host $s.caption -F "Black" -B "White"
    mv_cur $s.x $s.y

    $kif = $rui.ReadKey("NoEcho,IncludeKeyDown")
    $kcd = $kif.VirtualKeyCode

    # 方向キー↑か←が押されたとき
    if($kcd -in ($kmp::Up, $kmp::Left)) {
      write-host $s.caption; $i-=1 
      if($i -lt 0) { $i = $body.length - 1 }
    }

    # 方向キー↓か→が押されたとき
    if($kcd -in ($kmp::Down, $kmp::Right)) {
      write-host $s.caption; $i+=1
      if($i -ge $body.length) { $i = 0; }
    }

    # Enterキーが押されたとき
    if($kcd -eq $kmp::Enter) {
      $s.exe()
      $init = $true;
    }
  }
  # EscキーがQキーが押されるまで
  until($kcd -in ($kmp::Escape, $kmp::Q))
  clear
}

# カーソル移動
function mv_cur($x, $y) {
  $cd = [System.Management.Automation.Host.Coordinates]::new($x, $y)
  $rui.CursorPosition = $cd
}

# キャプション
class Caption {
  [int]$x
  [int]$y
  [String]$caption

  Caption($x, $y, $caption) {
    $this.x = $x; $this.y = $y; $this.caption = $caption
  }
}

# メニューアイテム
class MenuItem : Caption {
  [scriptblock]$cmd

  MenuItem($x, $y, $caption, $cmd) : base($x, $y, $caption) {
    $this.cmd = $cmd
  }

  # メニューを実行します
  [void] exe() {
    &($this.cmd)
  }
}

# メニュー本体（ヘッダ、ボディ、フッタから成ります）
class Menu : Caption {
  $head = @()
  $body = @()
  $foot = @()

  Menu($x, $y, $caption) : base ($x, $y, $caption) {
    $title = "** "+ $caption + " **"
    $this.head += new-object Caption(7, 2, $title)
  }

  [void] exe() {
    show_menu $this.head $this.body $this.foot
  }
}
