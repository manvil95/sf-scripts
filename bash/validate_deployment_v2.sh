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
    echo -e "\033[1;34m\n\nDESCRIPCIÓN\033[0m"
    echo -e "Este script valida un despliegue en Salesforce usando un manifiesto, un test suite y opcionalmente archivos de cambios destructivos previos y posteriores."
    echo -e "Detecta automáticamente si la organización es SANDBOX o PRODUCCIÓN y ejecuta el comando adecuado."
    echo -e "\033[1;34m\n\nUSO\033[0m"
    printf "\033[32m  $\033[0m"
    printf "\033[34m $0\033[0m"
    printf " [-x, --manifiest <manifiesto>] [-o, --target-org <org>] [--pre-destructive-changes <archivo>] [--post-destructive-changes <archivo>] [--test-suite <suite>]\n"
    printf "\033[32m  $\033[0m"
    printf "\033[34m $0\033[0m"
    printf " -h\n"
    printf "\033[32m  $\033[0m"
    printf "\033[34m $0\033[0m"
    printf " --help\n"
    echo -e "\033[1;34m\nFLAGS\033[0m"
    printf "\033[32m  -x, --manifest <archivo>\033[0m"
    printf "\033[31m\t\t(requerido)\033[0m"
    printf " Manifiesto XML (en ./manifest/).\n\n"
    printf "\033[32m  -o, --target-org <org>\033[0m"
    printf "\033[31m\t\t(requerido)\033[0m"
    printf " Alias o username de la organización de Salesforce.\n\n"
    printf "\033[32m  --pre-destructive-changes <archivo>\033[0m"
    printf "\t(Opcional) Archivo de cambios destructivos previos.\n\n"
    printf "\033[32m  --post-destructive-changes <archivo>\033[0m"
    printf "\t(Opcional) Archivo de cambios destructivos posteriores.\n\n"
    printf "\033[32m  --test-suite <suite>\033[0m"
    printf "\t\t\t(Opcional) Nombre del test suite (por defecto: SuiteToTest).\n\n"
    printf "\033[32m  -h, --help\033[0m"
    printf "\t\t\t\tMuestra este mensaje de ayuda.\n"
    echo -e "\033[1;34m\nEJEMPLOS:\033[0m"
    printf "\n$0 -x package.xml -o myOrg\n"
    printf "$0 -x package.xml -o myOrg --test-suite CustomSuite\n"
    printf "$0 -x package.xml -o myOrg --pre-destructive-changes pre.xml --post-destructive-changes post.xml\n"
    printf "$0 -h\n"
    printf "$0 --help\n"
    echo -e "\033[1;34m\nFUNCIONAMIENTO:\033[0m"
    echo -e "- Valida la existencia de los archivos requeridos."
    echo -e "- Lee el test suite y extrae las clases de test Apex."
    echo -e "- Detecta si la organización es SANDBOX o PRODUCCIÓN."
    echo -e "- Si es SANDBOX, ejecuta un despliegue en modo simulación (dry-run)."
    echo -e "- Si es PRODUCCIÓN, ejecuta una validación real usando 'sf project deploy validate' (sin --dry-run)."
    echo -e "- Muestra el comando generado y ejecuta la validación."
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
test_suite=""
command=""

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
                print_error "Argumento no reconocido: $1"
                show_help
            fi
            shift
            ;;
    esac
done

# 1. Modularidad y escalabilidad: separar en funciones
print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m\t  $1" >&2
}
print_info() {
    echo -e "\033[34m[INFO]\033[0m\t  $1"
}
print_success() {
    echo -e "\033[32m[SUCCESS]\033[0m $1"
}
print_warning() {
    echo -e "\033[33m[WARNING]\033[0m\t $1"
}

# 2. Validación de parámetros y flags
validate_parameters() {
    if [[ -z "$manifest_file" ]]; then
        print_error "El manifiesto es obligatorio (-x o --manifest)."
        show_help
        exit 1
    fi
    if [[ -z "$org_target" ]]; then
        print_error "La organización objetivo es obligatoria (-o o --target-org)."
        show_help
        exit 1
    fi
    if [[ -z "$test_suite" ]]; then
        test_suite="SuiteTest"
    fi
    if [[ -n "$pre_destructive_changes" && ! -f "$pre_destructive_changes" ]]; then
        print_error "El archivo de cambios destructivos previos no existe: $pre_destructive_changes"
        exit 1
    fi
    if [[ -n "$post_destructive_changes" && ! -f "$post_destructive_changes" ]]; then
        print_error "El archivo de cambios destructivos posteriores no existe: $post_destructive_changes"
        exit 1
    fi
}

# 3. Legibilidad y comprensión: comentarios y resumen de parámetros
print_summary() {
    print_info "Manifest Directory: $dirManifest"
    print_info "Target Org: $orgDefault"
    print_info "Test Suite: $DIR_TEST_SUITE"
    print_info "Tests a ejecutar: $(echo $APEXTEST_LIST | wc -w)"
    if [[ -n "$pre_destructive_changes" && -f "$pre_destructive_changes" ]]; then
        print_info "Pre Destructive Changes: $pre_destructive_changes"
    fi
    if [[ -n "$post_destructive_changes" && -f "$post_destructive_changes" ]]; then
        print_info "Post Destructive Changes: $post_destructive_changes"
    fi
}

# Validar que la CLI de Salesforce esté instalada
if ! command -v sf >/dev/null 2>&1; then
    print_error "La CLI de Salesforce (sf) no está instalada o no está en el PATH."
    exit 1
fi

# Define los parámetros de entrada del script
dirManifest="./manifest/$manifest_file" # Ruta al fichero XML del manifiesto
orgDefault="$org_target" # Organización objetivo de Salesforce

# Validación de parámetros y archivos
validate_parameters

# Ruta del archivo testSuite correctamente (después de validar y asignar test_suite)
DIR_TEST_SUITE="./unpackaged/main/default/testSuites/${test_suite}.testSuite-meta.xml"

print_info "Verificando fichero $manifest_file..."
# Verifica si el archivo de manifiesto existe
if [[ ! -f "$dirManifest" ]]; then
    print_error "El archivo $manifest_file no existe en la ruta especificada: $dirManifest"
    exit 1
fi
print_success "Verificado fichero $manifest_file."

print_info "Verificando Test Suite directory: "$DIR_TEST_SUITE"..."
# Verifica si el archivo de test suite existe
if [[ ! -f "$DIR_TEST_SUITE" ]]; then
    print_error "El archivo de test suite no existe: $DIR_TEST_SUITE"
    exit 1
fi
print_success "Verificado Test Suite directory: "$DIR_TEST_SUITE"."

print_info "Inicio proceso de lectura de test..."

# Inicializa la lista de pruebas
APEXTEST_LIST=""

# Procesa el archivo de test suite
while read -r line; do
    if [[ $line =~ \<testClassName\>(.*)\</testClassName\> ]]; then
        test=$(echo "${BASH_REMATCH[1]}" | tr -d '\n')
        APEXTEST_LIST="$APEXTEST_LIST$test "
    fi
done < "$DIR_TEST_SUITE"

# Elimina el último espacio en la lista de pruebas
APEXTEST_LIST=${APEXTEST_LIST% }

print_success "Finalizado proceso de lectura de test."

# Verifica que la lista de tests no esté vacía
if [[ -z "$APEXTEST_LIST" ]]; then
    print_error "No se encontraron clases de test en el archivo de test suite: $DIR_TEST_SUITE"
    exit 1
fi

# Imprimir resumen de parámetros
print_summary

# Obtener el valor de instanceUrl desde el JSON utilizando jq
INSTANCE_URL=$(sf org display --target-org "$orgDefault" --json | jq -r '.result.instanceUrl')
print_info "Instance Url: $INSTANCE_URL"

# Verifica si el valor obtenido es válido
if [[ -z "$INSTANCE_URL" ]]; then
    print_error "No se pudo determinar el URL de la instancia (instanceUrl). Verifica que la organización objetivo exista y que tengas acceso.\n"
    exit 1
fi

if [[ "$INSTANCE_URL" == *"sandbox"* ]]; then
    print_info "Tipo de organización: SANDBOX (se usará --dry-run)"
    # Comando para SANDBOX: dry-run
    print_info "Comando a ejecutar:"
    
    # No hay pre ni post destructive changes
    if [[ -z "$pre_destructive_changes" && ! -f "$pre_destructive_changes" && -z "$post_destructive_changes" && ! -f "$post_destructive_changes" ]]; then
        print_info "\033[32msf project start deploy\033[0m \033[34m--manifest\033[0m $dirManifest \033[34m--target-org\033[0m $orgDefault \033[34m--test-level\033[0m RunSpecifiedTests \033[34m--tests\033[0m $APEXTEST_LIST \033[34m--dry-run\033[0m"
        
        command="sf project start deploy --manifest $dirManifest --target-org $orgDefault --test-level RunSpecifiedTests --tests $APEXTEST_LIST --dry-run"
    fi
    
    # Hay pre destructive changes
    if [[ -n "$pre_destructive_changes" && -f "$pre_destructive_changes" && -z "$post_destructive_changes" && ! -f "$post_destructive_changes" ]]; then
        print_info "\033[32msf project start deploy\033[0m \033[34m--manifest\033[0m $dirManifest \033[34m--target-org\033[0m $orgDefault \033[34m--pre-destructive-changes\033[0m $pre_destructive_changes \033[34m--test-level\033[0m RunSpecifiedTests \033[34m--tests\033[0m $APEXTEST_LIST \033[34m--dry-run\033[0m"
        
        command="sf project start deploy --manifest $dirManifest --target-org $orgDefault --pre-destructive-changes $pre_destructive_changes --test-level RunSpecifiedTests --tests $APEXTEST_LIST --dry-run"
    fi
    
    # Hay post destructive changes
    if [[ -z "$pre_destructive_changes" && ! -f "$pre_destructive_changes" && -n "$post_destructive_changes" && -f "$post_destructive_changes" ]]; then
        print_info "\033[32msf project start deploy\033[0m \033[34m--manifest\033[0m $dirManifest \033[34m--target-org\033[0m $orgDefault \033[34m--post-destructive-changes\033[0m $post_destructive_changes \033[34m--test-level\033[0m RunSpecifiedTests \033[34m--tests\033[0m $APEXTEST_LIST \033[34m--dry-run\033[0m"
        
        command="sf project start deploy --manifest $dirManifest --target-org $orgDefault --post-destructive-changes $post_destructive_changes --test-level RunSpecifiedTests --tests $APEXTEST_LIST --dry-run"
    fi
    
    # Hay pre y post destructive changes
    if [[ -n "$pre_destructive_changes" && -f "$pre_destructive_changes" && -n "$post_destructive_changes" && -f "$post_destructive_changes" ]]; then
        print_info "\033[32msf project start deploy\033[0m \033[34m--manifest\033[0m $dirManifest \033[34m--target-org\033[0m $orgDefault \033[34m--pre-destructive-changes\033[0m $pre_destructive_changes \033[34m--post-destructive-changes\033[0m $post_destructive_changes \033[34m--test-level\033[0m RunSpecifiedTests \033[34m--tests\033[0m $APEXTEST_LIST \033[34m--dry-run\033[0m"
        
        command="sf project start deploy --manifest $dirManifest --target-org $orgDefault --pre-destructive-changes $pre_destructive_changes --post-destructive-changes $post_destructive_changes --test-level RunSpecifiedTests --tests $APEXTEST_LIST --dry-run"
    fi
else
    print_info "\nTipo de organización:\033[0m PRODUCCIÓN (validación real, sin --dry-run)"
    # Comando para PRODUCCIÓN: validación real
    print_info "\nComando a ejecutar:"
    
    # No hay pre ni post destructive changes
    if [[ -z "$pre_destructive_changes" && ! -f "$pre_destructive_changes" && -z "$post_destructive_changes" && ! -f "$post_destructive_changes" ]]; then
        print_info "\033[32msf project deploy validate\033[0m \033[34m--manifest\033[0m $dirManifest \033[34m--target-org\033[0m $orgDefault \033[34m--test-level\033[0m RunSpecifiedTests \033[34m--tests\033[0m $APEXTEST_LIST"
        
        command="sf project deploy validate --manifest $dirManifest --target-org $orgDefault --test-level RunSpecifiedTests --tests $APEXTEST_LIST "
    fi
    
    # Hay pre destructive changes
    if [[ -n "$pre_destructive_changes" && -f "$pre_destructive_changes" && -z "$post_destructive_changes" && ! -f "$post_destructive_changes" ]]; then
        print_info "\033[32msf project deploy validate\033[0m \033[34m--manifest\033[0m $dirManifest \033[34m--target-org\033[0m $orgDefault \033[34m--pre-destructive-changes\033[0m $pre_destructive_changes \033[34m--test-level\033[0m RunSpecifiedTests \033[34m--tests\033[0m $APEXTEST_LIST"
        
        command="sf project deploy validate --manifest $dirManifest --target-org $orgDefault --pre-destructive-changes $pre_destructive_changes --test-level RunSpecifiedTests --tests $APEXTEST_LIST "
    fi
    
    # Hay post destructive changes
    if [[ -z "$pre_destructive_changes" && ! -f "$pre_destructive_changes" && -n "$post_destructive_changes" && -f "$post_destructive_changes" ]]; then
        print_info "\033[32msf project deploy validate\033[0m \033[34m--manifest\033[0m $dirManifest \033[34m--target-org\033[0m $orgDefault \033[34m--post-destructive-changes\033[0m $post_destructive_changes \033[34m--test-level\033[0m RunSpecifiedTests \033[34m--tests\033[0m $APEXTEST_LIST"
        
        command="sf project deploy validate --manifest $dirManifest --target-org $orgDefault --post-destructive-changes $post_destructive_changes --test-level RunSpecifiedTests --tests $APEXTEST_LIST "
    fi
    
    # Hay pre y post destructive changes
    if [[ -n "$pre_destructive_changes" && -f "$pre_destructive_changes" && -n "$post_destructive_changes" && -f "$post_destructive_changes" ]]; then
        print_info "\033[32msf project deploy validate\033[0m \033[34m--manifest\033[0m $dirManifest \033[34m--target-org\033[0m $orgDefault \033[34m--pre-destructive-changes\033[0m $pre_destructive_changes \033[34m--post-destructive-changes\033[0m $post_destructive_changes \033[34m--test-level\033[0m RunSpecifiedTests \033[34m--tests\033[0m $APEXTEST_LIST"
        
        command="sf project deploy validate --manifest $dirManifest --target-org $orgDefault --pre-destructive-changes $pre_destructive_changes --post-destructive-changes $post_destructive_changes --test-level RunSpecifiedTests --tests $APEXTEST_LIST "
    fi
fi

# Ejecuta el comando de Salesforce según el tipo de organización
print_info "Ejecutando validación..."
eval "$command"
print_success "\n\033[32mValidación finalizada.\033[0m"