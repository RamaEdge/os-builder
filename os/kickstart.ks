lang en_US.UTF-8
keyboard us
timezone UTC
reboot
text

zerombr
#autopart --type=plain --fstype=xfs --nohome --encrypted --passphrase=WELLKN0WN
clearpart --all --disklabel gpt
part biosboot --fstype=biosboot --size=1
part /boot/efi --fstype=efi --asprimary --size=600
part /boot --fstype=xfs --asprimary --size=1024
# Uncomment this line to add a SWAP partition of the recommended size
#part swap --fstype=swap --recommended
part pv.01 --grow
volgroup eos pv.01
logvol none --fstype="None" --size=1 --grow --thinpool --metadatasize=4 --chunksize=65536 --name=thin --vgname=eos
logvol / --vgname=eos --fstype=xfs --size=100000 --name=root --thin --poolname=thin


network --bootproto=dhcp --device=link --activate --onboot=on

# bootc uses container images directly - no ostreesetup needed
# Container image will be specified during bootc install command


%post --log=/var/log/anaconda/post-install.log --erroronfail

#chage -M 180 -m 1 -E $(date -d +180days +%Y-%m-%d) -d $(date +%Y-%m-%d) abb

# bootc manages remotes automatically - no manual ostree remote commands needed

# Allow pod network and service network traffic on firewall
firewall-offline-cmd --zone=trusted --add-source=10.42.0.0/16
firewall-offline-cmd --zone=trusted --add-source=169.254.169.1


#echo -e 'RamaEdge REPLACE_VERSION \nKernel \\r on an \\m' > /etc/issue

# Configure systemd journal service to persist logs between boots and limit their size to 1G
sudo mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/microshift.conf <<EOF
[Journal]
Storage=persistent
SystemMaxUse=1G
RuntimeMaxUse=1G
EOF

exec < /dev/tty6 > /dev/tty6 2> /dev/tty6
chvt 6
echo "**************************************"
echo "          HOST Configuration          "
echo "**************************************"
# Set hostname 
read -p "Enter fully qualified hostname: " NAME
echo "$NAME" > /etc/hostname
echo "Hostname is set to $NAME"

# Create User
echo "**************************************"
echo "           USERNAME                   "
echo "**************************************"
echo " "
echo "Username must be between 3 and 10 characters long and contain only lowercase letters, numbers and underscores."
read -p "Please enter username and press [ENTER]: " USERNAME
while [[ ! $USERNAME =~ ^[a-z0-9_]{3,10}$ ]]; do
  echo "Username must be between 3 and 10 characters long and contain only lowercase letters, numbers and underscores."
  read USERNAME
done
while true; do
  echo "Password must be more than 8 characters long, contain at least one number, at least one uppercase letter, at least one lower case letter and at least one special character."
  read -s "Please enter password and press [ENTER]: " PASSWORD
  # Start POSIX-compliant password checks
  if echo "$PASSWORD" | grep -Eq '.{8,}'; then
    if echo "$PASSWORD" | grep -Eq '[0-9]'; then
      if echo "$PASSWORD" | grep -Eq '[a-z]'; then
        if echo "$PASSWORD" | grep -Eq '[A-Z]'; then
          if echo "$PASSWORD" | grep -Eq '[^a-zA-Z0-9]'; then
            echo "Password meets all requirements."
          else
            echo "Password must contain at least one special character."
            continue
          fi
        else
          echo "Password must contain at least one uppercase letter."
          continue
        fi
      else
        echo "Password must contain at least one lowercase letter."
        continue
      fi
    else
      echo "Password must contain at least one digit."
      continue
    fi
  else
    echo "Password must be at least 8 characters long."
    continue
  fi
  read -s "Please enter password again and press [ENTER]: " PASSWORD2
  [ "$PASSWORD" = "$PASSWORD2" ] && break
  echo "You have entered different passwords. Please try again"
done
useradd -p $(openssl passwd -1 $PASSWORD) $USERNAME
usermod -a -G wheel $USERNAME
echo -e '$USERNAME\tALL=(ALL)\tNOPASSWD: ALL' >> /etc/sudoers
# Workaround for home directory owned by root
install -d -o $USERNAME -g $USERNAME /home/$USERNAME/
install -d -o $USERNAME -g $USERNAME -m 0700 /home/$USERNAME/.kube
echo "User created with username $USERNAME"

# Configure Proxy
read -p "Do you want to setup EdgeniusOS behind a proxy(y/n): " YN
if [ $YN == "y" ] ; then
read -p "Enter HTTP Proxy(http://<proxy>): " HTTPPROXY
read -p "Enter Local Domain Name for NO_PROXY: " NOPROXY
sudo mkdir /etc/systemd/system/crio.service.d
sudo cat > /etc/systemd/system/crio.service.d/override.conf << EOF
[Service]
Environment=HTTP_PROXY=$HTTPPROXY
Environment=HTTPS_PROXY=$HTTPPROXY
Environment=NO_PROXY=127.0.0.1,10.42.*,10.43.*,cluster.local,$NOPROXY
EOF
sudo mkdir /etc/systemd/system/rpm-ostreed.service.d
sudo cat > /etc/systemd/system/rpm-ostreed.service.d/override.conf << EOF
[Service]
Environment="http_proxy=$HTTPPROXY"
Environment="https_proxy=$HTTPPROXY"
Environment="no_proxy=127.0.0.1,10.42.*,10.43.*,cluster.local,$NOPROXY"
EOF
sudo cat << EOF >> /etc/environment
export http_proxy=$HTTPPROXY
export https_proxy=$HTTPPROXY
export no_proxy=127.0.0.1,10.42.*,10.43.*,cluster.local,$NOPROXY
EOF
echo "Proxy is set."
else
echo "OS will be installed without Proxy Configuration."
fi


# Setup NTP Server Address. Only two addresses supported
read -p "Do you want to setup NTP Server IP Address(y/n): " YN
if [ $YN == "y" ] ; then
read -p "Enter NTP Server Address (Server1,Server2): " NTPSERVER
IFS=,
read SERVER1 SERVER2 <<< $NTPSERVER
if [[ -z "$SERVER2" ]] ; then
sudo cat << EOF >> /etc/chrony.conf
server $SERVER1 iburst
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
EOF
else
sudo cat << EOF >> /etc/chrony.conf
server $SERVER1 iburst
server $SERVER2 iburst
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
EOF
fi
fi

chvt 1
exec < /dev/tty1 > /dev/tty1 2> /dev/tty1

echo "******************************************"

echo -e 'export KUBECONFIG=/var/lib/microshift/resources/kubeadmin/kubeconfig' >> /root/.profile

# bootc handles container image storage automatically - no manual ostree repo setup needed

# Disabled as per #64
#if [ -c /dev/tpm0 ]; then 
#echo "Found a TPM chip. Applying full disk encryption..."
#    BLKDS=$(lsblk --noheadings -o NAME,FSTYPE -r | grep crypto_LUKS | cut -d ' ' -f 1)
#    for blkd in ${BLKDS}; do
#    echo Binding LUKS partition /dev/$blkd to the TPM pin...
#    dev="/dev/$blkd"
#    if [ "`clevis luks list -d $dev`" == "" ]; then
#      clevis luks bind -f -k - -d $dev tpm2 '{"pcr_ids":"7","pcr_bank":"sha256"}' <<< "WELLKN0WN"
#      cryptsetup luksRemoveKey $dev <<< "WELLKN0WN"
#    else
#      echo "$dev already pinned using clevis"
#    fi
#    done
#else
#    echo "No TPM chip found."
#    echo "!!! Use WELLKN0WN to decrypt your partitions at each boot !!!"
#    echo "TODO: create a no-password token in LUKS"
#fi
%end