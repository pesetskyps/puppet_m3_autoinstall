# puppet_m3_autoinstall
automatically installs master and agent vms on windows machine

.\install_puppet_vms.ps1 -interactive -vagrant_vms_path d:\test
Will ask before installing vagrant and virtual packages. 
Starting from importing boxes is performing automatically.

.\install_puppet_vms.ps1 -vagrant_vms_path d:\test
Will install the latest vagrant and virtualbox packages and launch the vms automatically without any interaction.
!!! Use it if you sure that fresh vagrant and virtualbox won't hurt your current installation.
