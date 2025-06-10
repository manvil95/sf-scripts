#!/bin/bash

# ========================================================================
# Script de validación de despliegue en Salesforce
#
# Este script genera un comando para validar un despliegue contra un entorno
# en Salesforce utilizando un manifiesto y un conjunto de tests Apex.
#
# Uso:
#   ./<ruta>/validate_deployment.sh -x <nombre_del_manifiesto> -o <organizacion_objetivo> [--pre-destructive-changes <archivo>] [--post-destructive-changes <archivo>] [--test-suite <testSuite>] [testSuite]
#   ./<ruta>/validate_deployment.sh [-h, --help]
#
# Parámetros:
#   [-x, --manifest]             : Nombre del archivo XML del manifiesto que
#                                  se encuentra en el directorio ./manifest/
#   [-o, --target-org]           : Organización de Salesforce contra la cual 
#                                  se realizará la validación del despliegue.
#   [--pre-destructive-changes]  : (Opcional) Nombre del archivo de cambios
#                                  destructivos previos.
#   [--post-destructive-changes] : (Opcional) Nombre del archivo de cambios
#                                  destructivos posteriores.
#   [--test-suite]               : (Opcional) Nombre del archivo de test suite
#                                  (por defecto: SuiteToTest).
#   [-h, --help]                 : (Opcional) Muestra ayuda del comando.
#
# Ejemplos:
#   1. Para validar un despliegue utilizando el manifiesto 'package.xml'
#      contra la organización 'myOrg':
#   ./validate_deployment.sh -x package.xml -o myOrg
#   ./validate_deployment.sh package.xml myOrg
#   ./validate_deployment.sh -x package.xml -o myOrg --pre-destructive-changes prechanges.xml --post-destructive-changes postchanges.xml
#   2. Para especificar un test suite diferente:
#      ./validate_deployment.sh package.xml myOrg CustomSuite
#      ./validate_deployment.sh -x package.xml -o myOrg --test-suite CustomSuite
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
    printf "\n\033[1;36mUso:\033[0m $0 [-x, --manifest <nombre_del_manifiesto>] [-o, --target-org <organizacion_objetivo> [--pre-destructive-changes <archivo>] [--post-destructive-changes <archivo>] [--test-suite <testSuite>]\n"
    printf "Ejemplo: $0 -x package.xml -o myOrg\n"
    printf "         $0 -x package.xml -o myOrg --pre-destructive-changes prechanges.xml --post-destructive-changes postchanges.xml --test-suite CustomSuite\n"
    printf "         $0 -h\n"
    printf "         $0 --help\n\n"
    exit 0
}

# Mostrar ayuda si se solicita
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
fi

# Comprobación de argumentos de entrada
if [[ "$#" -lt 4 ]]; then
    printf "\n\033[1;31mError:\033[0m Se requieren al menos 2 argumentos: -x archivo de manifiesto, -o organización objetivo de Salesforce.\n"
    show_help
fi

# Inicialización de variables
manifest_file=""
org_target=""
pre_destructive_changes=""
post_destructive_changes=""
test_suite="SuiteTest"

# Parseo de los argumentos
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -x|--manifest)
            manifest_file="$2"
            shift 2
            ;;
        -o|--target-org)
            org_target="$2"
            shift 2
            ;;
        --pre-destructive-changes)
            pre_destructive_changes="$2"
            shift 2
            ;;
        --post-destructive-changes)
            post_destructive_changes="$2"
            shift 2
            ;;
        --test-suite)
            test_suite="$2"
            shift 2
            ;;
        *)
            if [[ -z "$test_suite" ]]; then
                test_suite="$1"
            else
                printf "\n\033[1;31mError:\033[0m Argumento no reconocido: $1\n"
                show_help
            fi
            shift
            ;;
    esac
done

# Validar que la CLI de Salesforce esté instalada
if ! command -v sf >/dev/null 2>&1; then
    printf "\n\033[1;31mError:\033[0m La CLI de Salesforce (sf) no está instalada o no está en el PATH.\n"
    exit 1
fi

# Define los parámetros de entrada del script
dirManifest="./manifest/$manifest_file" # Ruta al fichero XML del manifiesto
orgDefault="$org_target" # Organización objetivo de Salesforce

# Ruta del archivo testSuite (tercer argumento opcional)
testSuiteFile="${3:-SuiteTest}"
DIR_TEST_SUITE="./unpackaged/main/default/testSuites/$testSuiteFile.testSuite-meta.xml"

# Inicializa la lista de pruebas
APEXTEST_LIST=""

printf "\n\n\033[34mTest Suite directory:\033[0m $DIR_TEST_SUITE\n"

# Verifica si el archivo de manifiesto existe
if [[ ! -f "$dirManifest" ]]; then
    printf "\n\033[1;31mError:\033[0m El archivo $manifest_file no existe en la ruta especificada: $dirManifest\n"
    exit 1
fi

# Comprobar si se proporcionaron archivos para cambios destructivos
if [[ -n "$pre_destructive_changes" && ! -f "$pre_destructive_changes" ]]; then
    printf "\n\033[1;31mError:\033[0m El archivo de cambios destructivos previos no existe: $pre_destructive_changes\n"
    exit 1
fi

if [[ -n "$post_destructive_changes" && ! -f "$post_destructive_changes" ]]; then
    printf "\n\033[1;31mError:\033[0m El archivo de cambios destructivos posteriores no existe: $post_destructive_changes\n"
    exit 1
fi

# Verifica si el archivo de test suite existe
if [[ ! -f "$DIR_TEST_SUITE" ]]; then
    printf "\n\033[1;31mError:\033[0m El archivo de test suite no existe: $DIR_TEST_SUITE\n"
    exit 1
fi

printf "\n\033[32mVerificado fichero $manifest_file. \033[0m\n"
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

# Imprimir valores introducidos
printf "\n\033[34mManifest Directory:\033[0m $dirManifest"
printf "\n\033[34mTarget Org:\033[0m $orgDefault"
printf "\n\033[34mTest Suite:\033[0m $DIR_TEST_SUITE"
printf "\n\033[34mTests a ejecutar:\033[0m $(echo $APEXTEST_LIST | wc -w)"
printf "\n\033[34mPre Destructive Changes:\033[0m $pre_destructive_changes"
printf "\n\033[34mPost Destructive Changes:\033[0m $post_destructive_changes\n\n"

# Obtener el valor de instanceUrl desde el JSON utilizando jq
INSTANCE_URL=$(sf org display --target-org "$orgDefault" --json | jq -r '.result.instanceUrl')
printf "\n\033[36mInstance Url:\033[0m $INSTANCE_URL"

# Verifica si el valor obtenido es válido
if [[ -z "$INSTANCE_URL" ]]; then
    printf "\n\033[1;31mError:\033[0m No se pudo determinar el URL de la instancia (instanceUrl). Verifica que la organización objetivo exista y que tengas acceso.\n"
    exit 1
fi

if [[ "$INSTANCE_URL" == *"sandbox"* ]]; then
    printf "\n\033[36mTipo de organización:\033[0m SANDBOX (se usará --dry-run)\n"
    # Comando para SANDBOX: dry-run
    printf "\n\033[34mComando a ejecutar:\033[0m\n"
    
    printf "\n\033[32msf project start deploy\033[0m \033[34m--manifest\033[0m $dirManifest \033[34m--target-org\033[0m $orgDefault \033[34m--pre-destructive-changes\033[0m $pre_destructive_changes \033[34m--post-destructive-changes\033[0m $post_destructive_changes \033[34m--test-level\033[0m RunSpecifiedTests \033[34m--tests\033[0m $APEXTEST_LIST \033[34m--dry-run\033[0m\n\n"
    
    command="sf project start deploy --manifest $dirManifest --target-org $orgDefault --pre-destructive-changes $pre_destructive_changes --post-destructive-changes $post_destructive_changes --test-level RunSpecifiedTests --tests $APEXTEST_LIST --dry-run"
else
    printf "\n\033[36mTipo de organización:\033[0m PRODUCCIÓN (validación real, sin --dry-run)\n"
    # Comando para PRODUCCIÓN: validación real
    printf "\n\033[34mComando a ejecutar:\033[0m\n"
    
    printf "\n\033[32msf project deploy validate\033[0m \033[34m--manifest\033[0m $dirManifest \033[34m--target-org\033[0m $orgDefault \033[34m--pre-destructive-changes\033[0m $pre_destructive_changes \033[34m--post-destructive-changes\033[0m $post_destructive_changes \033[34m--test-level\033[0m RunSpecifiedTests \033[34m--tests\033[0m $APEXTEST_LIST\n\n"

    command="sf project deploy validate --manifest $dirManifest --target-org $orgDefault --pre-destructive-changes $pre_destructive_changes --post-destructive-changes $post_destructive_changes --test-level RunSpecifiedTests --tests $APEXTEST_LIST"
fi

# Ejecuta el comando de Salesforce según el tipo de organización
printf "\n\033[33mEjecutando validación...\033[0m"
eval "$command"
printf "\n\033[32mValidación finalizada.\033[0m"
