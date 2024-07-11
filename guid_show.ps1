using module ".\menu.psm1"

class Uho : Menu {
  Uho($x, $y, $ttt) : base($x, $y, "ぬほほ") {
    $this.body += [Caption]::new(7, 5, $ttt)
  }
}

class Pu : Menu {
  Pu() : base(0, 0, "おツール") {
    5..30 | %{
      $x = New-Guid
      $num = $_
      $this.body += [MenuItem]::new(7, $_, "{0:000} : $x" -f $_, $this.mumu.GetNewClosure())
    }
  }

  [scriptblock]$pu = {
  }

  [scriptblock]$mumu = {
    $uho = [Uho]::new(7, $num, $x)
    $uho.exe()
  }
}

$pu = [Pu]::new()
$pu.exe()
