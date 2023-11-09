## Install necessary packages
apt install git -y 
apt install golang -y
apt install sed -y  
#check if ubuntu
if [ -f /etc/lsb-release ]; then
    DISTRO=$(grep "DISTRIB_ID" /etc/lsb-release | cut -d'=' -f2)
    if [[ "$DISTRO" == "Ubuntu" ]]; then
        clear
        echo "This OS is Ubuntu."
        sudo sed -i 's/#DNS=/DNS=8.8.8.8/' /etc/systemd/resolved.conf
        sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
        sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    else
        echo "Unable to determine the operating system."
    fi
fi


#installation
clear
echo "[DNSTT over SSH Setup]"
echo "" 
echo "Enter your nameserver ?"
echo ""
read nameserver

#allowtcpforwarding on SSH
sudo sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/' /etc/ssh/sshd_config
systemctl restart ssh

#adding user 
useradd test -M -s /bin/false
echo "test:1234" | chpasswd
#install udpgw
echo "Installing UDPGW and service of udpgw.service"
   #!/bin/sh
   OS=`uname -m`;
   wget -O /usr/bin/badvpn-udpgw "https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw" >> /dev/null
   if [ "$OS" == "x86_64" ]; then   
      wget -O /usr/bin/badvpn-udpgw "https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw64" >> /dev/null
   fi
   chmod +x /usr/bin/badvpn-udpgw
   # Echo the service file contents
   echo "
   [Unit]
   Description=UDPGW Service
   After=network.target

   [Service]
   Type=simple
   ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300
   Restart=always

   [Install]
   WantedBy=multi-user.target" >> /etc/systemd/system/udpgw.service 
   systemctl daemon-reload
   systemctl enable udpgw.service
   systemctl restart udpgw.service
   sleep 2

#get git repo and build the golang
git clone https://github.com/Mygod/dnstt.git
cd dnstt
cd dnstt-server
go build

#generate pub key and privkey
./dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub

cat <<\EOM > /root/dnstt/dnstt-server/server.key
e0518afec33e79e1c9fb7f10906a1b2198146947aa1f78861d8c971fde9bde3
EOM

cat <<\EOM > /root/dnstt/dnstt-server/server.pub
4a3583ca915e35e9c4f64800624a5e46a1400462b9a1cd11068aedc4c7e4c14b
EOM

#generate service file for dnstt
   echo "
   [Unit]
   Description=DNSTT
   After=network.target

   [Service]
   Type=simple
   WorkingDirectory=/root/dnstt/dnstt-server
   ExecStart=/root/dnstt/dnstt-server/dnstt-server -udp :53 -privkey-file server.key $nameserver 127.0.0.1:22
   Restart=always

   [Install]
   WantedBy=multi-user.target" >> /etc/systemd/system/dnstt.service 

#restart the service and run it
systemctl enable dnstt
systemctl restart dnstt

#echo the public key and ns
clear
publickey=$(cat /root/dnstt/dnstt-server/server.pub)
echo "======================"
echo "Public Key = $publickey"
echo "Nameserver = $nameserver"
echo "======================"
echo "Login Credentials"
echo "Username:test"
echo "Password:1234"
echo "The system will reboot now..."
sleep 5
reboot
