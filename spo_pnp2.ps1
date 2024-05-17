#********************************************************************************
using module ".\menu.psm1"
#********************************************************************************
$origin = "https://uhoogohan.sharepoint.com"
$site = "/personal/uhoogohan_jp"
$doc_name = "Documents"
#********************************************************************************
import-module PnP.PowerShell

# １行編集
function edit_($pu) {
  return [PSCustomObject] @{
    FileLeafRef    = $pu["FileLeafRef"]
    FSObjectType   = $pu.FileSystemObjectType
    FSObjType      = $pu["FSObjType"]
    FileRef        = $pu["FileRef"]
    FileDirRef     = $pu["FileDirRef"]
    Email          = $pu["Author"].Email
    Created        = $pu["Created"]
    Modified       = $pu["Modified"]
  }
}

# CAML Query
function q_by_FileDirRef($dir) {
  return @"
<View Scope='RecursiveAll'><Query>
  <Where>
    <Eq>
      <FieldRef Name='FileDirRef'/>
      <Value Type='Text'>$dir</Value>
    </Eq>
  </Where>
</Query></View>
"@
}

class Pu {
  [Menu]$mnu

  Pu($doc_name, $doc_root) {
    $this.mnu = [Menu]::new(0, 0, $doc_root)

    $query = q_by_FileDirRef $doc_root
    $items = Get-PnPListItem -List $doc_name -Query $query

    $a = @()
    $items | %{$a += edit_ $_}

    $i = 5
    $a | %{
      $fn_ = $_
      $this.mnu.body += [MenuItem]::new(7, $i++, $_.FileLeafRef, $this.sb.GetNewClosure())
    }
  }

  exe () {
    $this.mnu.exe()
  }

  $sb = {
    if($fn_.FSObjectType -match "Folder") {
      $pu = [Pu]::new($doc_name, $fn_.FileRef)
      $pu.exe()
    }
    if($fn_.FSObjectType -match "File") {
      clear
      write-host $fn_.FileLeafRef "は、ファイルでーす☆"
      pause
    }
  }
}


function main() {
  try {
    $con = Connect-PnPOnline -Url ($origin + $site) -useweblogin #-Interactive

    $doc_root = ($site, $doc_name) -join "/"

    $pu = [Pu]::new($doc_name, $doc_root)
    $pu.exe()

    Disconnect-PnPOnline
  }
  catch {
    [System.Windows.Forms.MessageBox]::Show($PSItem, "＞＜", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
  }
}
main