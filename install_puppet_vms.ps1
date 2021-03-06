param(
	[Parameter(Mandatory=$true, HelpMessage="sets whether you will be asked to confirm packages installation.(virtualbox/vagrant)")]
	[ValidateSet($true,$false)] 
	[Switch]$interactive,
	[Parameter(Mandatory=$true, HelpMessage="the place where vagrant will put the vms.")]
	[String] $vagrant_vms_path
)

function Install_Chocollatey {
	Write-Host "Checking chocollatey installation..."
	try{
        choco
    }
    catch{
	    try{
            "chocollatey is not installed. Installing..."
            (iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')))>$null 2>&1
		    choco
	    }
	    catch{
		    "chocollatey seems not to be installed. exiting"
		    throw "chocollatey installation failed. Chocollatey needs  to be installed to install other tools like vagrant and virtualbox"
	    }
    }
}

function Set-EnvVariable($bin_path){
    if(Test-Path $bin_path){
        #add path to ssh bin fodler to environment varables
        if($env:Path -notlike "*;$bin_path*"){
            $edited_path = $env:Path + ";$bin_path"
            if($edited_path -ne $null){
                [Environment]::SetEnvironmentVariable("PATH",$edited_path , "Machine")
                $env:Path = $edited_path
            }
        }
    }
}

function Install_Package($package_name, $choco_parameters){
	Write-Host "Installing $package_name"
    
    #validating choco_parameters
    if($choco_parameters -ne $null){
        if($choco_parameters -notlike "--params*"){
            throw "parameters of chocollatey should start with -params"
        }
    }

    #check whether package is installed
	$package_installed = $installed_packages | ? name -like "*$package_name*"
	if($interactive){
		if($package_installed -eq $null){
			$response = Read-Host "There no $package_name on your machine. Installing? y\n"
			if($response -eq "y"){choco install $package_name -y $choco_parameters --force}
			else{Write-Host "skipping $package_name install"}		
		}
		else{
			$response = Read-Host "There is $package_name on your machine. Let me upgrade it? y\n"
			if($response -eq "y"){choco upgrade $package_name -y $choco_parameters}
			else{Write-Host "skipping $package_name"}		
		}
	}
	else{
		if($package_installed -eq $null){
			Write-Host "There no $package_name on your machine. Installing..."
			choco install $package_name -y $choco_parameters --force
		}
		else{
            Write-Host "Upgrading $package_name on your machine..."
			choco upgrade $package_name -y $choco_parameters
		}
	}

    #set Vagrant's home
    if($package_name -eq "vagrant"){
        Set-EnvVariable "c:\HashiCorp\Vagrant\bin"
    }
}

function Install_SSH {
    try {
        ssh -V
    }
    catch{
        #we will catch the output of the ssh -V as exception. Because powershell think that's an error.
        if( $_.exception.message -like "*OpenSSH_*"){
            Write-Host "ssh is installed. The output of ssh -V is $($_.exception.message)"
            return
        }
        write-host "ssh.exe not found. Need to install the git to install ssh with it"
        "installing it from sources in scripts directory $ScriptDirectory"
        $sshSourceDir = $ScriptDirectory+"\soft\ssh"
        if((Test-Path $sshSourceDir) -and (Test-Path ${env:ProgramFiles(x86)})){
            Copy-Item -Recurse -Force -Path $sshSourceDir -Destination ${env:ProgramFiles(x86)}
            #add path to ssh bin fodler to environment varables
            $ssh_bin = "${env:ProgramFiles(x86)}\ssh\bin"
            Set-EnvVariable $ssh_bin
        }
        try{
            ssh -V
        }
        catch{
            if( $_.exception.message -like "*OpenSSH_*"){
                Write-Host "ssh is installed. The output of ssh -V is $_.exception.message"
                return
            }
            throw "no ssh executable found. And can't install. Please install ssh to be able to connect to linux boxes installed via Vagrant."
        }
    }
}

function Change_Vagrant_Home{
    $vagrant_dir = $null
    $vagrant_boxes_path = "$script:vagrant_home_path"+"\"+"boxes"
	if($interactive){
		$response = Read-Host "I will switch vagrant home directory to $vagrant_boxes_path .All the boxes and settings will be put there. Ok? y\n"
		if($response -eq "y"){[Environment]::SetEnvironmentVariable("VAGRANT_HOME", $vagrant_boxes_path, "Machine")}
		else{
            Write-Host "Skipping switching the vagrant home directory"
            Write-Host "Gettting the current vagrant_home path"
            try{
                $vagrant_dir = (Get-ChildItem Env:\VAGRANT_HOME).value
            }
            catch {
                Write-Host "no VAGRANT_HOME environment variable found. Searching for vagrant directory in users directory."
                try{
                    $vagrant_dir = ((Get-ChildItem Env:\USERPROFILE).Value+"\.vagrant.d")
                    if( -not (Test-Path $user_vagrant_dir)){
                        throw "no default directory"
                    }
                }
                catch{
                    throw "Could not find vagrant directory. Please ensure that vagrant is installed from your account. Or rerun the script and install vagrant."
                }
            }
            $global:vagrant_home_path = $vagrant_dir
        }
	}
    else{
        "Settings Vagrant_Home to $vagrant_boxes_path"
        [Environment]::SetEnvironmentVariable("VAGRANT_HOME", $vagrant_boxes_path, "Machine")
    }
}

function Install_Choho_Packages {
    Install_Chocollatey
    $installed_packages = Get-WmiObject -Class Win32_Product
    Install_Package "virtualbox"
    Install_Package "vagrant"
    Install_SSH
}

function vagrant_up{
    try{
	    vagrant up --provider virtualbox	
    }
    catch {
        if($_.exception.message -like "*Vagrant cannot forward the specified ports on this VM*"){
            throw "It seems that some other machine is using the ports for redirection. Please edit $vagrant_vms_path_agent_vagrantFile_dest and edit config.vm.network forwarded_port key there"
        }
        throw $_.exception
    }
}

function vagrant_add($boxname,$url){
    try{
        Write-Host "adding vagrant box $boxname..."
        vagrant box add $boxname $url --provider virtualbox
    }
    catch {
        if($_.exception.message -like "*The box you're attempting to add already exists.*"){
            Write-Host "It seems that the box is already there. Skipping add."
        }
        else{
            throw $_.exception
        }
    }
}

function Install_master_VM ($vagrant_vms_path_dir) {
	$vagrant_vms_path_master = $vagrant_vms_path_dir+"\"+"m3master"
	$vagrant_vms_path_master_vagrantFile = $ScriptDirectory+"\m3master\Vagrantfile"
	$vagrant_vms_path_master_init_script = $ScriptDirectory+"\m3master\init.sh"
	mkdir $vagrant_vms_path_master -Force
	cd $vagrant_vms_path_master
	if((Test-Path $vagrant_vms_path_master_vagrantFile) -and (Test-Path $vagrant_vms_path_master_init_script)){
		
        Write-Host "adding vagrant base box"
	    vagrant_add "amatas/centos-7"

        Write-Host "copy vagrant config and init scripts to vms fodler"
		copy -Path $vagrant_vms_path_master_vagrantFile -Destination . -Force
		copy -Path $vagrant_vms_path_master_init_script -Destination . -Force
		
        Write-Host "function above that starts vagrant vm"
		vagrant_up
        
        Write-Host "get master server ip to use it in the agent to set puppet masteer location"
        $ips = vagrant ssh -- "hostname -I"
        if($ips){
	        $ip = $ips | %{ $_.split(' ')[1] }
	        if($ip -eq $null){
		        throw "no ip for the master found. can't configure agent without it"
	        }
            $script:ip= $ip
        }
        else{
            throw "no ip for master server found in vagrant box. please run vagrant ssh -- 'hostname -I' from $vagrant_vms_path_master dir to get the ip address of the host"
        }
	}
    else{
        throw "config files for master not found. $vagrant_vms_path_master_vagrantFile and $vagrant_vms_path_master_init_script"
    }
}

function Install_agent_VM ($vagrant_vms_path_dir) {
	if(!$script:ip){
		throw "no master ip defined"
	}
	$vagrant_vms_path_agent = $vagrant_vms_path_dir+"\m3agent"
	$vagrant_vms_path_agent_vagrantFile = $ScriptDirectory+"\m3agent\Vagrantfile"
    $vagrant_vms_path_agent_vagrantFile_dest = $vagrant_vms_path_agent+"\Vagrantfile"
	$vagrant_vms_path_agent_init_script = $ScriptDirectory+"\m3agent\init.ps1"

	mkdir $vagrant_vms_path_agent -Force
	cd $vagrant_vms_path_agent
	if((Test-Path $vagrant_vms_path_agent_vagrantFile) -and (Test-Path $vagrant_vms_path_agent_init_script)){
		Write-Host "copy vagrant config and init scripts to vms fodler"
        copy -Path $vagrant_vms_path_agent_vagrantFile -Destination .
		copy -Path $vagrant_vms_path_agent_init_script -Destination .
        
        Write-Host "set master's ip address for agent init script which configure agent to look to puppet master (config via hosts file)    "
        Write-host "master's IP is $script:ip"
		(gc $vagrant_vms_path_agent_vagrantFile_dest) -replace 'master_ip',$ip | Set-Content $vagrant_vms_path_agent_vagrantFile_dest -Encoding Ascii
        Write-Host " adding agents base box"
        vagrant_add "w2012_puppet_agent" "\\epbyminw2312\boxes\m3puppet_agent.box"
        Write-Host "run agent"
        vagrant_up 
	}
    else{
        throw "config files for agent not found. $vagrant_vms_path_agent_vagrantFile and $vagrant_vms_path_agent_init_script"
    }
}
Write-Host "Started at $(Get-Date)"
#general variables
$ErrorActionPreference="Stop"
$ScriptDirectory = Split-Path -Parent $PSCommandPath

#global variables thatare chagned from the functions
$script:ip= $null
$script:vagrant_home_path = $vagrant_vms_path

Install_Choho_Packages
Write-Host "Getting install packages..."
$installed_packages_after_choco_install = Get-WmiObject -Class Win32_Product
if($installed_packages_after_choco_install | ? name -like "*vagrant*"){
	$vagrant_vms_path_dir = "$script:vagrant_home_path"+"\vms"
    Change_Vagrant_Home 
    Install_master_VM $vagrant_vms_path_dir
    Install_agent_VM $vagrant_vms_path_dir
}
else{
    throw "it seems that Vagrant is not installed. Please rerun the script and install the vagrant."
}
Write-Host "Finished at $(Get-Date)"
Write-Host ""
Write-Host "##################################"
Write-Host "############# Done ###############"
Write-Host "### To connect to windows agent ##"
Write-Host "############# run ################"
Write-Host "# cd  $($script:vagrant_home_path+'\vms\m3agent')"
Write-Host "# vagrant rdp"
Write-Host "# or use"
Write-Host "# mstsc /v 127.0.0.1:33389"
Write-Host "# credentials: Administrator/Epam_2010"
Write-Host "##################################"
Write-Host "# to connect to puppet master use"
Write-Host "# cd $($script:vagrant_home_path+'\vms\m3master')"
Write-Host "# vagrant ssh"
Write-Host "##################################"
Write-Host "##################################"