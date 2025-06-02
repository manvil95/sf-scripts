#!/bin/bash

# ========================================================================
# Script de validación de despliegue en Salesforce
#
# Este script genera un comando para validar un despliegue contra un entorno
# en Salesforce utilizando un manifiesto y un conjunto de tests Apex.
#
# Uso:
#   ./<ruta>/validate_deployment.sh [nombre_del_manifiesto] [organizacion_objetivo] [testSuite]
#   ./<ruta>/validate_deployment.sh [-h, --help]
#
# Parámetros:
#   [nombre_del_manifiesto]  : Nombre del archivo XML del manifiesto que
#                              se encuentra en el directorio ./manifest/
#   [organizacion_objetivo]  : Organización de Salesforce contra la cual 
#                              se realizará la validación del despliegue.
#   [testSuite]              : (Opcional) Nombre del archivo de test suite
#                              (por defecto: SuiteToTest)
#   [-h, --help]             : (Opcional) Muestra ayuda del comando.
#
# Ejemplos:
#   1. Para validar un despliegue utilizando el manifiesto 'package.xml'
#      contra la organización 'myOrg':
#      ./validate_deployment.sh package.xml myOrg
#   2. Para especificar un test suite diferente:
#      ./validate_deployment.sh package.xml myOrg CustomSuite
#   3. Para mostrar la ayuda:
#      ./validate_deployment.sh -h
#      ./validate_deployment.sh --help
#
# Notas:
#   - Este script está pensado para validar contra entornos de desarrollo,
#     no productivos.
#   - Los test que ejecuta el comando de validación son aquellos indicados
#     en el testSuite-meta.xml que se indica en la variable DIR_TEST_SUITE.
#   - Ejecutar el script en una consola Bash.
#   - Se recomienda guardar el script en la carpeta ./scripts/bash/.
#   - El comando ejecutado varía según el tipo de organización:
#       - Si es SANDBOX: se ejecuta un despliegue en modo simulación (dry-run).
#       - Si es PRODUCCIÓN: se ejecuta una validación real (sin --dry-run) usando 'sf project deploy validate'.
#   - El comando para ejecutar el script:
#       ./scripts/bash/validate_deployment.sh package.xml myOrg CustomSuite
#       ./scripts/bash/validate_deployment.sh [-h, --help]
#     
# ========================================================================

set -euo pipefail

# Función de ayuda
show_help() {
    echo -e "\033[1;34m\n\nDESCRIPCIÓN\033[0m"
    echo -e "Este script genera un comando para validar un despliegue contra un entorno de Salesforce utilizando un manifiesto y un conjunto de tests Apex.\nDetecta automáticamente si la organización es sandbox o producción y ejecuta el comando adecuado."
    echo -e "\033[1;34m\n\nUSO\033[0m"
    printf "\033[32m  $\033[0m"
    printf "\033[34m $0\033[0m"
    printf " <nombre_del_manifiesto> <organizacion_objetivo> [testSuite]\n"
    printf "\033[32m  $\033[0m"
    printf "\033[34m $0\033[0m"
    printf " -h\n"
    printf "\033[32m  $\033[0m"
    printf "\033[34m $0\033[0m"
    printf " --help\n"
    echo -e "\033[1;34m\nFLAGS\033[0m"
    printf "\033[32m  <nombre_del_manifiesto>\033[0m"
    printf "\033[31m\t(requerido)\033[0m"
    printf " Nombre del archivo XML del manifiesto (en ./manifest/).\n\n"
    printf "\033[32m  <organizacion_objetivo>\033[0m"
    printf "\033[31m\t(requerido)\033[0m"
    printf " Alias o username de la organización de Salesforce.\n\n"
    printf "\033[32m  [testSuite]\033[0m"
    printf "\t\t\t(Opcional) Nombre del archivo de test suite (por defecto: SuiteToTest).\n\n"
    printf "\033[32m  -h, --help\033[0m"
    printf "\t\t\tMuestra este mensaje de ayuda.\n"
    echo -e "\033[1;34m\nEJEMPLOS:\033[0m"
    printf "\n$0 package.xml myOrg\n"
    printf "$0 package.xml myOrg CustomSuite\n"
    printf "$0 -h\n"
    printf "$0 --help\n"
    echo -e "\033[1;34m\nFUNCIONAMIENTO:\033[0m"
    echo -e "- Verifica la existencia de los archivos requeridos.\n- Lee el test suite y extrae las clases de test Apex.\n- Detecta si la organización es SANDBOX o PRODUCCIÓN.\n- Si es SANDBOX, ejecuta un despliegue en modo simulación (dry-run).\n- Si es PRODUCCIÓN, ejecuta una validación real usando 'sf project deploy validate' (sin --dry-run).\n- Muestra el comando generado y ejecuta la validación."
}

# Mostrar ayuda si se solicita
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

# Comprobación de argumentos de entrada
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    if [[ "${1:-}" != "-h" && "${1:-}" != "--help" ]]; then
        printf "\n\033[1;31mError:\033[0m Se requieren 2 o 3 argumentos: 1) archivo de manifiesto, 2) organización objetivo de Salesforce, 3) (opcional) archivo de test suite\n"
    fi
    show_help
    exit 1
fi

# Validar que la CLI de Salesforce esté instalada
if ! command -v sf >/dev/null 2>&1; then
    printf "\n\033[1;31mError:\033[0m La CLI de Salesforce (sf) no está instalada o no está en el PATH.\n"
    exit 1
fi

# Define los parámetros de entrada del script
dirManifest="./manifest/$1" # Primer argumento: Ruta al fichero XML del manifiesto
orgDefault=$2  # Segundo argumento: Organización objetivo de Salesforce

# Ruta del archivo testSuite (tercer argumento opcional)
testSuiteFile="${3:-SuiteToTest}"
DIR_TEST_SUITE="./force-app/main/default/testSuites/$testSuiteFile.testSuite-meta.xml"

# Inicializa la lista de pruebas
APEXTEST_LIST=""

printf "\n\n\033[34mTest Suite directory:\033[0m $DIR_TEST_SUITE\n"

# Verifica si el archivo de manifiesto existe
if [[ ! -f "$dirManifest" ]]; then
    printf "\n\033[1;31mError:\033[0m El archivo $1 no existe en la ruta especificada: $dirManifest\n"
    exit 1
fi

# Verifica si el archivo de test suite existe
if [[ ! -f "$DIR_TEST_SUITE" ]]; then
    printf "\n\033[1;31mError:\033[0m El archivo de test suite no existe: $DIR_TEST_SUITE\n"
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

# Verifica que la lista de tests no esté vacía
if [[ -z "$APEXTEST_LIST" ]]; then
    printf "\n\033[1;31mError:\033[0m No se encontraron clases de test en el archivo de test suite: $DIR_TEST_SUITE\n"
    exit 1
fi

# Imprime los valores introducidos solo para verificación
printf "\n\033[34mManifest Directory:\033[0m $dirManifest"
printf "\n\033[34mTarget Org:\033[0m $orgDefault"
printf "\n\033[34mTest Suite:\033[0m $DIR_TEST_SUITE"
printf "\n\033[34mTests a ejecutar:\033[0m $APEXTEST_LIST"

# Determina si la organización es sandbox o producción usando la CLI de Salesforce
ORG_TYPE=$(sf org display --target-org "$orgDefault" --json | grep -o '"isSandbox": *[a-z]*' | awk -F: '{print $2}' | tr -d ' ,')

if [[ "$ORG_TYPE" == "true" ]]; then
    printf "\n\033[36mTipo de organización:\033[0m SANDBOX (se usará --dry-run)\n"
    # Comando para SANDBOX: dry-run
    printf "\n\033[34mComando a ejecutar:\033[0m\n"
    printf "\nsf project start deploy \033[34m--manifest\033[0m $dirManifest \033[34m--target-org\033[0m $orgDefault \033[34m--test-level\033[0m RunSpecifiedTests \033[34m--tests\033[0m $APEXTEST_LIST \033[34m--dry-run\033[0m\n"
    command="sf project start deploy --manifest $dirManifest --target-org $orgDefault --test-level RunSpecifiedTests --tests $APEXTEST_LIST --dry-run"
else
    printf "\n\033[36mTipo de organización:\033[0m PRODUCCIÓN (validación real, sin --dry-run)\n"
    # Comando para PRODUCCIÓN: validación real
    printf "\n\033[34mComando a ejecutar:\033[0m\n"
    printf "\nsf project deploy validate \033[34m--manifest\033[0m $dirManifest \033[34m--target-org\033[0m $orgDefault \033[34m--test-level\033[0m RunSpecifiedTests \033[34m--tests\033[0m $APEXTEST_LIST\n"
    command="sf project deploy validate --manifest $dirManifest --target-org $orgDefault --test-level RunSpecifiedTests --tests $APEXTEST_LIST"
fi

# Ejecuta el comando de Salesforce según el tipo de organización
eval "$command"
