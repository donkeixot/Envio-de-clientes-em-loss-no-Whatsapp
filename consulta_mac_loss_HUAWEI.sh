#!/bin/bash

# Endereço IP da OLT Huawei
OLT_IP="10.11.104.2"

# Comunidade SNMP
COMMUNITY="public123"

# OID para status das ONUs
OID_STATUS="1.3.6.1.4.1.2011.6.128.1.1.2.46.1.15"

# Consulta SNMP para obter os status das ONUs
SNMP_STATUS_RESULT=$(snmpwalk -v 2c -c "$COMMUNITY" "$OLT_IP" "$OID_STATUS")

# Extrair a lista de ONUs online (status 1) e offline (status 2)
echo "$SNMP_STATUS_RESULT" | grep "INTEGER: [12]" > /media/script/onuloss/onus_status.txt

# Filtrar ONUs offline da lista de status
cat /media/script/onuloss/onus_status.txt | grep "INTEGER: 2" > /media/script/onuloss/onus_offline.txt

# Remover prefixos dos OIDs no arquivo onus_offline.txt
sed -i 's/SNMPv2-SMI::enterprises.2011.6.128.1.1.2.46.1.15.//' /media/script/onuloss/onus_offline.txt

# OID para causa da última desconexão das ONUs
OID_CAUSE="1.3.6.1.4.1.2011.6.128.1.1.2.46.1.24"

# Consulta SNMP para obter as causas de última desconexão das ONUs
SNMP_CAUSE_RESULT=$(snmpwalk -v 2c -c "$COMMUNITY" "$OLT_IP" "$OID_CAUSE")

# Extrair a lista de ONUs com causas válidas (1, 2, 3, 5, 6, 15)
echo "$SNMP_CAUSE_RESULT" | grep "INTEGER: [23]" > /media/script/onuloss/onus_cause.txt

# Remover prefixos dos OIDs no arquivo onus_cause.txt
sed -i 's/SNMPv2-SMI::enterprises.2011.6.128.1.1.2.46.1.24.//' /media/script/onuloss/onus_cause.txt

# Comparar os dois arquivos e extrair as ONUs com status offline e causas válidas
awk 'NR==FNR{a[$1];next} $1 in a' /media/script/onuloss/onus_offline.txt /media/script/onuloss/onus_cause.txt > /media/script/onuloss/onus_offline_cause.txt

# Extrair nomes das ONTs e salvar em arquivo
snmpwalk -v 2c -c public123 10.11.104.2 1.3.6.1.4.1.2011.6.128.1.1.2.43.1.3 > /media/script/onuloss/onu_names.txt

# Remover prefixo do OID do arquivo temporário
sed -i 's/SNMPv2-SMI::enterprises.2011.6.128.1.1.2.43.1.3.//' /media/script/onuloss/onu_names.txt

# Comparar os dois arquivos e extrair as ONUs com status offline e causas válidas
awk 'NR==FNR{a[$1];next} $1 in a' /media/script/onuloss/onus_offline_cause.txt /media/script/onuloss/onu_names.txt > /media/script/onuloss/onus_offline_names.txt

# Arquivo temporário para armazenar os MACs das ONUs offline
MACS_FILE="/media/script/onuloss/onus_offline_macs.txt"

# Remover o arquivo de MACs antigo, caso exista, para garantir que não acumule dados antigos
rm -f $MACS_FILE

# Loop para percorrer cada linha no arquivo de nomes das ONUs offline
while IFS= read -r line; do
    # Extrair o MAC da linha
    mac=$(echo "$line" | awk -F ": " '{print $2}' | awk '{gsub(" ", "", $0); print}')

    # Adicionar o MAC ao arquivo de MACs
    echo "\"$mac\"" >> $MACS_FILE
done < "/media/script/onuloss/onus_offline_names.txt"

# Juntar os MACs separados por ";"
macs=$(paste -sd ";" $MACS_FILE)

# Enviar os MACs das ONUs offline via Zabbix Sender
zabbix_sender -z 127.0.0.1 -s "OLT_HUAWEI_TLS" -k "offline_onu_macs" -o "$macs"

#Salvar Macs
echo "$macs" > /media/script/onuloss/macsalvostls.txt

# Contar o número de ONUs em Loss
COUNT=$(wc -l < /media/script/onuloss/onus_offline_names.txt)

# Enviar a contagem via zabbix_sender
zabbix_sender -z 127.0.0.1 -s "OLT_HUAWEI_TLS" -k "losstls" -o "$COUNT"

# Excluir arquivos temporários
rm /media/script/onuloss/onu_names.txt /media/script/onuloss/onus_cause.txt /media/script/onuloss/onus_offline_cause.txt /media/script/onuloss/onus_offline_names.txt /media/script/onuloss/onus_off>
