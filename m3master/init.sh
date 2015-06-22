#install puppet
sudo rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
sudo yum -y install puppet puppet-server git

#disable firewall
sudo systemctl disable firewalld
sudo systemctl stop firewalld

#set puppet autostart
sudo systemctl enable puppetmaster
sudo systemctl start puppetmaster
#get fresh code
rm -rf /etc/puppet/*
rm -rf /etc/puppet/.git
cd /etc/puppet
git init
git remote add day3 https://github.com/pesetskyps/puppet-course-day3.git
git pull day3 master

#workaround cert notices
sudo puppet cert list
sudo systemctl restart puppetmaster