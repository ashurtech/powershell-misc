### Requires Powershell 5.0

Class RunspacePool {
[int]$poolMinimum = 1
[int]$poolMaximum = 3
[Collections.Arraylist]$RunspaceCollection =@()
[System.Management.Automation.Runspaces.RunspacePool]$RunspacePool
[int]$counter = 0
[hashtable]$SyncHASH = [Hashtable]::Synchronized(@{})
[int]$jobID = 0
[Collections.Arraylist]$RunspaceOUTPUT
[Collections.Arraylist]$RunspaceINPUT ####Collection of objects to process, at present these are passed in as the script argument
[System.Management.Automation.ScriptBlock]$Scriptblock ######## Include a param($param1) block in your script, or else
#### See $myscript at the end for an example
$Param1 ### Untyped at present, given below could usually just assume it is same as $object in the foreach
### 
[int]$statusCheckIntervalSECS = 5
##Constructor
###Sets up the runspacepool - assumes $object is the parameter to pass in
RunspacePool ([Collections.Arraylist]$RunspaceINPUT,[System.Management.Automation.ScriptBlock]$Scriptblock){
#$this.RunspaceCollection = [Collections.Arraylist]::Synchronized(@())
$this.RunspacePool = [RunspaceFactory]::CreateRunspacePool($this.poolMinimum,$this.poolMaximum)
$this.RunspacePool.Open()
$this.RunspaceOUTPUT = @()
$this.Scriptblock = $scriptblock
$this.RunspaceINPUT = $RunspaceINPUT
}
RunspacePool ([Collections.Arraylist]$RunspaceINPUT,[System.Management.Automation.ScriptBlock]$Scriptblock,[int]$poolMaximum){
$this.poolMaximum = $poolMaximum
#$this.RunspaceCollection = @()
$this.RunspacePool = [RunspaceFactory]::CreateRunspacePool($this.poolMinimum,$this.poolMaximum)
$this.RunspacePool.Open()
$this.RunspaceOUTPUT = @()
$this.Scriptblock = $scriptblock
$this.RunspaceINPUT = $RunspaceINPUT
}
RunPoolRun(){
###This bit throws the objects into the pool
Foreach($object in $this.RunspaceINPUT){
$Powershell = [PowerShell]::Create().AddScript($this.ScriptBlock).AddArgument($this.Synchash).AddArgument($this.jobID).AddArgument($object)
$Powershell.RunspacePool = $this.RunspacePool
$this.Synchash["$($this.jobid)"] = (New-Object -TypeName PSObject -Property @{
Job = $this.jobid
Started = $false
Done = $false
Data = $False
Runspace = $PowerShell.BeginInvoke();
PowerShell = $PowerShell
})
$this.jobID ++
}
$this.counter = 0
##This bit monitors the runspace, sleeps for statusCheckIntervalSECS
While($this.RunspaceCollection){
            if(($Event = (Get-Event)).MessageData){write-host $event}
            $this.counter++
            write-host $this.counter #nice to see its actually doing something sometimes
            sleep $this.statusCheckIntervalSECS    

#Check each pool member for .Iscompleted()
Foreach($Runspace in $this.RunspaceCollection.ToArray()){
#If done
  If($Runspace.Runspace.IsCompleted){
   #Save the output
   $runspaceresult = $Runspace.PowerShell.EndInvoke($Runspace.Runspace)
   $this.RunspaceOUTPUT += $runspaceresult
   #Trash the powershell instance
   $Runspace.PowerShell.Dispose()
   #Remove the runspace from the pool, allowing a new one to be born. Sunrise, Sunset.
   $this.RunspaceCollection.Remove($Runspace)
  }
}
}
}
}


##Example data
[Collections.Arraylist]$myINPUT = gci C:\ -Directory
[System.Management.Automation.ScriptBlock]$myscript = {
param($syncHASH,$jobID,$param1)
$SyncHash["$jobID"].Started = (get-date)
#$data = gci -Path $param1.fullname -recurse
$thisobject = [pscustomobject] @{
Name = $param1.name
data = ((gci -Path $param1.fullname -recurse | measure-object length -sum).sum) / 1GB
}
$SyncHash["$jobID"].Data = $thisobject
$SyncHash["$jobID"].Done = (get-date)
#New-Event -SourceIdentifier 'blip' -Sender 'scum' -MessageData "whoah nelly"
New-Event -SourceIdentifier 'blip' -Action {$True} -Forward -MessageData ('what the jesus cats')

}
###Example execution

$myRunspace = [RunspacePool]::new($myinput,$myscript,10)
Register-EngineEvent -SourceIdentifier blip -MessageData ('what the jesus cats') -Action {Write-Host 'yeahsss'}
$myRunspace.RunPoolRun()
#"yep"
$myRunspace.Synchash | out-gridview 
