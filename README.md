# AWSIOT
AWSIOT

as per certificate use below command to generate .p12 files
openssl pkcs12 -export -out awsiot-identity.p12 -inkey can-iot.private.key -in can-iot.cert.pem

openssl pkcs12 -export -out YOURPFXFILE.pfx -inkey *****-private.pem.key -in *****-certificate.pem.crt
