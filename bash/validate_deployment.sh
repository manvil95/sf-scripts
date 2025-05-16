#!/bin/bash

# ========================================================================
# Script de validación de despliegue en Salesforce
#
# Este script genera un comando para validar un despliegue contra un entorno
# en Salesforce utilizando un manifiesto y un conjunto de tests Apex.
#
# Uso:
#   ./<ruta>/validate_deployment.sh <nombre_del_manifiesto> <organizacion_objetivo>
#
# Parámetros:
#   <nombre_del_manifiesto>  : Nombre del archivo XML del manifiesto que
#                              se encuentra en el directorio ./manifest/
#   <organizacion_objetivo>  : Organización de Salesforce contra la cual 
#                              se realizará la validación del despliegue.
#
# Ejemplos:
#   1. Para validar un despliegue utilizando el manifiesto 'package.xml'
#      contra la organización 'myOrg':
#      ./validate_deployment.sh package.xml myOrg
# 
# Notas:
#   - Este script está pensado para validar contra entornos de desarrollo,
#     no productivos.
#   - Los test que ejecuta el comando de validación son aquellos indicados
#     en el testSuite-meta.xml que se indica en la variable DIR_TEST_SUITE.
#   - Ejecutar el script en una consola Bash.
#   - Se recomienda guardar el script en la carpeta ./scripts/bash/.
#   - El comando para ejecutar el script:
#       ./scripts/bash/validate_deployment.sh package.xml myOrg
#     
# ========================================================================

# Comprobación de argumentos de entrada
if [ "$#" -ne 2 ]; then
    printf "\n\033[1;31mError:\033[0m Se requieren 2 argumentos: 1) archivo de manifiesto, 2) organización objetivo de Salesforce\n"
    exit 1
fi

# Define los parámetros de entrada del script
dirManifest="./manifest/$1" # Primer argumento: Ruta al fichero XML del manifiesto
orgDefault=$2  # Segundo argumento: Organización objetivo de Salesforce

# Ruta del archivo testSuite
DIR_TEST_SUITE="./unpackaged/main/default/testSuites/SuiteToTest.testSuite-meta.xml"
# Inicializa la lista de pruebas
APEXTEST_LIST=""

printf "\n\n\033[34mTest Suite directory:\033[0m $DIR_TEST_SUITE\n"

# Verifica si el archivo de manifiesto existe
if [[ ! -f "$dirManifest" ]]; then
    printf "\n\033[1;31mError:\033[0m El archivo $1 no existe en la ruta especificada: $dirManifest"
    exit 1
fi

printf "\n\033[32mVerificado fichero $1. \033[0m\n"

printf "\n\033[33mInicio proceso de lectura de test...\033[0m"

# Procesa el archivo de test suite
while read -r line; do
    if [[ $line =~ \<testClassName\>(.*)\</testClassName\> ]]; then
        test=$(echo "${BASH_REMATCH[1]}" | tr -d '\n')
        APEXTEST_LIST="$APEXTEST_LIST$test "
    fi
done < "$DIR_TEST_SUITE"

# Elimina el último espacio en la lista de pruebas
APEXTEST_LIST=${APEXTEST_LIST% }

printf "\n\033[32mFinalizado proceso de lectura de test. \033[0m\n"

# Imprime los valores introducidos solo para verificación
printf "\n\033[34mManifest Directory:\033[0m $dirManifest"
printf "\n\033[34mTarget Org:\033[0m $orgDefault"

# Construye e imprime el comando completo
command="sf project start deploy --manifest $dirManifest --target-org $orgDefault --test-level RunSpecifiedTests --tests $APEXTEST_LIST --dry-run"
printf "\n\n\033[34mComando a ejecutar:\033[0m\n $command"

# Ejecuta el comando de Salesforce
eval "$command"
