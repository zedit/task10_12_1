#!/bin/bash
#set -x
source config
def_link="https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img"
def_img="/home/dmitry/projects/kvm-training/xenial.img"
CHECK_SUM="99e73c2c09cad6a681b2d372c37f2e11"
DIR_NAME="/var/lib/libvirt/images/"
UDVM1="user-data_vm1.template"
UDVM2="user-data_vm2.template"

function create_ext_net {
  local file_ext_net="/tmp/external.xml"
  cp networks/external.xml ${file_ext_net}
  sed -i "s/SED_EXTERNAL_NET_NAME/${EXTERNAL_NET_NAME}/" ${file_ext_net}
  sed -i "s/SED_EXTERNAL_NET_HOST_IP/${EXTERNAL_NET_HOST_IP}/" ${file_ext_net}
  sed -i "s/SED_EXTERNAL_NET_MASK/${EXTERNAL_NET_MASK}/" ${file_ext_net}
  sed -i "s/SED_EXTERNAL_NET/${EXTERNAL_NET}/g" ${file_ext_net}
  virsh net-define ${file_ext_net}
  virsh net-start ${EXTERNAL_NET_NAME}
}

function create_int_net {
  local file_int_net="/tmp/internal.xml"
  cp networks/internal.xml ${file_int_net}
  sed -i "s/SED_INTERNAL_NET_NAME/${INTERNAL_NET_NAME}/" ${file_int_net}
  virsh net-define ${file_int_net}
  virsh net-start ${INTERNAL_NET_NAME}
}

function create_man_net {
  local file_man_net="/tmp/management.xml"
  cp networks/management.xml ${file_man_net}
  sed -i "s/SED_MANAGEMENT_NET_NAME/${MANAGEMENT_NET_NAME}/" ${file_man_net}
  sed -i "s/SED_MANAGEMENT_NET_HOST_IP/${MANAGEMENT_NET_HOST_IP}/" ${file_man_net}
  sed -i "s/SED_MANAGEMENT_NET_MASK/${MANAGEMENT_NET_MASK}/" ${file_man_net}
  virsh net-define ${file_man_net}
  virsh net-start ${MANAGEMENT_NET_NAME}
}

function downloadImg {
  if [ ! -e "${DIR_NAME}/${1}" ]; then
    mkdir ${DIR_NAME}/${1}
  fi
#del_section
  if [ -f "${def_img}" ]; then
    cp "${def_img}" "${2}"
  else
#end_del_section
  if [ ! -f "${2}" ]; then
    wget -O ${2} ${def_link}
  else
    local existing_file_check_sum="$(md5sum -b ${2} | awk '{print$1}')"
    if [[ "${CHECK_SUM}" != "${existing_file_check_sum}" ]]
      then
        wget -O ${2} ${def_link}
    fi
  fi
  fi
}

function createNetworkVM1data {
mkdir /tmp/${VM1_NAME}
cat << EOF > /tmp/${VM1_NAME}/network-config.yml
version: 1
config:
  - type: nameserver
    address:
      - ${EXTERNAL_NET_HOST_IP}
      - ${VM_DNS}
  - type: physical
    name: ${VM1_EXTERNAL_IF}
    subnets:
     - control: auto
       type: ${EXTERNAL_NET_TYPE}
  - type: physical
    name: ${VM1_INTERNAL_IF}
    subnets:
     - control: auto
       type: static
       address: ${VM1_INTERNAL_IP}
       netmask: ${INTERNAL_NET_MASK}
  - type: physical
    name: ${VM1_MANAGEMENT_IF}
    subnets:
     - control: auto
       type: static
       address: ${VM1_MANAGEMENT_IP}
       netmask: ${MANAGEMENT_NET_MASK}
EOF
}

function createNetworkVM2data {
mkdir /tmp/${VM2_NAME}
cat << EOF > /tmp/${VM2_NAME}/network-config.yml
version: 1
config:
  - type: nameserver
    address:
      - ${EXTERNAL_NET_HOST_IP}
      - ${VM_DNS}
  - type: physical
    name: ${VM2_INTERNAL_IF}
    subnets:
     - control: auto
       type: static
       address: ${VM2_INTERNAL_IP}
       netmask: ${INTERNAL_NET_MASK}
       gateway: ${VM1_INTERNAL_IP}
  - type: physical
    name: ${VM2_MANAGEMENT_IF}
    subnets:
     - control: auto
       type: static
       address: ${VM2_MANAGEMENT_IP}
       netmask: ${MANAGEMENT_NET_MASK}
EOF
}

function createUserdataVM1 {
  local check_cu_inst=$(apt-cache policy cloud-utils | grep Installed | awk -F ': ' '{print $2}')
  local used_data_file="/tmp/${VM1_NAME}/user-data"
  if [ "${check_cu_inst}" == "(none)" ]; then
    apt-get update
    apt-get install -y cloud-utils
  fi 
  mkdir /tmp/${VM1_NAME}
  cp ${UDVM1} ${user_data_file}
  sed -i "s/sed_change_vm_name/${VM1_NAME}/" ${user_data_file}
  sed -i "s#sed_change_public_key#$(cat ${SSH_PUB_KEY})#" ${user_data_file}
  sed -i "s/SED_VM1_INTERNAL_IP/${VM1_INTERNAL_IP}/" ${user_data_file}
  sed -i "s/SED_VM2_INTERNAL_IP/${VM1_INTERNAL_IP}/" ${user_data_file}
  sed -i "s/SED_VXLAN_IF/${VXLAN_IF}/g" ${user_data_file}
  sed -i "s/SED_VM1_VXLAN_IP/${VM1_VXLAN_IP}/" ${user_data_file}
  sed -i "s/SED_INT_IF/${VM1_INTERNAL_IF}/" ${user_data_file}
  sed -i "s/SED_EXT_IF/${VM1_EXTERNAL_IF}/g" ${user_data_file}
  sed -i "s/SED_INT_NET_IP/${INTERNAL_NET_IP}/" ${user_data_file}
  cloud-localds -N /tmp/${VM1_NAME}/network-config.yml ${VM1_CONFIG_ISO} ${user_data_file}
  rm -rf /tmp/${VM1_NAME}/
}

function createUserdataVM2 {
  local check_cu_inst=$(apt-cache policy cloud-utils | grep Installed | awk -F ': ' '{print $2}')
  local used_data_file="/tmp/${1}/user-data"
  if [ "${check_cu_inst}" == "(none)" ]; then
    apt-get update
    apt-get install -y cloud-utils
  fi 
  mkdir /tmp/${1}
  cp ${3} ${user_data_file}
  sed -i "s/sed_change_vm_name/${1}/" ${user_data_file}
  sed -i "s#sed_change_public_key#$(cat ${SSH_PUB_KEY})#" ${user_data_file}
  sed -i "s/SED_VM1_INTERNAL_IP/${VM1_INTERNAL_IP}/" ${user_data_file}
  sed -i "s/SED_VM2_INTERNAL_IP/${VM1_INTERNAL_IP}/" ${user_data_file}
  sed -i "s/SED_VXLAN_IF/${VXLAN_IF}/g" ${user_data_file}
  sed -i "s/SED_VM1_VXLAN_IP/${VM1_VXLAN_IP}/" ${user_data_file}
  sed -i "s/SED_INT_IF/${VM1_INTERNAL_IF}/" ${user_data_file}
  sed -i "s/SED_EXT_IF/${VM1_EXTERNAL_IF}/g" ${user_data_file}
  sed -i "s/SED_INT_NET_IP/${INTERNAL_NET_IP}/" ${user_data_file}
  cloud-localds -N /tmp/${1}/network-config.yml ${2} ${user_data_file}
  rm -rf /tmp/${1}/
}

function createVM1 {
  virt-install --virt-type=kvm --name ${VM1_NAME} \
               --ram ${VM1_MB_RAM} \
               --vcpus=${VM1_NUM_CPU} \
               --noautoconsole \
               --network network=${EXTERNAL_NET_NAME},model=virtio \
               --network network=${INTERNAL_NET_NAME},model=virtio \
               --network network=${MANAGEMENT_NET_NAME},model=virtio \
               --cdrom=${VM1_CONFIG_ISO} \
               --disk path=${VM1_HDD},format=qcow2
}

function createVM2 {
  virt-install --virt-type=kvm --name ${VM2_NAME} \
               --ram ${VM2_MB_RAM} \
               --vcpus=${VM2_NUM_CPU} \
               --noautoconsole \
               --network network=${INTERNAL_NET_NAME},model=virtio \
               --network network=${MANAGEMENT_NET_NAME},model=virtio \
               --cdrom=${VM2_CONFIG_ISO} \
               --disk path=${VM2_HDD},format=qcow2
}

create_ext_net
create_int_net
create_man_net
downloadImg ${VM1_NAME} ${VM1_HDD}
downloadImg ${VM2_NAME} ${VM2_HDD}
createNetworkVM1data
createNetworkVM2data
createUserdataVM1
createUserdata ${VM2_NAME} ${VM2_CONFIG_ISO} ${UDVM2}
createVM1
createVM2
