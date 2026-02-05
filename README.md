# icinga2_com_ack_migration
Scripts to migrate all comments and acknowlements from the one instance to another
The migration can be done between IDO and Icinga DB instances. The Icinga2 API is used for all communication.

# Usage
## Export comments and acknowlements into file
In source deployment:
* Host comments/acks
```
icinga-host-ack-com-export.sh
```
* Service comments/acks
```
icinga-service-ack-com-export.sh
```
* Config

ENV variables can be used for changing default parameters:
```
ICINGA_HOST - default: localhost                # Icinga2 API hostname/IP
ICINGA_PORT - default: 5665                     # Icinga2 API listening port
ICINGA_USER - default: apiuser                  # Icinga2 API username
OUTFILE     - default: hosts_acks_comments.json # output filename
ICINGA_PASS                                     # Icinga2 API user password
SINCE                                           # UNIX timestamp from which records will be exported
```
Password and timestamp will be asked interactively if not submitted.

## Import comments and acknowlements into file
In destination deployment:
* Host comments/acks
```
icinga-host-ack-com-import.sh
```
* Service comments/acks
```
icinga-service-ack-com-import.sh
```
* Config

ENV variables can be used for changing default parameters:
```
ICINGA_HOST - default: localhost                # Icinga2 API hostname/IP
ICINGA_PORT - default: 5665                     # Icinga2 API listening port
ICINGA_USER - default: apiuser                  # Icinga2 API username
INFILE      - default: hosts_acks_comments.json # input filename
ICINGA_PASS                                     # Icinga2 API user password
```
Password will be asked interactively if not submitted.
