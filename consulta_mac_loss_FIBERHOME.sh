#!/bin/bash

# Endereço IP da OLT SNMP Fiberhome
SNMP_DEVICE="10.200.201.2"

# Community SNMP
SNMP_COMMUNITY="adsl"

# OID para status das ONUs
OID_STATUS="1.3.6.1.4.1.5875.800.3.10.1.1.11"
OID_MAC_LIST="1.3.6.1.4.1.5875.800.3.10.1.1.10"

# Consulta SNMP para obter os status das ONUs
echo "Executando snmpwalk..."
SNMP_STATUS_RESULT=$(snmpwalk -v 2c -c "$SNMP_COMMUNITY" "$SNMP_DEVICE" "$OID_STATUS")

if [ $? -ne 0 ]; then
    echo "Erro ao executar snmpwalk."
    exit 1
fi

# Extrair a lista de ONU com status INTEGER: 0
ONUS_STATUS_0=$(echo "$SNMP_STATUS_RESULT" | grep -E "INTEGER: 0" | awk -F. '{print $NF}')

# Inicializar uma variável para armazenar os MACs
MACS_STATUS_0=""

# Loop para obter os MACs das ONUs com status INTEGER: 0
for onu in $ONUS_STATUS_0; do
  MAC_RESULT=$(snmpget -v 2c -c "$SNMP_COMMUNITY" "$SNMP_DEVICE" "$OID_MAC_LIST.$onu" | awk -F"STRING: " '{print $2}' | sed 's/"//g')
  if [ -n "$MAC_RESULT" ]; then
    MACS_STATUS_0="$MACS_STATUS_0\"$MAC_RESULT\";"
  fi
done

# Remover o último ponto e vírgula do resultado
MACS_STATUS_0=${MACS_STATUS_0%;}

# Enviar a lista de MACs em loss para o Zabbix Sender
zabbix_sender -z 127.0.0.1 -s "OLT_FIBERHOME_APT" -k "macloss" -o "$MACS_STATUS_0"
echo "Lista de MACs enviada para o Zabbix Sender."

# Salvar a lista de MACs em um arquivo (alterar o caminho)
OUTPUT_FILE="/media/script/onuloss/macsalvos.txt"
echo "$MACS_STATUS_0" > "$OUTPUT_FILE"
echo "Lista de MACs salva em $OUTPUT_FILE."
