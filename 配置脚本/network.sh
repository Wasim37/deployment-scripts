#!/bin/bash

# Copyright 2016 Chen Peng <senpal220@qq.com> All rights reserved.
# 
# 系统支持：CentOS测试通过；
# 
################################################################################

# 安装参数
ip_addr=192.168.0.100
netmask=255.255.255.0
gateway=192.168.0.1

parse_args() {
  read -p "Please type IP address [$ip_addr]:" _ip_addr
  if [ -n "$_ip_addr" ] ; then
    ip_addr=$_ip_addr
  fi

  read -p "Please type netmask [$netmask]:" _netmask
  if [ -n "$_netmask" ] ; then
    netmask=$_netmask
  fi

  read -p "Please type gateway [$gateway]:" _gateway
  if [ -n "$_gateway" ] ; then
    gateway=$_gateway
  fi

  printf "config:\n"
  printf "%-30s = %s\n" "IP address" "$ip_addr"
  printf "%-30s = %s\n" "Netmask" "$netmask"
  printf "%-30s = %s\n" "gateway" "$gateway"
}

setup() {
  echo 'Network config...'
  cd /etc/sysconfig/network-scripts/
  sed -i 's/HWADDR/MACADDR/' ifcfg-eth0
  sed -i 's/dhcp/static/' ifcfg-eth0
  sed -i 's/ONBOOT=no/ONBOOT=yes/' ifcfg-eth0

  grep "IPADDR=" ifcfg-eth0 >/dev/null
  if [ $? -eq 0 ]; then
    sed -i '/IPADDR=/c IPADDR='$ip_addr'' ifcfg-eth0
    sed -i '/NETMASK=/c NETMASK='$netmask'' ifcfg-eth0
    sed -i '/GATEWAY=/c GATEWAY='$gateway'' ifcfg-eth0
  else
    echo >> /etc/profile
    echo "IPADDR=$ip_addr" >> ifcfg-eth0
    echo "NETMASK=$netmask" >> ifcfg-eth0
    echo "GATEWAY=$gateway" >> ifcfg-eth0
  fi

  echo 'DNS config...'
  echo "nameserver $gateway" > /etc/resolv.conf
}

echo 'Install Network...'
parse_args
setup
echo 'Restart network service...'
service network restart

exit 0
