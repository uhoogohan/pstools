<#------------------------------------------------------------------
 ファイルとディレクトリを表示します
------------------------------------------------------------------#>
using module ".\menu.psm1"

class Uho {
  [Menu]$mnu

  Uho($dir_) {
    $this.mnu = [Menu]::new(0, 0, $dir_)
    $i = 4
    ls $dir_ | %{
      $fn_ = $_
      $cap = ($_.Attributes.ToString()).SubString(0, 1) +" "+ $_.Name
      $this.mnu.body += [MenuItem]::new(7, $i++, $cap, $this.sb.GetNewClosure())
    }
  }

  exe() {
    $this.mnu.exe()
  }

  $sb = {
    if($fn_.Attributes -match "Directory") {
      $uho = [Uho]::new($fn_.Fullname)
      $uho.exe()
    }

    if($fn_.Attributes -match "Archive") {
　    clear
      write-host $fn_.Name "は、ファイルでーす☆"
      pause
    }
  }
}

$uho = [Uho]::new("E:\")
$uho.exe()