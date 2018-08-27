start_msg() {
  cat << EOD | awk '{a=sprintf("%s#",$0);b=sprintf("%-38s",a);gsub(/ $/,"-",b);sub(/#/," ",b);printf "# --- %s - Start of : %s #\n",strftime("%Y-%m-%d %H:%M:%S",systime()),b}'
$*
EOD
}

end_msg() {
  cat << EOD | awk '{a=sprintf("%s#",$0);b=sprintf("%-38s",a);gsub(/ $/,"-",b);sub(/#/," ",b);printf "# --- %s - End of   : %s #\n",strftime("%Y-%m-%d %H:%M:%S",systime()),b}'
$*
EOD
}
do_upgrade(){
  version="$1"
  cd /tmp/
  echo "### content of pe.conf START ###"
  cat /etc/puppetlabs/enterprise/conf.d/pe.conf || (echo "pe.conf not OK";return 1)
  echo "### content of pe.conf END ###"
  wget https://pm.puppetlabs.com/puppet-enterprise/${version}/puppet-enterprise-${version}-el-7-x86_64.tar.gz || return 1
  tar xvf puppet-enterprise-${version}-el-7-x86_64.tar.gz || return 1
  cd puppet-enterprise-${version}-el-7-x86_64 || return 1
  # run installer with existing config
  start_msg ./puppet-enterprise-installer -c /etc/puppetlabs/enterprise/conf.d/pe.conf 
  if ./puppet-enterprise-installer -c /etc/puppetlabs/enterprise/conf.d/pe.conf 
  then
   end_msg ./puppet-enterprise-installer -c /etc/puppetlabs/enterprise/conf.d/pe.conf SUCCESS
    # run puppet agent
    puppet agent -t 
    puppet agent -t 
    # mail the logfile
    if [ ! -x /usr/local/bin/mailit ];then
      curl http://huclis02.qvc-intern.de:/inst.images/GIT/admin-scripts/scripts/mailit > /usr/local/bin/mailit
      chmod +x /usr/local/bin/mailit
    fi
    facter -p pe_server_version puppetversion facterversion | /usr/local/bin/mailit -t klaus_franke@qvc.com -f /tmp/upgrade_${version}.log -s "Puppet Server Upgrade to ${version} on $(hostname -f)"
    # tidyup
    cd /tmp
    rm -rf puppet-enterprise-${version}-el-7-x86_64*
  else
     end_msg ./puppet-enterprise-installer -c /etc/puppetlabs/enterprise/conf.d/pe.conf FAIL
    echo "Non Zereo return code from installer script. please check logfile.."
  fi
}
disable_envs() {
# move envs to other location to speed up puppetserver restart
mkdir -p /etc/puppetlabs/save/environments
cd /etc/puppetlabs/code/environmen
for x in $(ls -1 | grep -v -w -e stable -e production)
do
  echo "mv -f $x /etc/puppetlabs/save/environments/"
  mv -f $x /etc/puppetlabs/save/environments/
done
cd
}
enable_envs() {
# move envs to other location to speed up puppetserver restart
cd /etc/puppetlabs/save/environments
for x in $(ls -1 | grep -v -w -e stable -e production)
do
  echo "mv -f $x /etc/puppetlabs/code/environments/"
  mv -f $x /etc/puppetlabs/code/environments/
done
cd
rmdir /etc/puppetlabs/save/environments
}

version="2018.1.4"
disable_envs
do_upgrade "${version}" 2>&1| tee /tmp/upgrade_${version}.log
enable_envs
