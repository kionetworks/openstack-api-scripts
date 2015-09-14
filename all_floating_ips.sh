#!/bin/bash

declare -A tenant_data

for tenants_raw_data in `keystone tenant-list | egrep -v "^\+|\<id\>" | awk '{printf "%s,%s\n",$2,$4}'`; do
    tenant_id=`echo ${tenants_raw_data} | cut -d, -f1`
    tenant_name=`echo ${tenants_raw_data} | cut -d, -f2`
    tenant_data["${tenant_id}"]="${tenant_name}"

done

printf "%25s %25s %25s %25s\n" "Tenant ID" "Tenant Name" "Floating IP" "Status"

mysql -u neutron --password=XXXXXXXXXXXX neutron -N -e 'SELECT tenant_id, floating_ip_address, status FROM floatingips' | while read -r neutron_data; do
    tenant_id_n=`echo ${neutron_data} | awk '{print $1}'`
    floating_ip=`echo ${neutron_data} | awk '{print $2}'`
    stat=`echo ${neutron_data} | awk '{print $3}'`
    tenant_n="${tenant_data["${tenant_id_n}"]}"
    if [ ${#tenant_n} -le 1 ]; then
        tenant_n="======================"
    fi
    printf "%25s %25s %25s %25s\n" ${tenant_id_n} ${tenant_n} ${floating_ip} ${stat}
done
