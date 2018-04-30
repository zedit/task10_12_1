#!/bin/bash

source config

virsh net-destroy ${EXTERNAL_NET_NAME}
virsh net-destroy ${INTERNAL_NET_NAME}
virsh net-destroy ${MANAGEMENT_NET_NAME}

virsh net-undefine ${EXTERNAL_NET_NAME}
virsh net-undefine ${INTERNAL_NET_NAME}
virsh net-undefine ${MANAGEMENT_NET_NAME}

virsh destroy vm1
virsh destroy vm2

virsh undefine vm1
virsh undefine vm2
